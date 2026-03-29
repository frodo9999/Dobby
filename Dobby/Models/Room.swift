import Foundation
import SwiftData

@Model
final class Room: Hashable {
    static func == (lhs: Room, rhs: Room) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(persistentModelID)
    }

    var name: String
    var icon: String
    @Relationship(deleteRule: .cascade, inverse: \Cabinet.room)
    var cabinets: [Cabinet] = []
    var createdAt: Date
    var sortOrder: Int

    init(name: String, icon: String = "door.left.hand.closed", sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }

    var itemCount: Int {
        cabinets.reduce(0) { $0 + $1.items.count }
    }
}
