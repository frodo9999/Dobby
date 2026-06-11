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
        let fallback = LanguageManager.shared.s.unassigned
        let cabinetName = cabinet?.name ?? fallback
        let roomName = cabinet?.room?.name ?? fallback
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
        let en = LanguageManager.shared.isEnglish
        switch self {
        case .none: return ""
        case .ok: return en ? "Not Expired" : "未过期"
        case .expiringSoon: return en ? "Expiring Soon" : "即将过期"
        case .expired: return en ? "Expired" : "已过期"
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

    /// English display name — also used to match backend responses when language == "en"
    var englishName: String {
        switch self {
        case .clothing:    return "Clothing"
        case .food:        return "Food"
        case .electronics: return "Electronics"
        case .documents:   return "Documents"
        case .tools:       return "Tools"
        case .medicine:    return "Medicine"
        case .kitchenware: return "Kitchenware"
        case .toys:        return "Toys"
        case .books:       return "Books"
        case .other:       return "Other"
        }
    }

    /// Returns the appropriate display name for the current app language.
    /// rawValue (Chinese) is always used as the CoreData storage key — never changes.
    var displayName: String {
        LanguageManager.shared.isEnglish ? englishName : rawValue
    }

    /// Match against either Chinese rawValue or English name — handles both backend languages.
    static func from(string: String?) -> ItemCategory? {
        guard let string else { return nil }
        return allCases.first { $0.rawValue == string || $0.englishName == string }
    }

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
