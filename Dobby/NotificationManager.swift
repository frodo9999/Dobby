import Foundation
import UserNotifications

struct NotificationManager {
    static func scheduleExpiryNotification(itemName: String, itemID: String, expiryDate: Date) {
        let center = UNUserNotificationCenter.current()

        // Remove old notifications for this item
        center.removePendingNotificationRequests(withIdentifiers: [itemID])

        // Schedule 3 days before expiry
        let threeDaysBefore = Calendar.current.date(byAdding: .day, value: -3, to: expiryDate)!
        if threeDaysBefore > Date() {
            let content = UNMutableNotificationContent()
            content.title = "物品即将过期"
            content.body = "「\(itemName)」将在3天后过期"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: threeDaysBefore)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: itemID, content: content, trigger: trigger)
            center.add(request)
        }

        // Schedule on expiry day
        let expiryDayID = "\(itemID)-expiry"
        center.removePendingNotificationRequests(withIdentifiers: [expiryDayID])

        if expiryDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "物品已过期"
            content.body = "「\(itemName)」今天到期了"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day], from: expiryDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: expiryDayID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancelExpiryNotification(itemID: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [itemID, "\(itemID)-expiry"])
    }
}
