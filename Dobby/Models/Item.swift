import Foundation
import SwiftUI
import CoreData

@objc(Item)
public class Item: NSManagedObject, Identifiable {
    @NSManaged public var name: String
    @NSManaged public var category: String
    @NSManaged public var quantity: Int64
    @NSManaged public var notes: String
    @NSManaged public var photoData: Data?
    @NSManaged public var expiryDate: Date?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var cabinet: Cabinet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        if primitiveValue(forKey: "createdAt") == nil {
            setPrimitiveValue(now, forKey: "createdAt")
        }
        if primitiveValue(forKey: "updatedAt") == nil {
            setPrimitiveValue(now, forKey: "updatedAt")
        }
        if primitiveValue(forKey: "quantity") == nil {
            setPrimitiveValue(Int64(1), forKey: "quantity")
        }
    }

    var locationDescription: String {
        let cabinetName = cabinet?.name ?? "未分配"
        let roomName = cabinet?.room?.name ?? "未分配"
        return "\(roomName) · \(cabinetName)"
    }

    var expiryStatus: ExpiryStatus {
        guard let expiryDate else { return .none }
        let now = Date()
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: now, to: expiryDate).day ?? 0
        if expiryDate < now {
            return .expired
        } else if daysUntilExpiry <= 7 {
            return .expiringSoon
        } else {
            return .ok
        }
    }

    var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day
    }
}

enum ExpiryStatus {
    case none, ok, expiringSoon, expired

    var color: Color {
        switch self {
        case .none, .ok: return .clear
        case .expiringSoon: return .orange
        case .expired: return .red
        }
    }

    var label: String {
        switch self {
        case .none: return ""
        case .ok: return "未过期"
        case .expiringSoon: return "即将过期"
        case .expired: return "已过期"
        }
    }
}

enum ItemCategory: String, CaseIterable {
    case clothing = "衣物"
    case food = "食品"
    case electronics = "电子产品"
    case documents = "文件"
    case tools = "工具"
    case medicine = "药品"
    case kitchenware = "厨具"
    case toys = "玩具"
    case books = "书籍"
    case other = "其他"

    var icon: String {
        switch self {
        case .clothing: return "tshirt"
        case .food: return "fork.knife"
        case .electronics: return "laptopcomputer"
        case .documents: return "doc.text"
        case .tools: return "wrench.and.screwdriver"
        case .medicine: return "cross.case"
        case .kitchenware: return "frying.pan"
        case .toys: return "teddybear"
        case .books: return "book"
        case .other: return "archivebox"
        }
    }
}
