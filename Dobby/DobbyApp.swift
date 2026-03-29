import SwiftUI
import SwiftData
import UserNotifications

@main
struct DobbyApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: Room.self, Cabinet.self, Item.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationPermission()
                }
        }
        .modelContainer(modelContainer)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}
