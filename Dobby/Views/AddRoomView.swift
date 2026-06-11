import SwiftUI
import CoreData

struct AddRoomView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lm: LanguageManager

    var existingRoom: Room?

    @State private var name = ""
    @State private var selectedIcon = "door.left.hand.closed"

    private var isEditing: Bool { existingRoom != nil }

    private let roomIcons = [
        "door.left.hand.closed",
        "bed.double",
        "sofa",
        "bathtub",
        "refrigerator",
        "oven",
        "washer",
        "car",
        "figure.walk",
        "books.vertical",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(lm.s.roomName) {
                    TextField(lm.s.roomNamePlaceholder, text: $name)
                }

                Section(lm.s.chooseIcon) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(roomIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? lm.s.editRoom : lm.s.addRoom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.s.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? lm.s.save : lm.s.add) {
                        if let room = existingRoom {
                            room.name = name
                            room.icon = selectedIcon
                        } else {
                            let room = Room(context: viewContext)
                            room.name = name
                            room.icon = selectedIcon
                            room.sortOrder = 0
                        }
                        try? viewContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let room = existingRoom {
                    name = room.name
                    selectedIcon = room.icon
                }
            }
        }
    }
}
