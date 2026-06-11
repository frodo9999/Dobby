import Foundation

/// Infers the best cabinet to assign a recognized item to.
///
/// Priority:
///   1. A cabinet that already contains an item with the same name (case-insensitive).
///   2. A cabinet whose `contentSummary` mentions the item's category or name.
///   3. nil — no confident match; the user must choose manually.
struct CabinetInferenceService {

    /// Returns the most appropriate cabinet for a recognized item, or nil if none match.
    static func findBestCabinet(
        for item: ItemRecognitionResult,
        in cabinets: [Cabinet]
    ) -> Cabinet? {
        guard !cabinets.isEmpty else { return nil }

        let itemNameLower = item.name.lowercased()
        let categoryRaw = item.category?.rawValue ?? ""                      // Chinese, e.g. "药品"
        let categoryEnglish = item.category?.englishName.lowercased() ?? "" // English, e.g. "medicine"

        // Priority 1: Cabinet already holds an item with the same name
        for cabinet in cabinets {
            let existingNames = cabinet.itemsArray.map { $0.name.lowercased() }
            if existingNames.contains(itemNameLower) {
                return cabinet
            }
        }

        // Priority 2: Cabinet summary mentions the category (Chinese or English) or item name
        for cabinet in cabinets {
            let summary = cabinet.contentSummary.lowercased()
            if !summary.isEmpty {
                let categoryMatch = (!categoryRaw.isEmpty && summary.contains(categoryRaw.lowercased()))
                               || (!categoryEnglish.isEmpty && summary.contains(categoryEnglish))
                let nameMatch = summary.contains(itemNameLower)
                if categoryMatch || nameMatch {
                    return cabinet
                }
            }
        }

        // Priority 3: Cabinet name matches the item category (e.g. "Medicine Cabinet" → Medicine)
        let categoryKeywords: [ItemCategory: [String]] = [
            .food:        ["refrigerator", "fridge", "pantry", "freezer", "kitchen"],
            .medicine:    ["medicine", "pharmacy", "health", "first aid"],
            .clothing:    ["wardrobe", "closet", "drawer", "dresser"],
            .electronics: ["desk", "office", "tv", "stand", "shelf"],
            .books:       ["bookshelf", "bookcase", "library", "shelf"],
            .tools:       ["garage", "toolbox", "workshop", "storage"],
            .kitchenware: ["kitchen", "pantry", "cabinet", "drawer"],
            .toys:        ["playroom", "toy", "kids", "children"],
            .documents:   ["office", "desk", "filing", "drawer"],
            .other:       [],
        ]
        if let category = item.category, let keywords = categoryKeywords[category] {
            for cabinet in cabinets {
                let cabinetNameLower = cabinet.name.lowercased()
                if keywords.contains(where: { cabinetNameLower.contains($0) }) {
                    return cabinet
                }
            }
        }

        return nil
    }
}
