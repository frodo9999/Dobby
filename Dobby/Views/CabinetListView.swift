import SwiftUI
import CoreData

struct CabinetListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var lm: LanguageManager
    @ObservedObject var room: Room
    @State private var showingAddCabinet = false
    @State private var cabinetToEdit: Cabinet?
    @State private var cabinetToDelete: Cabinet?

    private var sortedCabinets: [Cabinet] {
        room.cabinetsArray
    }

    var body: some View {
        List {
            ForEach(sortedCabinets) { cabinet in
                NavigationLink(destination: ItemListView(cabinet: cabinet)) {
                    CabinetRow(cabinet: cabinet)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        cabinetToDelete = cabinet
                    } label: {
                        Label(lm.s.delete, systemImage: "trash")
                    }
                    Button {
                        cabinetToEdit = cabinet
                    } label: {
                        Label(lm.s.edit, systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button {
                        cabinetToEdit = cabinet
                    } label: {
                        Label(lm.s.edit, systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        cabinetToDelete = cabinet
                    } label: {
                        Label(lm.s.delete, systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddCabinet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCabinet) {
            AddCabinetView(room: room)
        }
        .sheet(item: $cabinetToEdit) { cabinet in
            AddCabinetView(room: room, existingCabinet: cabinet)
        }
        .alert(lm.s.confirmDelete, isPresented: Binding(
            get: { cabinetToDelete != nil },
            set: { if !$0 { cabinetToDelete = nil } }
        )) {
            Button(lm.s.delete, role: .destructive) {
                if let cabinet = cabinetToDelete {
                    viewContext.delete(cabinet)
                    try? viewContext.save()
                    cabinetToDelete = nil
                }
            }
            Button(lm.s.cancel, role: .cancel) {
                cabinetToDelete = nil
            }
        } message: {
            if let cabinet = cabinetToDelete {
                Text(lm.s.deleteCabinetConfirm(name: cabinet.name, count: cabinet.itemsArray.count))
            }
        }
        .overlay {
            if sortedCabinets.isEmpty {
                ContentUnavailableView {
                    Label(lm.s.noCabinets, systemImage: "cabinet")
                } description: {
                    Text(lm.s.addCabinetHint)
                }
            }
        }
    }
}

struct CabinetRow: View {
    @ObservedObject var cabinet: Cabinet
    @EnvironmentObject private var lm: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cabinet.icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(cabinet.name)
                    .font(.headline)
                Text(lm.s.cabinetSubtitle(count: cabinet.itemsArray.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
