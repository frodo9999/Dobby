import SwiftUI
import SwiftData

struct MoveItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.sortOrder) private var rooms: [Room]

    let items: [Item]

    @State private var searchText = ""
    @State private var expandedRooms: Set<PersistentIdentifier> = []

    private var currentCabinet: Cabinet? { items.first?.cabinet }
    private var currentRoom: Room? { currentCabinet?.room }

    private var filteredRooms: [Room] {
        if searchText.isEmpty {
            return rooms
        }
        let query = searchText.lowercased()
        return rooms.filter { room in
            room.name.lowercased().contains(query) ||
            room.cabinets.contains { $0.name.lowercased().contains(query) }
        }
    }

    private func filteredCabinets(for room: Room) -> [Cabinet] {
        let sorted = room.cabinets.sorted(by: { $0.sortOrder < $1.sortOrder })
        if searchText.isEmpty {
            return sorted
        }
        let query = searchText.lowercased()
        // If room name matches, show all its cabinets; otherwise filter cabinets
        if room.name.lowercased().contains(query) {
            return sorted
        }
        return sorted.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary section
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

                // Room → Cabinet hierarchy
                ForEach(filteredRooms) { room in
                    let cabinets = filteredCabinets(for: room)
                    if !cabinets.isEmpty {
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedRooms.contains(room.persistentModelID) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedRooms.insert(room.persistentModelID)
                                        } else {
                                            expandedRooms.remove(room.persistentModelID)
                                        }
                                    }
                                )
                            ) {
                                ForEach(cabinets) { cabinet in
                                    let isCurrent = cabinet.persistentModelID == currentCabinet?.persistentModelID
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
                                            Text("\(cabinet.items.count) 件")
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
                // Default expand the room containing the current cabinet
                if let currentRoom {
                    expandedRooms.insert(currentRoom.persistentModelID)
                }
            }
            .onChange(of: searchText) { _, newValue in
                // When searching, expand all matching rooms
                if !newValue.isEmpty {
                    for room in filteredRooms {
                        expandedRooms.insert(room.persistentModelID)
                    }
                }
            }
        }
    }

    private func moveItems(to targetCabinet: Cabinet) {
        for item in items {
            if let oldCabinet = item.cabinet {
                oldCabinet.items.removeAll { $0.persistentModelID == item.persistentModelID }
            }
            item.cabinet = targetCabinet
            targetCabinet.items.append(item)
            item.updatedAt = Date()
        }
        dismiss()
    }
}
