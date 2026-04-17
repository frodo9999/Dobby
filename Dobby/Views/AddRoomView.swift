import SwiftUI
import CoreData

struct AddRoomView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

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
                Section("房间名称") {
                    TextField("例如：主卧、厨房", text: $name)
                }

                Section("选择图标") {
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
            .navigationTitle(isEditing ? "编辑房间" : "添加房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
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
