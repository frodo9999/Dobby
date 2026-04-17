import Foundation
import CoreData

@objc(Cabinet)
public class Cabinet: NSManagedObject, Identifiable {
    @NSManaged public var name: String
    @NSManaged public var icon: String
    @NSManaged public var createdAt: Date
    @NSManaged public var sortOrder: Int64
    @NSManaged public var room: Room?
    @NSManaged public var items: NSSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if primitiveValue(forKey: "createdAt") == nil {
            setPrimitiveValue(Date(), forKey: "createdAt")
        }
    }

    var itemsArray: [Item] {
        let set = items as? Set<Item> ?? []
        return Array(set)
    }
}

extension Cabinet {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: Item)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: Item)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}
