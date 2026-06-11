import SwiftUI
import CoreData

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var lm: LanguageManager
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
            let key = item.category.isEmpty ? lm.s.uncategorized : item.category
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
                    emptyStateSections
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Section(lm.s.searchResults(n: filteredItems.count)) {
                        ForEach(filteredItems, id: \.objectID) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                SearchResultRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle(lm.s.searchTitle)
            .searchable(text: $searchText, prompt: lm.s.searchPlaceholder)
            .toolbar { aiToolbarButton }
            .sheet(isPresented: $showingAIDiscovery) { AIDiscoveryView() }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyStateSections: some View {
        Section {
            let cabinets = Set(allItems.compactMap { $0.cabinet })
            HStack {
                StatCard(title: lm.s.statRooms, value: "\(allRooms.count)", icon: "house", color: .blue)
                StatCard(title: lm.s.statCabinets, value: "\(cabinets.count)", icon: "cabinet", color: .orange)
                StatCard(title: lm.s.statItems, value: "\(allItems.count)", icon: "archivebox", color: .green)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        if !expiredItems.isEmpty || !expiringSoonItems.isEmpty {
            Section(lm.s.expiryAlerts) {
                if !expiredItems.isEmpty {
                    NavigationLink {
                        ExpiryItemsListView(title: lm.s.expired, items: expiredItems)
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(lm.s.expired)
                            Spacer()
                            Text(lm.s.itemCount(n: expiredItems.count)).foregroundStyle(.red).bold()
                        }
                    }
                }
                if !expiringSoonItems.isEmpty {
                    NavigationLink {
                        ExpiryItemsListView(title: lm.s.expiringSoon7, items: expiringSoonItems)
                    } label: {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
                            Text(lm.s.expiringSoon7)
                            Spacer()
                            Text(lm.s.itemCount(n: expiringSoonItems.count)).foregroundStyle(.orange).bold()
                        }
                    }
                }
            }
        }

        if !roomStats.isEmpty {
            Section(lm.s.byRoom) {
                ForEach(roomStats, id: \.room.objectID) { stat in
                    HStack(spacing: 12) {
                        Image(systemName: stat.room.icon).foregroundStyle(.blue).frame(width: 24)
                        Text(stat.room.name)
                        Spacer()
                        Text(lm.s.itemCount(n: stat.itemCount)).foregroundStyle(.secondary)
                        ProgressView(value: Double(stat.itemCount), total: Double(max(allItems.count, 1)))
                            .frame(width: 60)
                            .tint(.blue)
                    }
                }
            }
        }

        if !categoryStats.isEmpty {
            Section(lm.s.byCategory) {
                ForEach(categoryStats, id: \.category) { stat in
                    HStack {
                        let cat = ItemCategory.from(string: stat.category)
                        Image(systemName: cat?.icon ?? "tag").foregroundStyle(.green).frame(width: 24)
                        Text(stat.category)
                        Spacer()
                        Text(lm.s.itemCount(n: stat.count)).foregroundStyle(.secondary)
                    }
                }
            }
        }

        if !allItems.isEmpty {
            Section(lm.s.recentlyAdded) {
                ForEach(allItems.sorted(by: { $0.createdAt > $1.createdAt }).prefix(10), id: \.objectID) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        SearchResultRow(item: item)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var aiToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingAIDiscovery = true } label: {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.purple)
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
                            Text(item.name).font(.headline)
                            Text(item.locationDescription).font(.caption).foregroundStyle(.secondary)
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
                let category = ItemCategory.from(string: item.category)
                Image(systemName: category?.icon ?? "archivebox")
                    .frame(width: 40, height: 40)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body)
                Text(item.locationDescription).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if item.quantity > 1 {
                Text("×\(item.quantity)").font(.caption).foregroundStyle(.secondary)
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
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.title2).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
