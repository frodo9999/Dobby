import Foundation
import CoreData

@objc(Cabinet)
public class Cabinet: NSManagedObject, Identifiable {
    @NSManaged public var name: String
    @NSManaged public var icon: String
    @NSManaged public var createdAt: Date
    @NSManaged public var sortOrder: Int64
    @NSManaged public var contentSummary: String
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

    /// Rebuilds `contentSummary` from the current items in this cabinet.
    /// Call after adding or removing items, then save the context.
    func rebuildContentSummary() {
        let names = itemsArray.map { $0.name }.filter { !$0.isEmpty }
        let categories = Array(Set(itemsArray.map { $0.category }.filter { !$0.isEmpty }))

        var parts: [String] = []
        if !categories.isEmpty { parts.append(categories.joined(separator: "、")) }
        // Include up to 5 distinct item names for richer matching
        let sampleNames = Array(Set(names)).prefix(5)
        if !sampleNames.isEmpty { parts.append(sampleNames.joined(separator: "、")) }

        contentSummary = parts.joined(separator: "；")
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
