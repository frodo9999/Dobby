import SwiftUI
import CoreData

struct ItemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lm: LanguageManager
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
                            Text(lm.s.category)
                                .foregroundStyle(.secondary)
                            Spacer()
                            let category = ItemCategory.from(string: item.category)
                            Label(category?.displayName ?? item.category, systemImage: category?.icon ?? "tag")
                        }
                    }

                    HStack {
                        Text(lm.s.quantity)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(item.quantity)")
                    }

                    if let expiryDate = item.expiryDate {
                        HStack {
                            Text(lm.s.expiryDate)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(expiryDate, style: .date)
                                if let days = item.daysUntilExpiry {
                                    Text(days < 0
                                         ? lm.s.expiryDaysExpired(days: days)
                                         : days == 0
                                            ? lm.s.expiryToday
                                            : lm.s.expiryDaysRemaining(days: days))
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
                            Text(lm.s.notes)
                                .foregroundStyle(.secondary)
                            Text(item.notes)
                        }
                    }

                    Divider()

                    HStack {
                        Text(lm.s.addedOn)
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
                        Label(lm.s.edit, systemImage: "pencil")
                    }

                    Button {
                        showingMoveSheet = true
                    } label: {
                        Label(lm.s.moveTo, systemImage: "arrow.right.doc.on.clipboard")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label(lm.s.delete, systemImage: "trash")
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
        .alert(lm.s.confirmDelete, isPresented: $showingDeleteConfirm) {
            Button(lm.s.delete, role: .destructive) {
                MongoSyncService.deleteItem(item)
                viewContext.delete(item)
                try? viewContext.save()
                dismiss()
            }
            Button(lm.s.cancel, role: .cancel) {}
        } message: {
            Text(lm.s.deleteItemConfirm(name: item.name))
        }
    }
}
