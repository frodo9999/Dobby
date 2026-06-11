import Foundation
import SwiftUI

// MARK: - Models

struct DiscoveryResult: Decodable {
    let query: String
    let found: Bool
    let answer: String       // mapped from "summary"
    let items: [DiscoveryItem]
    let explanation: String? // mapped from "suggestion"

    enum CodingKeys: String, CodingKey {
        case query, found, items
        case answer = "summary"
        case explanation = "suggestion"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        query       = try c.decode(String.self, forKey: .query)
        found       = try c.decode(Bool.self, forKey: .found)
        answer      = (try? c.decode(String.self, forKey: .answer)) ?? ""
        items       = (try? c.decode([DiscoveryItem].self, forKey: .items)) ?? []
        explanation = try? c.decode(String.self, forKey: .explanation)
    }
}

struct DiscoveryItem: Decodable {
    let name: String
    let category: String?
    let quantity: Int
    let location: String
    let matchType: MatchType?

    enum CodingKeys: String, CodingKey {
        case name, category, quantity, location
        case matchType = "matchType"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name      = try c.decode(String.self, forKey: .name)
        category  = try? c.decode(String.self, forKey: .category)
        quantity  = (try? c.decode(Int.self, forKey: .quantity)) ?? 1
        location  = (try? c.decode(String.self, forKey: .location)) ?? ""
        let raw   = try? c.decode(String.self, forKey: .matchType)
        matchType = raw.flatMap { MatchType(rawValue: $0) }
    }
}

enum MatchType: String, Decodable {
    case exact
    case substitute
    case related

    var label: String {
        let en = LanguageManager.shared.isEnglish
        switch self {
        case .exact:      return en ? "Exact Match" : "直接匹配"
        case .substitute: return en ? "Substitute"  : "替代品"
        case .related:    return en ? "Related"     : "相关"
        }
    }

    var color: Color {
        switch self {
        case .exact:      return .green
        case .substitute: return .orange
        case .related:    return .blue
        }
    }
}

// MARK: - Service

enum DiscoveryService {
    static func discover(query: String) async throws -> DiscoveryResult {
        let url = URL(string: "\(GeminiService.baseURL)/discovery")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let language = LanguageManager.shared.language
        request.httpBody = try JSONEncoder().encode(["query": query, "language": language])

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(DiscoveryResult.self, from: data)
    }
}
