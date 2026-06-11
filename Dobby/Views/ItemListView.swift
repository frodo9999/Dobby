import SwiftUI
import CoreData

enum ItemSortOption: String, CaseIterable {
    case dateDesc  = "dateDesc"
    case dateAsc   = "dateAsc"
    case nameAsc   = "nameAsc"
    case nameDesc  = "nameDesc"
    case expiryAsc = "expiryAsc"
    case quantityDesc = "quantityDesc"

    var displayName: String {
        let s = LanguageManager.shared.s
        switch self {
        case .dateDesc:     return s.sortDateDesc
        case .dateAsc:      return s.sortDateAsc
        case .nameAsc:      return s.sortNameAsc
        case .nameDesc:     return s.sortNameDesc
        case .expiryAsc:    return s.sortExpiryAsc
        case .quantityDesc: return s.sortQtyDesc
        }
    }
}

struct ItemListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var lm: LanguageManager
    @ObservedObject var cabinet: Cabinet
    @State private var showingAddItem = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedItems: Set<NSManagedObjectID> = []
    @State private var showingBatchMoveSheet = false
    @State private var showingBatchDeleteConfirm = false
    @State private var sortOption: ItemSortOption = .dateDesc
    @State private var filterCategory: String? = nil

    private var availableCategories: [String] {
        Array(Set(cabinet.itemsArray.compactMap { $0.category.isEmpty ? nil : $0.category })).sorted()
    }

    private var sortedItems: [Item] {
        var items = cabinet.itemsArray

        if let category = filterCategory {
            items = items.filter { $0.category == category }
        }

        switch sortOption {
        case .dateDesc:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .dateAsc:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .nameAsc:
            return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return items.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .expiryAsc:
            return items.sorted {
                ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture)
            }
        case .quantityDesc:
            return items.sorted { $0.quantity > $1.quantity }
        }
    }

    private var selectedItemObjects: [Item] {
        sortedItems.filter { selectedItems.contains($0.objectID) }
    }

    var body: some View {
        List(selection: $selectedItems) {
            ForEach(sortedItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemRow(item: item)
                }
                .tag(item.objectID)
            }
            .onDelete(perform: editMode == .inactive ? deleteItems : nil)
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(cabinet.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if editMode == .inactive && !cabinet.itemsArray.isEmpty {
                    Menu {
                        Section(lm.s.sortSection) {
                            ForEach(ItemSortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.displayName)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        if !availableCategories.isEmpty {
                            Section(lm.s.filterSection) {
                                Button {
                                    filterCategory = nil
                                } label: {
                                    HStack {
                                        Text(lm.s.filterAll)
                                        if filterCategory == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                ForEach(availableCategories, id: \.self) { category in
                                    Button {
                                        filterCategory = category
                                    } label: {
                                        HStack {
                                            Text(ItemCategory.from(string: category)?.displayName ?? category)
                                            if filterCategory == category {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: filterCategory != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if editMode == .active {
                    Button(lm.s.done) {
                        editMode = .inactive
                        selectedItems.removeAll()
                    }
                } else {
                    HStack(spacing: 16) {
                        if !cabinet.itemsArray.isEmpty {
                            Button {
                                editMode = .active
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                        }
                        Button(action: { showingAddItem = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if editMode == .active && !selectedItems.isEmpty {
                HStack(spacing: 0) {
                    Button {
                        showingBatchMoveSheet = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.right.doc.on.clipboard")
                            Text(lm.s.moveBatch)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button(role: .destructive) {
                        showingBatchDeleteConfirm = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text(lm.s.delete)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(cabinet: cabinet)
        }
        .sheet(isPresented: $showingBatchMoveSheet) {
            MoveItemsView(items: selectedItemObjects)
        }
        .onChange(of: showingBatchMoveSheet) { _, isShowing in
            if !isShowing && !selectedItemObjects.isEmpty == false {
                editMode = .inactive
                selectedItems.removeAll()
            }
        }
        .alert(lm.s.confirmDelete, isPresented: $showingBatchDeleteConfirm) {
            Button(lm.s.deleteCountButton(count: selectedItems.count), role: .destructive) {
                batchDelete()
            }
            Button(lm.s.cancel, role: .cancel) {}
        } message: {
            Text(lm.s.deleteCountConfirm(count: selectedItems.count))
        }
        .overlay {
            if cabinet.itemsArray.isEmpty {
                ContentUnavailableView {
                    Label(lm.s.noItems, systemImage: "archivebox")
                } description: {
                    Text(lm.s.addItemHint)
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let sorted = sortedItems
        for index in offsets {
            let item = sorted[index]
            MongoSyncService.deleteItem(item)
            viewContext.delete(item)
        }
        try? viewContext.save()
    }

    private func batchDelete() {
        for item in selectedItemObjects {
            MongoSyncService.deleteItem(item)
            viewContext.delete(item)
        }
        try? viewContext.save()
        selectedItems.removeAll()
        editMode = .inactive
    }
}

struct ItemRow: View {
    @ObservedObject var item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                let category = ItemCategory.from(string: item.category)
                Image(systemName: category?.icon ?? "archivebox")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .frame(width: 44, height: 44)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    if !item.category.isEmpty {
                        Text(ItemCategory.from(string: item.category)?.displayName ?? item.category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let expiryDate = item.expiryDate {
                    ExpiryBadge(expiryDate: expiryDate, status: item.expiryStatus, daysLeft: item.daysUntilExpiry)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ExpiryBadge: View {
    let expiryDate: Date
    let status: ExpiryStatus
    let daysLeft: Int?
    @EnvironmentObject private var lm: LanguageManager

    private var text: String {
        guard let days = daysLeft else { return "" }
        switch status {
        case .expired:
            return lm.s.expiryExpired(days: days)
        case .expiringSoon:
            return days == 0 ? lm.s.expiryToday : lm.s.expiryDaysLeft(days: days)
        case .ok:
            return lm.s.expiryDaysLeft(days: days)
        case .none:
            return ""
        }
    }

    private var badgeColor: Color {
        switch status {
        case .expired: return .red
        case .expiringSoon: return .orange
        case .ok: return .secondary
        case .none: return .clear
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status == .expired ? "exclamationmark.circle.fill" :
                    status == .expiringSoon ? "clock.badge.exclamationmark" : "clock")
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.1))
        .clipShape(Capsule())
    }
}
