import SwiftUI
import CoreData

struct ItemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var item: Item
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingMoveSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(item.locationDescription, systemImage: "location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    if !item.category.isEmpty {
                        HStack {
                            Text("分类")
                                .foregroundStyle(.secondary)
                            Spacer()
                            let category = ItemCategory.allCases.first { $0.rawValue == item.category }
                            Label(item.category, systemImage: category?.icon ?? "tag")
                        }
                    }

                    HStack {
                        Text("数量")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(item.quantity)")
                    }

                    if let expiryDate = item.expiryDate {
                        HStack {
                            Text("过期日期")
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(expiryDate, style: .date)
                                if let days = item.daysUntilExpiry {
                                    Text(days < 0 ? "已过期 \(-days) 天" : days == 0 ? "今天过期" : "还剩 \(days) 天")
                                        .font(.caption)
                                        .foregroundStyle(item.expiryStatus.color)
                                        .bold()
                                }
                            }
                        }
                    }

                    if !item.notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备注")
                                .foregroundStyle(.secondary)
                            Text(item.notes)
                        }
                    }

                    Divider()

                    HStack {
                        Text("添加时间")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.createdAt, style: .date)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Button {
                        showingMoveSheet = true
                    } label: {
                        Label("移动到…", systemImage: "arrow.right.doc.on.clipboard")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let cabinet = item.cabinet {
                AddItemView(cabinet: cabinet, existingItem: item)
            }
        }
        .sheet(isPresented: $showingMoveSheet) {
            MoveItemsView(items: [item])
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("删除", role: .destructive) {
                viewContext.delete(item)
                try? viewContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除「\(item.name)」吗？此操作无法撤销。")
        }
    }
}
