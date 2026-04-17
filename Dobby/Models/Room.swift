import Foundation
import CoreData

@objc(Room)
public class Room: NSManagedObject, Identifiable {
    @NSManaged public var name: String
    @NSManaged public var icon: String
    @NSManaged public var createdAt: Date
    @NSManaged public var sortOrder: Int64
    @NSManaged public var cabinets: NSSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if primitiveValue(forKey: "createdAt") == nil {
            setPrimitiveValue(Date(), forKey: "createdAt")
        }
    }

    var cabinetsArray: [Cabinet] {
        let set = cabinets as? Set<Cabinet> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    var itemCount: Int {
        cabinetsArray.reduce(0) { $0 + $1.itemsArray.count }
    }
}

extension Room {
    @objc(addCabinetsObject:)
    @NSManaged public func addToCabinets(_ value: Cabinet)

    @objc(removeCabinetsObject:)
    @NSManaged public func removeFromCabinets(_ value: Cabinet)

    @objc(addCabinets:)
    @NSManaged public func addToCabinets(_ values: NSSet)

    @objc(removeCabinets:)
    @NSManaged public func removeFromCabinets(_ values: NSSet)
}
