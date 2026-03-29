import Foundation
import SwiftData

@Model
final class Cabinet: Hashable {
    static func == (lhs: Cabinet, rhs: Cabinet) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(persistentModelID)
    }

    var name: String
    var icon: String
    var room: Room?
    @Relationship(deleteRule: .cascade, inverse: \Item.cabinet)
    var items: [Item] = []
    var createdAt: Date
    var sortOrder: Int

    init(name: String, icon: String = "cabinet", room: Room? = nil, sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.room = room
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}
