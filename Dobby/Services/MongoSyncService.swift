import Foundation

/// Syncs manual add / edit / delete operations to MongoDB + Elasticsearch on the backend.
/// All calls are fire-and-forget — failures are logged but never surface to the user.
enum MongoSyncService {

    private static let baseURL = "https://dobby-agent-172253357017.us-central1.run.app"

    // MARK: - Upsert (add or edit)

    /// Call after saving a new or edited item in AddItemView.
    static func upsertItem(_ item: Item, oldName: String? = nil) {
        guard let cabinet = item.cabinet, let room = cabinet.room else { return }

        var body: [String: Any] = [
            "name": item.name,
            "category": ItemCategory.from(string: item.category)?.englishName ?? item.category,
            "quantity": item.quantity,
            "notes": item.notes,
            "cabinetName": cabinet.name,
            "roomName": room.name,
            "oldName": oldName ?? ""
        ]
        if let expiry = item.expiryDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            body["expiryDate"] = formatter.string(from: expiry)
        }

        post(path: "/items/sync", body: body)
    }

    // MARK: - Delete

    /// Call before deleting an item in ItemDetailView.
    static func deleteItem(_ item: Item) {
        guard let cabinet = item.cabinet, let room = cabinet.room else { return }

        let body: [String: Any] = [
            "name": item.name,
            "cabinetName": cabinet.name,
            "roomName": room.name
        ]
        delete(path: "/items/sync", body: body)
    }

    // MARK: - Private helpers

    private static func post(path: String, body: [String: Any]) {
        guard let url = URL(string: baseURL + path),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error { print("⚠️ MongoSyncService POST \(path) failed: \(error)") }
            else { print("✅ MongoSyncService POST \(path) succeeded") }
        }.resume()
    }

    private static func delete(path: String, body: [String: Any]) {
        guard let url = URL(string: baseURL + path),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error { print("⚠️ MongoSyncService DELETE \(path) failed: \(error)") }
            else { print("✅ MongoSyncService DELETE \(path) succeeded") }
        }.resume()
    }
}
