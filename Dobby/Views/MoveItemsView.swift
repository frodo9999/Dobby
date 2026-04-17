import SwiftUI
import CoreData

struct MoveItemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Room.sortOrder, ascending: true)])
    private var rooms: FetchedResults<Room>

    let items: [Item]

    @State private var searchText = ""
    @State private var expandedRooms: Set<NSManagedObjectID> = []

    private var currentCabinet: Cabinet? { items.first?.cabinet }
    private var currentRoom: Room? { currentCabinet?.room }

    private var filteredRooms: [Room] {
        if searchText.isEmpty {
            return Array(rooms)
        }
        let query = searchText.lowercased()
        return rooms.filter { room in
            room.name.lowercased().contains(query) ||
            room.cabinetsArray.contains { $0.name.lowercased().contains(query) }
        }
    }

    private func filteredCabinets(for room: Room) -> [Cabinet] {
        let sorted = room.cabinetsArray
        if searchText.isEmpty {
            return sorted
        }
        let query = searchText.lowercased()
        if room.name.lowercased().contains(query) {
            return sorted
        }
        return sorted.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if items.count == 1, let item = items.first {
                        HStack {
                            Text("物品")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.name)
                        }
                        HStack {
                            Text("当前位置")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.locationDescription)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("已选择")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(items.count) 件物品")
                        }
                    }
                }

                ForEach(filteredRooms) { room in
                    let cabinets = filteredCabinets(for: room)
                    if !cabinets.isEmpty {
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedRooms.contains(room.objectID) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedRooms.insert(room.objectID)
                                        } else {
                                            expandedRooms.remove(room.objectID)
                                        }
                                    }
                                )
                            ) {
                                ForEach(cabinets) { cabinet in
                                    let isCurrent = cabinet.objectID == currentCabinet?.objectID
                                    Button {
                                        moveItems(to: cabinet)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: cabinet.icon)
                                                .foregroundStyle(.orange)
                                                .frame(width: 24)
                                            Text(cabinet.name)
                                                .foregroundStyle(isCurrent ? .secondary : .primary)
                                            Spacer()
                                            Text("\(cabinet.itemsArray.count) 件")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if isCurrent {
                                                Text("当前")
                                                    .font(.caption)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .disabled(isCurrent)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: room.icon)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                    Text(room.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(cabinets.count) 个柜子")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("移动到")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索柜子...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if let currentRoom {
                    expandedRooms.insert(currentRoom.objectID)
                }
            }
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    for room in filteredRooms {
                        expandedRooms.insert(room.objectID)
                    }
                }
            }
        }
    }

    private func moveItems(to targetCabinet: Cabinet) {
        for item in items {
            item.cabinet = targetCabinet
            item.updatedAt = Date()
        }
        try? viewContext.save()
        dismiss()
    }
}
