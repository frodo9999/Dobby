import SwiftUI
import CloudKit
import UIKit
import CoreData

/// Helper to present UICloudSharingController directly via UIKit.
final class CloudSharingPresenter {
    static let shared = CloudSharingPresenter()

    private var delegate: SharingDelegate?

    private let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    /// Present sharing controller for an existing share.
    func presentExistingShare(_ share: CKShare, container: CKContainer) {
        let controller = UICloudSharingController(share: share, container: container)
        let delegate = SharingDelegate()
        self.delegate = delegate
        controller.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
        controller.delegate = delegate
        present(controller)
    }

    /// Share the entire CloudKit zone so all current and future data is included.
    func presentZoneShare(ckContainer: CKContainer, onError: ((String) -> Void)? = nil) {
        let privateDB = ckContainer.privateCloudDatabase

        privateDB.fetch(withRecordZoneID: zoneID) { [weak self] zone, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    onError?("无法访问 CloudKit Zone：\(error.localizedDescription)")
                }
                return
            }

            self.fetchExistingZoneShare(privateDB: privateDB) { existingShare in
                if let existingShare = existingShare {
                    DispatchQueue.main.async {
                        self.presentExistingShare(existingShare, container: ckContainer)
                    }
                } else {
                    self.createZoneShare(privateDB: privateDB, ckContainer: ckContainer, onError: onError)
                }
            }
        }
    }

    private func fetchExistingZoneShare(privateDB: CKDatabase, completion: @escaping (CKShare?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "cloudkit.share", predicate: predicate)
        privateDB.fetch(withQuery: query, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchResults, _)):
                let share = matchResults.compactMap { _, recordResult in
                    try? recordResult.get() as? CKShare
                }.first
                completion(share)
            case .failure:
                completion(nil)
            }
        }
    }

    private func createZoneShare(privateDB: CKDatabase, ckContainer: CKContainer, onError: ((String) -> Void)? = nil) {
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Dobby 我的家" as CKRecordValue
        share.publicPermission = .none

        let saveOp = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
        saveOp.perRecordSaveBlock = { [weak self] recordID, result in
            switch result {
            case .success(let savedRecord):
                guard let savedShare = savedRecord as? CKShare else { return }
                DispatchQueue.main.async {
                    self?.presentExistingShare(savedShare, container: ckContainer)
                }
            case .failure(let error):
                let ckError = error as? CKError ?? (error as NSError).userInfo[NSUnderlyingErrorKey] as? CKError
                if ckError?.code == .serverRecordChanged {
                    privateDB.fetch(withRecordID: recordID) { record, fetchError in
                        DispatchQueue.main.async {
                            if let existingShare = record as? CKShare {
                                self?.presentExistingShare(existingShare, container: ckContainer)
                            } else {
                                onError?("共享失败：无法获取已有共享")
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        onError?("共享失败：\(error.localizedDescription)")
                    }
                }
            }
        }
        privateDB.add(saveOp)
    }

    private func present(_ controller: UICloudSharingController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(controller, animated: true)
    }
}

private final class SharingDelegate: NSObject, UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "Dobby 我的家"
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
}
