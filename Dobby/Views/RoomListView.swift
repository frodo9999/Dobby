import SwiftUI
import CoreData
import CloudKit
import UniformTypeIdentifiers

struct RoomListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var lm: LanguageManager
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Room.sortOrder, ascending: true)])
    private var rooms: FetchedResults<Room>
    @FetchRequest(sortDescriptors: [])
    private var allItems: FetchedResults<Item>

    @State private var showingAddRoom = false
    @State private var roomToEdit: Room?
    @State private var roomToDelete: Room?
    @State private var showingExportShare = false
    @State private var exportFileURL: URL?
    @State private var showingImportPicker = false
    @State private var showingImportResult = false
    @State private var importResult: CSVService.ImportResult?
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(rooms) { room in
                    NavigationLink(destination: CabinetListView(room: room)) {
                        RoomRow(room: room)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            roomToDelete = room
                        } label: {
                            Label(lm.s.delete, systemImage: "trash")
                        }
                        Button {
                            roomToEdit = room
                        } label: {
                            Label(lm.s.edit, systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            roomToEdit = room
                        } label: {
                            Label(lm.s.edit, systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            roomToDelete = room
                        } label: {
                            Label(lm.s.delete, systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(lm.s.myHome)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            shareHome()
                        } label: {
                            Label(lm.s.inviteFamily, systemImage: "person.crop.circle.badge.plus")
                        }
                        .disabled(rooms.isEmpty)

                        Divider()

                        Button {
                            exportCSV()
                        } label: {
                            Label(lm.s.exportData, systemImage: "square.and.arrow.up")
                        }
                        .disabled(allItems.isEmpty)

                        Button {
                            showingImportPicker = true
                        } label: {
                            Label(lm.s.importData, systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button {
                            lm.language = lm.isEnglish ? "zh" : "en"
                        } label: {
                            Label(lm.s.switchToOtherLang, systemImage: "globe")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRoom = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoom) {
                AddRoomView()
            }
            .sheet(item: $roomToEdit) { room in
                AddRoomView(existingRoom: room)
            }
            .alert(lm.s.shareFailed, isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )) {
                Button(lm.s.ok) { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
            .sheet(isPresented: $showingExportShare) {
                if let url = exportFileURL {
                    ShareSheetView(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(lm.s.importComplete, isPresented: $showingImportResult) {
                Button(lm.s.ok) {}
            } message: {
                if let r = importResult {
                    Text(lm.s.importSummary(
                        items: r.itemsCreated,
                        rooms: r.roomsCreated,
                        cabinets: r.cabinetsCreated,
                        errors: r.errors
                    ))
                }
            }
            .alert(lm.s.confirmDelete, isPresented: Binding(
                get: { roomToDelete != nil },
                set: { if !$0 { roomToDelete = nil } }
            )) {
                Button(lm.s.delete, role: .destructive) {
                    if let room = roomToDelete {
                        viewContext.delete(room)
                        try? viewContext.save()
                        roomToDelete = nil
                    }
                }
                Button(lm.s.cancel, role: .cancel) {
                    roomToDelete = nil
                }
            } message: {
                if let room = roomToDelete {
                    Text(lm.s.deleteRoomConfirm(
                        name: room.name,
                        cabinets: room.cabinetsArray.count,
                        items: room.itemCount
                    ))
                }
            }
            .overlay {
                if rooms.isEmpty {
                    ContentUnavailableView {
                        Label(lm.s.noRooms, systemImage: "house")
                    } description: {
                        Text(lm.s.addFirstRoom)
                    }
                }
            }
        }
    }

    private func shareHome() {
        CloudSharingPresenter.shared.presentZoneShare(
            ckContainer: SharingManager.shared.ckContainer
        ) { errorMsg in
            self.shareError = errorMsg
        }
    }

    private func exportCSV() {
        let csv = CSVService.exportToCSV(items: Array(allItems))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "Dobby_\(dateFormatter.string(from: Date())).csv"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let bom = "\u{FEFF}"
        try? (bom + csv).write(to: tempURL, atomically: true, encoding: .utf8)

        exportFileURL = tempURL
        showingExportShare = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                var csvString: String?

                if let str = String(data: data, encoding: .utf8) {
                    csvString = str
                } else if let str = String(data: data, encoding: .utf16) {
                    csvString = str
                } else if let str = String(data: data, encoding: .macOSRoman) {
                    csvString = str
                }

                guard let content = csvString else {
                    importResult = CSVService.ImportResult()
                    importResult?.errors.append(lm.s.cannotDecodeFile)
                    showingImportResult = true
                    return
                }

                let cleaned = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content

                importResult = CSVService.importFromCSV(
                    csvString: cleaned,
                    context: viewContext,
                    existingRooms: Array(rooms)
                )
                showingImportResult = true
            } catch {
                importResult = CSVService.ImportResult()
                importResult?.errors.append(lm.s.fileReadError(error.localizedDescription))
                showingImportResult = true
            }

        case .failure(let error):
            importResult = CSVService.ImportResult()
            importResult?.errors.append(lm.s.pickFileFailed(error.localizedDescription))
            showingImportResult = true
        }
    }
}

struct RoomRow: View {
    @ObservedObject var room: Room
    @EnvironmentObject private var lm: LanguageManager
    @FetchRequest private var items: FetchedResults<Item>

    init(room: Room) {
        self.room = room
        _items = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "cabinet.room == %@", room)
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: room.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.headline)
                Text(lm.s.roomSubtitle(cabinets: room.cabinetsArray.count, items: items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
