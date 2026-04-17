import SwiftUI
import CoreData

struct CabinetListView: View {
    @Environment(\.managedObjectContext) private var viewContext
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
                        Label("删除", systemImage: "trash")
                    }
                    Button {
                        cabinetToEdit = cabinet
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button {
                        cabinetToEdit = cabinet
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        cabinetToDelete = cabinet
                    } label: {
                        Label("删除", systemImage: "trash")
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
        .alert("确认删除", isPresented: Binding(
            get: { cabinetToDelete != nil },
            set: { if !$0 { cabinetToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let cabinet = cabinetToDelete {
                    viewContext.delete(cabinet)
                    try? viewContext.save()
                    cabinetToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                cabinetToDelete = nil
            }
        } message: {
            if let cabinet = cabinetToDelete {
                Text("确定要删除「\(cabinet.name)」吗？其中的 \(cabinet.itemsArray.count) 件物品将被一并删除，此操作无法撤销。")
            }
        }
        .overlay {
            if sortedCabinets.isEmpty {
                ContentUnavailableView {
                    Label("还没有柜子", systemImage: "cabinet")
                } description: {
                    Text("点击右上角 + 添加柜子")
                }
            }
        }
    }
}

struct CabinetRow: View {
    @ObservedObject var cabinet: Cabinet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cabinet.icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(cabinet.name)
                    .font(.headline)
                Text("\(cabinet.itemsArray.count) 件物品")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
