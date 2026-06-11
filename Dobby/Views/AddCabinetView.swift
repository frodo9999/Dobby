import SwiftUI
import CoreData

struct AddCabinetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lm: LanguageManager
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
                Section(lm.s.cabinetName) {
                    TextField(lm.s.cabinetNamePlaceholder, text: $name)
                }

                Section(lm.s.chooseIcon) {
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
            .navigationTitle(isEditing ? lm.s.editCabinet : lm.s.addCabinet)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.s.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? lm.s.save : lm.s.add) {
                        if let cabinet = existingCabinet {
                            cabinet.name = name
                            cabinet.icon = selectedIcon
                        } else {
                            let cabinet = Cabinet(context: viewContext)
                            cabinet.name = name
                            cabinet.icon = selectedIcon
                            cabinet.sortOrder = 0
                            cabinet.room = room
                        }
                        try? viewContext.save()
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
