import SwiftUI
import SwiftData

struct AddCabinetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let room: Room

    var existingCabinet: Cabinet?

    @State private var name = ""
    @State private var selectedIcon = "cabinet"

    private var isEditing: Bool { existingCabinet != nil }

    private let cabinetIcons = [
        "cabinet",
        "archivebox",
        "tray.2",
        "shippingbox",
        "bag",
        "suitcase",
        "backpack",
        "basket",
        "cube.box",
        "square.stack.3d.up",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("柜子名称") {
                    TextField("例如：衣柜、书柜、鞋柜", text: $name)
                }

                Section("选择图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(cabinetIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color.orange.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "编辑柜子" : "添加柜子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
                        if let cabinet = existingCabinet {
                            cabinet.name = name
                            cabinet.icon = selectedIcon
                        } else {
                            let cabinet = Cabinet(name: name, icon: selectedIcon, room: room)
                            modelContext.insert(cabinet)
                            room.cabinets.append(cabinet)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let cabinet = existingCabinet {
                    name = cabinet.name
                    selectedIcon = cabinet.icon
                }
            }
        }
    }
}
