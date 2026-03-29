import SwiftUI
import SwiftData

enum ItemSortOption: String, CaseIterable {
    case dateDesc = "最新添加"
    case dateAsc = "最早添加"
    case nameAsc = "名称 A→Z"
    case nameDesc = "名称 Z→A"
    case expiryAsc = "过期日期（近→远）"
    case quantityDesc = "数量（多→少）"
}

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    let cabinet: Cabinet
    @State private var showingAddItem = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedItems: Set<PersistentIdentifier> = []
    @State private var showingBatchMoveSheet = false
    @State private var showingBatchDeleteConfirm = false
    @State private var sortOption: ItemSortOption = .dateDesc
    @State private var filterCategory: String? = nil

    private var availableCategories: [String] {
        Array(Set(cabinet.items.compactMap { $0.category.isEmpty ? nil : $0.category })).sorted()
    }

    private var sortedItems: [Item] {
        var items = cabinet.items

        // Filter
        if let category = filterCategory {
            items = items.filter { $0.category == category }
        }

        // Sort
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
        sortedItems.filter { selectedItems.contains($0.persistentModelID) }
    }

    var body: some View {
        List(selection: $selectedItems) {
            ForEach(sortedItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemRow(item: item)
                }
                .tag(item.persistentModelID)
            }
            .onDelete(perform: editMode == .inactive ? deleteItems : nil)
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(cabinet.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if editMode == .inactive && !cabinet.items.isEmpty {
                    Menu {
                        // Sort options
                        Section("排序") {
                            ForEach(ItemSortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        // Filter by category
                        if !availableCategories.isEmpty {
                            Section("按分类筛选") {
                                Button {
                                    filterCategory = nil
                                } label: {
                                    HStack {
                                        Text("全部")
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
                                            Text(category)
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
                    Button("完成") {
                        editMode = .inactive
                        selectedItems.removeAll()
                    }
                } else {
                    HStack(spacing: 16) {
                        if !cabinet.items.isEmpty {
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
                            Text("移动")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button(role: .destructive) {
                        showingBatchDeleteConfirm = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("删除")
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
                // Items were moved, exit edit mode
                editMode = .inactive
                selectedItems.removeAll()
            }
        }
        .alert("确认删除", isPresented: $showingBatchDeleteConfirm) {
            Button("删除 \(selectedItems.count) 件", role: .destructive) {
                batchDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除选中的 \(selectedItems.count) 件物品吗？此操作无法撤销。")
        }
        .overlay {
            if cabinet.items.isEmpty {
                ContentUnavailableView {
                    Label("还没有物品", systemImage: "archivebox")
                } description: {
                    Text("点击右上角 + 添加物品")
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let sorted = sortedItems
        for index in offsets {
            let item = sorted[index]
            cabinet.items.removeAll { $0.persistentModelID == item.persistentModelID }
            modelContext.delete(item)
        }
    }

    private func batchDelete() {
        for item in selectedItemObjects {
            cabinet.items.removeAll { $0.persistentModelID == item.persistentModelID }
            modelContext.delete(item)
        }
        selectedItems.removeAll()
        editMode = .inactive
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                let category = ItemCategory.allCases.first { $0.rawValue == item.category }
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
                        Text(item.category)
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
                // Always show expiry info when set
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

    private var text: String {
        guard let days = daysLeft else { return "" }
        switch status {
        case .expired:
            return "已过期 \(-days) 天"
        case .expiringSoon:
            return days == 0 ? "今天过期" : "还剩 \(days) 天过期"
        case .ok:
            return "还剩 \(days) 天过期"
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
