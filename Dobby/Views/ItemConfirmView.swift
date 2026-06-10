import SwiftUI

/// Single-item confirmation screen.
/// Pre-filled from AI recognition result; user edits any field and confirms.
struct ItemConfirmView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let recognitionResult: ItemRecognitionResult
    let rooms: [Room]
    let geminiService: GeminiServiceProtocol

    // Editable fields — pre-filled from AI, user values always win
    @State private var name: String
    @State private var category: ItemCategory
    @State private var quantity: Int
    @State private var hasExpiryDate: Bool
    @State private var expiryDate: Date
    @State private var notes: String = ""

    // Cabinet selection
    @State private var selectedCabinet: Cabinet?
    @State private var isCabinetRequired = false   // flash if user tries to save without one

    init(recognitionResult: ItemRecognitionResult, rooms: [Room], geminiService: GeminiServiceProtocol) {
        self.recognitionResult = recognitionResult
        self.rooms = rooms
        self.geminiService = geminiService

        _name     = State(initialValue: recognitionResult.name)
        _category = State(initialValue: recognitionResult.category ?? .other)
        _quantity = State(initialValue: recognitionResult.quantity)
        _hasExpiryDate = State(initialValue: recognitionResult.expiryDate != nil)
        _expiryDate    = State(initialValue: recognitionResult.expiryDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Basic Info
                Section("物品信息") {
                    TextField("物品名称", text: $name)
                    Picker("分类", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Stepper("数量：\(quantity)", value: $quantity, in: 1...999)
                }

                // MARK: Expiry
                Section("保质期") {
                    Toggle("设置保质期", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("过期日期", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                // MARK: Notes
                Section("备注") {
                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // MARK: Cabinet
                Section {
                    NavigationLink {
                        CabinetPickerView(rooms: rooms, selectedCabinet: $selectedCabinet)
                    } label: {
                        HStack {
                            Text("存放位置")
                            Spacer()
                            if let cabinet = selectedCabinet {
                                Text(cabinet.room.map { "\($0.name) · \(cabinet.name)" } ?? cabinet.name)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("请选择")
                                    .foregroundStyle(isCabinetRequired ? .red : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("存放位置")
                } footer: {
                    if isCabinetRequired {
                        Text("请选择存放位置后再保存")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("确认物品信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveItem() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                inferCabinet()
            }
        }
    }

    // MARK: - Cabinet Inference

    private func inferCabinet() {
        guard selectedCabinet == nil else { return }
        let allCabinets = rooms.flatMap { $0.cabinetsArray }
        selectedCabinet = CabinetInferenceService.findBestCabinet(
            for: recognitionResult,
            in: allCabinets
        )
    }

    // MARK: - Save

    private func saveItem() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let cabinet = selectedCabinet else {
            isCabinetRequired = true
            return
        }
        isCabinetRequired = false

        let item = Item(context: viewContext)
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.category = category.rawValue
        item.quantity = Int64(quantity)
        item.notes = notes.trimmingCharacters(in: .whitespaces)
        item.expiryDate = hasExpiryDate ? expiryDate : nil
        item.cabinet = cabinet
        item.updatedAt = Date()

        if hasExpiryDate {
            NotificationManager.scheduleExpiryNotification(
                itemName: item.name,
                itemID: item.objectID.uriRepresentation().absoluteString,
                expiryDate: expiryDate
            )
        }

        // Rebuild cabinet summary
        cabinet.rebuildContentSummary()

        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Cabinet Picker

/// Drill-down room → cabinet picker used by ItemConfirmView and ReceiptReviewView.
struct CabinetPickerView: View {
    let rooms: [Room]
    @Binding var selectedCabinet: Cabinet?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(rooms) { room in
                Section(header: Label(room.name, systemImage: room.icon)) {
                    ForEach(room.cabinetsArray) { cabinet in
                        Button {
                            selectedCabinet = cabinet
                            dismiss()
                        } label: {
                            HStack {
                                Label(cabinet.name, systemImage: cabinet.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCabinet == cabinet {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("选择柜子")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ItemConfirmView(
        recognitionResult: ItemRecognitionResult(name: "牛奶", category: .food, quantity: 2),
        rooms: [],
        geminiService: MockGeminiService()
    )
    .environment(\.managedObjectContext,
        PersistenceController.preview.container.viewContext)
}
