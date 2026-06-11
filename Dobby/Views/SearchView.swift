import SwiftUI
import CoreData

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: []) private var allItems: FetchedResults<Item>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Room.sortOrder, ascending: true)])
    private var allRooms: FetchedResults<Room>
    @State private var searchText = ""
    @State private var showingAIDiscovery = false

    var filteredItems: [Item] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return allItems.filter { item in
            item.name.lowercased().contains(query) ||
            item.category.lowercased().contains(query) ||
            item.notes.lowercased().contains(query) ||
            (item.cabinet?.name.lowercased().contains(query) ?? false) ||
            (item.cabinet?.room?.name.lowercased().contains(query) ?? false)
        }
    }

    private var expiredItems: [Item] {
        allItems.filter { $0.expiryStatus == .expired }
    }

    private var expiringSoonItems: [Item] {
        allItems.filter { $0.expiryStatus == .expiringSoon }
    }

    private var categoryStats: [(category: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in allItems {
            let key = item.category.isEmpty ? "未分类" : item.category
            counts[key, default: 0] += Int(item.quantity)
        }
        return counts.map { (category: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    private var roomStats: [(room: Room, itemCount: Int)] {
        allRooms.map { ($0, $0.itemCount) }.filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        let cabinets = Set(allItems.compactMap { $0.cabinet })
                        HStack {
                            StatCard(title: "房间", value: "\(allRooms.count)", icon: "house", color: .blue)
                            StatCard(title: "柜子", value: "\(cabinets.count)", icon: "cabinet", color: .orange)
                            StatCard(title: "物品", value: "\(allItems.count)", icon: "archivebox", color: .green)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    if !expiredItems.isEmpty || !expiringSoonItems.isEmpty {
                        Section("过期提醒") {
                            if !expiredItems.isEmpty {
                                NavigationLink {
                                    ExpiryItemsListView(title: "已过期", items: expiredItems)
                                } label: {
                                    HStack {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text("已过期")
                                        Spacer()
                                        Text("\(expiredItems.count) 件")
                                            .foregroundStyle(.red)
                                            .bold()
                                    }
                                }
                            }
                            if !expiringSoonItems.isEmpty {
                                NavigationLink {
                                    ExpiryItemsListView(title: "即将过期", items: expiringSoonItems)
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .foregroundStyle(.orange)
                                        Text("7天内过期")
                                        Spacer()
                                        Text("\(expiringSoonItems.count) 件")
                                            .foregroundStyle(.orange)
                                            .bold()
                                    }
                                }
                            }
                        }
                    }

                    if !roomStats.isEmpty {
                        Section("各房间物品") {
                            ForEach(roomStats, id: \.room.objectID) { stat in
                                HStack(spacing: 12) {
                                    Image(systemName: stat.room.icon)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                    Text(stat.room.name)
                                    Spacer()
                                    Text("\(stat.itemCount) 件")
                                        .foregroundStyle(.secondary)
                                    ProgressView(value: Double(stat.itemCount), total: Double(max(allItems.count, 1)))
                                        .frame(width: 60)
                                        .tint(.blue)
                                }
                            }
                        }
                    }

                    if !categoryStats.isEmpty {
                        Section("分类统计") {
                            ForEach(categoryStats, id: \.category) { stat in
                                HStack {
                                    let cat = ItemCategory.allCases.first { $0.rawValue == stat.category }
                                    Image(systemName: cat?.icon ?? "tag")
                                        .foregroundStyle(.green)
                                        .frame(width: 24)
                                    Text(stat.category)
                                    Spacer()
                                    Text("\(stat.count) 件")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !allItems.isEmpty {
                        Section("最近添加") {
                            ForEach(allItems.sorted(by: { $0.createdAt > $1.createdAt }).prefix(10), id: \.objectID) { item in
                                NavigationLink(destination: ItemDetailView(item: item)) {
                                    SearchResultRow(item: item)
                                }
                            }
                        }
                    }
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Section("搜索结果 (\(filteredItems.count))") {
                        ForEach(filteredItems, id: \.objectID) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                SearchResultRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .searchable(text: $searchText, prompt: "搜索物品、柜子、房间...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAIDiscovery = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAIDiscovery) {
                AIDiscoveryView()
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExpiryItemsListView: View {
    let title: String
    let items: [Item]

    var body: some View {
        List {
            ForEach(items.sorted(by: { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }), id: \.objectID) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.locationDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let expiryDate = item.expiryDate {
                            ExpiryBadge(expiryDate: expiryDate, status: item.expiryStatus, daysLeft: item.daysUntilExpiry)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

struct SearchResultRow: View {
    @ObservedObject var item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                let category = ItemCategory.allCases.first { $0.rawValue == item.category }
                Image(systemName: category?.icon ?? "archivebox")
                    .frame(width: 40, height: 40)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                Text(item.locationDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.quantity > 1 {
                Text("×\(item.quantity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
