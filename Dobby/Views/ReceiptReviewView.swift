import SwiftUI

/// Shows all items recognized from a receipt in an editable list.
/// The user can edit any field, assign cabinets, delete rows, then save all at once.
struct ReceiptReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let rooms: [Room]

    @State private var rows: [ReceiptRow]
    @State private var showingSaveConfirm = false
    @State private var savedCount: Int?

    init(recognitionResults: [ItemRecognitionResult], rooms: [Room]) {
        self.rooms = rooms
        let allCabinets = rooms.flatMap { $0.cabinetsArray }
        _rows = State(initialValue: recognitionResults.map { result in
            let inferredCabinet = CabinetInferenceService.findBestCabinet(for: result, in: allCabinets)
            return ReceiptRow(result: result, cabinet: inferredCabinet)
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty {
                    ContentUnavailableView("没有识别到物品", systemImage: "doc.text.magnifyingglass",
                        description: Text("请重新拍摄小票"))
                } else {
                    List {
                        ForEach($rows) { $row in
                            ReceiptRowView(row: $row, rooms: rooms)
                        }
                        .onDelete { indexSet in
                            rows.remove(atOffsets: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("确认小票物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存全部（\(rows.count)）") {
                        saveAll()
                    }
                    .fontWeight(.semibold)
                    .disabled(rows.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert("保存成功", isPresented: Binding(
                get: { savedCount != nil },
                set: { if !$0 { savedCount = nil; dismiss() } }
            )) {
                Button("好") { savedCount = nil; dismiss() }
            } message: {
                Text("已添加 \(savedCount ?? 0) 件物品")
            }
        }
    }

    // MARK: - Save

    private func saveAll() {
        let allCabinets = rooms.flatMap { $0.cabinetsArray }
        var count = 0

        for row in rows {
            guard !row.name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            // Determine cabinet: user-selected or inferred
            let cabinet = row.cabinet ?? CabinetInferenceService.findBestCabinet(
                for: ItemRecognitionResult(name: row.name, category: row.category),
                in: allCabinets
            )
            guard let cabinet else { continue }  // skip rows without a cabinet

            let item = Item(context: viewContext)
            item.name = row.name.trimmingCharacters(in: .whitespaces)
            item.category = row.category.rawValue
            item.quantity = Int64(row.quantity)
            item.notes = ""
            item.expiryDate = row.hasExpiryDate ? row.expiryDate : nil
            item.cabinet = cabinet
            item.updatedAt = Date()

            if row.hasExpiryDate {
                NotificationManager.scheduleExpiryNotification(
                    itemName: item.name,
                    itemID: item.objectID.uriRepresentation().absoluteString,
                    expiryDate: row.expiryDate
                )
            }
            count += 1
        }

        // Rebuild summaries for all affected cabinets
        let affectedCabinets = Set(rows.compactMap { $0.cabinet })
        for cabinet in affectedCabinets {
            cabinet.rebuildContentSummary()
        }

        try? viewContext.save()
        savedCount = count
    }
}

// MARK: - Row Model

struct ReceiptRow: Identifiable {
    let id = UUID()
    var name: String
    var category: ItemCategory
    var quantity: Int
    var hasExpiryDate: Bool
    var expiryDate: Date
    var cabinet: Cabinet?

    init(result: ItemRecognitionResult, cabinet: Cabinet?) {
        self.name = result.name
        self.category = result.category ?? .other
        self.quantity = result.quantity
        self.hasExpiryDate = result.expiryDate != nil
        self.expiryDate = result.expiryDate ?? Date()
        self.cabinet = cabinet
    }
}

// MARK: - Row View

struct ReceiptRowView: View {
    @Binding var row: ReceiptRow
    let rooms: [Room]

    private var showsExpiry: Bool {
        row.category == .food || row.category == .medicine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Row 1: Name + Category
            HStack {
                TextField("物品名称", text: $row.name)
                    .font(.headline)
                Spacer()
                Picker("分类", selection: $row.category) {
                    ForEach(ItemCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Row 2: Quantity counter  "— N +" (right-aligned)
            HStack(spacing: 0) {
                Spacer()
                Button {
                    if row.quantity > 1 { row.quantity -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("\(row.quantity)")
                    .monospacedDigit()
                    .frame(minWidth: 40)
                    .multilineTextAlignment(.center)

                Button {
                    if row.quantity < 999 { row.quantity += 1 }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .font(.subheadline)

            // Row 3: Cabinet
            NavigationLink {
                CabinetPickerView(rooms: rooms, selectedCabinet: $row.cabinet)
            } label: {
                HStack {
                    Image(systemName: "cabinet")
                        .foregroundStyle(.orange)
                    if let cabinet = row.cabinet {
                        Text(cabinet.room.map { "\($0.name) · \(cabinet.name)" } ?? cabinet.name)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("请选择存放位置")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
            }

            // Row 4: Expiry — only for food and medicine
            if showsExpiry {
                HStack {
                    Toggle("保质期", isOn: $row.hasExpiryDate)
                        .labelsHidden()
                    Text("保质期")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    if row.hasExpiryDate {
                        DatePicker("", selection: $row.expiryDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ReceiptReviewView(
        recognitionResults: [
            ItemRecognitionResult(name: "苹果汁", category: .food, quantity: 2),
            ItemRecognitionResult(name: "洗发水", category: .other, quantity: 1)
        ],
        rooms: []
    )
    .environment(\.managedObjectContext,
        PersistenceController.preview.container.viewContext)
}
