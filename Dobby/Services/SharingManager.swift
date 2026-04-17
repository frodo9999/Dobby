import Foundation
import CoreData
import CloudKit
import UIKit

enum SharingError: Error {
    case noSharedStore
    case shareCreationFailed
}

final class SharingManager {
    static let shared = SharingManager()

    let ckContainer = CKContainer(identifier: "iCloud.com.dobby.home-inventory")

    var persistentContainer: NSPersistentCloudKitContainer {
        PersistenceController.shared.container
    }

    /// Returns an existing CKShare for a Room, or creates a new one.
    func shareRoom(_ room: Room, completion: @escaping (Result<(CKShare, CKContainer), Error>) -> Void) {
        let container = persistentContainer

        // Check if already shared
        if let existing = try? container.fetchShares(matching: [room.objectID])[room.objectID] {
            completion(.success((existing, ckContainer)))
            return
        }

        container.share([room], to: nil) { [weak self] _, share, _, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let share = share else {
                completion(.failure(SharingError.shareCreationFailed))
                return
            }
            share[CKShare.SystemFieldKey.title] = room.name as CKRecordValue
            completion(.success((share, self.ckContainer)))
        }
    }

    /// Accept a share invitation into the shared store.
    func acceptShare(metadata: CKShare.Metadata) {
        let container = persistentContainer
        guard let sharedStore = container.persistentStoreCoordinator.persistentStores.first(where: {
            $0.url?.lastPathComponent.contains("Shared") == true
        }) else {
            print("SharingManager: no shared store available")
            return
        }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error = error {
                print("SharingManager: accept failed: \(error)")
            }
        }
    }
}

// MARK: - App/Scene Delegate for share acceptance

final class DobbyAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = DobbySceneDelegate.self
        return config
    }
}

final class DobbySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        SharingManager.shared.acceptShare(metadata: cloudKitShareMetadata)
    }
}
