import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RoomListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.sortOrder) private var rooms: [Room]
    @Query private var allItems: [Item]
    @State private var showingAddRoom = false
    @State private var roomToEdit: Room?
    @State private var roomToDelete: Room?
    @State private var showingExportShare = false
    @State private var exportFileURL: URL?
    @State private var showingImportPicker = false
    @State private var showingImportResult = false
    @State private var importResult: CSVService.ImportResult?

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
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            roomToEdit = room
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            roomToEdit = room
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            roomToDelete = room
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("我的家")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            exportCSV()
                        } label: {
                            Label("导出数据", systemImage: "square.and.arrow.up")
                        }
                        .disabled(allItems.isEmpty)

                        Button {
                            showingImportPicker = true
                        } label: {
                            Label("导入数据", systemImage: "square.and.arrow.down")
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
            .alert("导入完成", isPresented: $showingImportResult) {
                Button("好的") {}
            } message: {
                if let r = importResult {
                    let summary = "成功导入 \(r.itemsCreated) 件物品"
                    let details = r.roomsCreated > 0 || r.cabinetsCreated > 0
                        ? "（新建 \(r.roomsCreated) 个房间、\(r.cabinetsCreated) 个柜子）"
                        : ""
                    let errors = r.errors.isEmpty ? "" : "\n\n跳过 \(r.errors.count) 行：\(r.errors.first ?? "")"
                    Text(summary + details + errors)
                }
            }
            .alert("确认删除", isPresented: Binding(
                get: { roomToDelete != nil },
                set: { if !$0 { roomToDelete = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let room = roomToDelete {
                        modelContext.delete(room)
                        roomToDelete = nil
                    }
                }
                Button("取消", role: .cancel) {
                    roomToDelete = nil
                }
            } message: {
                if let room = roomToDelete {
                    Text("确定要删除「\(room.name)」吗？其中的 \(room.cabinets.count) 个柜子和 \(room.itemCount) 件物品将被一并删除，此操作无法撤销。")
                }
            }
            .overlay {
                if rooms.isEmpty {
                    ContentUnavailableView {
                        Label("还没有房间", systemImage: "house")
                    } description: {
                        Text("点击右上角 + 添加你的第一个房间")
                    }
                }
            }
        }
    }

    private func exportCSV() {
        let csv = CSVService.exportToCSV(items: allItems)
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
                    importResult?.errors.append("无法读取文件编码")
                    showingImportResult = true
                    return
                }

                let cleaned = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content

                importResult = CSVService.importFromCSV(
                    csvString: cleaned,
                    modelContext: modelContext,
                    existingRooms: rooms
                )
                showingImportResult = true
            } catch {
                importResult = CSVService.ImportResult()
                importResult?.errors.append("读取文件失败：\(error.localizedDescription)")
                showingImportResult = true
            }

        case .failure(let error):
            importResult = CSVService.ImportResult()
            importResult?.errors.append("选择文件失败：\(error.localizedDescription)")
            showingImportResult = true
        }
    }
}

struct RoomRow: View {
    let room: Room

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: room.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.headline)
                Text("\(room.cabinets.count) 个柜子 · \(room.itemCount) 件物品")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
