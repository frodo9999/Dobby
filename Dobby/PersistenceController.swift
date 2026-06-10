import Foundation
import CoreData
import CloudKit

final class PersistenceController {
    static let shared = PersistenceController(inMemory: false)

    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentCloudKitContainer

    // MARK: - Managed Object Model (programmatic)

    static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        // Entities
        let roomEntity = NSEntityDescription()
        roomEntity.name = "Room"
        roomEntity.managedObjectClassName = NSStringFromClass(Room.self)

        let cabinetEntity = NSEntityDescription()
        cabinetEntity.name = "Cabinet"
        cabinetEntity.managedObjectClassName = NSStringFromClass(Cabinet.self)

        let itemEntity = NSEntityDescription()
        itemEntity.name = "Item"
        itemEntity.managedObjectClassName = NSStringFromClass(Item.self)

        // MARK: Room attributes
        // NOTE: CloudKit requires all attributes to be optional OR have default values.
        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = true, defaultValue: Any? = nil, allowsExternalBinaryDataStorage: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            if let defaultValue { a.defaultValue = defaultValue }
            a.allowsExternalBinaryDataStorage = allowsExternalBinaryDataStorage
            return a
        }

        roomEntity.properties = [
            attr("name", .stringAttributeType, defaultValue: ""),
            attr("icon", .stringAttributeType, defaultValue: "door.left.hand.closed"),
            attr("createdAt", .dateAttributeType),
            attr("sortOrder", .integer64AttributeType, defaultValue: 0),
        ]

        cabinetEntity.properties = [
            attr("name", .stringAttributeType, defaultValue: ""),
            attr("icon", .stringAttributeType, defaultValue: "cabinet"),
            attr("createdAt", .dateAttributeType),
            attr("sortOrder", .integer64AttributeType, defaultValue: 0),
            attr("contentSummary", .stringAttributeType, defaultValue: ""),
        ]

        itemEntity.properties = [
            attr("name", .stringAttributeType, defaultValue: ""),
            attr("category", .stringAttributeType, defaultValue: ""),
            attr("quantity", .integer64AttributeType, defaultValue: 1),
            attr("notes", .stringAttributeType, defaultValue: ""),
            attr("photoData", .binaryDataAttributeType, allowsExternalBinaryDataStorage: true),
            attr("expiryDate", .dateAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
        ]

        // MARK: Relationships
        // Room.cabinets <-->> Cabinet.room
        let roomCabinets = NSRelationshipDescription()
        roomCabinets.name = "cabinets"
        roomCabinets.destinationEntity = cabinetEntity
        roomCabinets.minCount = 0
        roomCabinets.maxCount = 0 // to-many
        roomCabinets.deleteRule = .cascadeDeleteRule
        roomCabinets.isOptional = true

        let cabinetRoom = NSRelationshipDescription()
        cabinetRoom.name = "room"
        cabinetRoom.destinationEntity = roomEntity
        cabinetRoom.minCount = 0
        cabinetRoom.maxCount = 1 // to-one
        cabinetRoom.deleteRule = .nullifyDeleteRule
        cabinetRoom.isOptional = true

        roomCabinets.inverseRelationship = cabinetRoom
        cabinetRoom.inverseRelationship = roomCabinets

        // Cabinet.items <-->> Item.cabinet
        let cabinetItems = NSRelationshipDescription()
        cabinetItems.name = "items"
        cabinetItems.destinationEntity = itemEntity
        cabinetItems.minCount = 0
        cabinetItems.maxCount = 0
        cabinetItems.deleteRule = .cascadeDeleteRule
        cabinetItems.isOptional = true

        let itemCabinet = NSRelationshipDescription()
        itemCabinet.name = "cabinet"
        itemCabinet.destinationEntity = cabinetEntity
        itemCabinet.minCount = 0
        itemCabinet.maxCount = 1
        itemCabinet.deleteRule = .nullifyDeleteRule
        itemCabinet.isOptional = true

        cabinetItems.inverseRelationship = itemCabinet
        itemCabinet.inverseRelationship = cabinetItems

        roomEntity.properties.append(roomCabinets)
        cabinetEntity.properties.append(contentsOf: [cabinetRoom, cabinetItems])
        itemEntity.properties.append(itemCabinet)

        model.entities = [roomEntity, cabinetEntity, itemEntity]
        return model
    }()

    // MARK: - Init

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(
            name: "Dobby",
            managedObjectModel: Self.managedObjectModel
        )

        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.url = URL(fileURLWithPath: "/dev/null")
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        } else {
            let fm = FileManager.default
            let baseURL: URL = {
                if let url = try? fm.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ) {
                    return url
                }
                return fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            }()
            try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)

            // Private store
            let privateURL = baseURL.appendingPathComponent("Dobby-Private.sqlite")
            let privateDesc = NSPersistentStoreDescription(url: privateURL)
            privateDesc.configuration = nil
            privateDesc.shouldMigrateStoreAutomatically = true
            privateDesc.shouldInferMappingModelAutomatically = true
            privateDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let privateOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.dobby.home-inventory"
            )
            privateOptions.databaseScope = .private
            privateDesc.cloudKitContainerOptions = privateOptions

            // Shared store
            let sharedURL = baseURL.appendingPathComponent("Dobby-Shared.sqlite")
            let sharedDesc = NSPersistentStoreDescription(url: sharedURL)
            sharedDesc.configuration = nil
            sharedDesc.shouldMigrateStoreAutomatically = true
            sharedDesc.shouldInferMappingModelAutomatically = true
            sharedDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            sharedDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let sharedOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.dobby.home-inventory"
            )
            sharedOptions.databaseScope = .shared
            sharedDesc.cloudKitContainerOptions = sharedOptions

            container.persistentStoreDescriptions = [privateDesc, sharedDesc]
        }

        container.loadPersistentStores { desc, error in
            if let error = error {
                // In debug, log. In production you might handle gracefully.
                print("Core Data store load error for \(desc.url?.lastPathComponent ?? "?"): \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // CloudKit schema has been initialized; no need to call initializeCloudKitSchema again.
    }
}
