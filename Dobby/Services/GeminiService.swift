import Foundation
import UIKit

// MARK: - Result Types

/// A single item recognized from a photo or receipt line.
struct ItemRecognitionResult {
    var name: String
    var category: ItemCategory?
    var quantity: Int
    var expiryDate: Date?

    init(name: String, category: ItemCategory? = nil, quantity: Int = 1, expiryDate: Date? = nil) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.expiryDate = expiryDate
    }
}

// MARK: - Errors

enum GeminiServiceError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case invalidResponse
    case noItemsRecognized

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:       return "未配置 API Key，请检查设置"
        case .networkError(let e): return "网络错误：\(e.localizedDescription)"
        case .invalidResponse:     return "无法解析识别结果，请重试"
        case .noItemsRecognized:   return "未能识别到任何物品，请重新拍摄"
        }
    }
}

// MARK: - Protocol

protocol GeminiServiceProtocol {
    /// Recognize a single item from a photo.
    func recognizeItem(imageData: Data) async throws -> ItemRecognitionResult

    /// Recognize multiple items from a receipt photo.
    func recognizeReceipt(imageData: Data) async throws -> [ItemRecognitionResult]
}

// MARK: - Mock (for tests and Xcode Previews)

final class MockGeminiService: GeminiServiceProtocol {
    var stubbedItem: ItemRecognitionResult?
    var stubbedReceipt: [ItemRecognitionResult] = []
    var shouldThrow: GeminiServiceError?

    func recognizeItem(imageData: Data) async throws -> ItemRecognitionResult {
        if let error = shouldThrow { throw error }
        return stubbedItem ?? ItemRecognitionResult(name: "测试物品", category: .other, quantity: 1)
    }

    func recognizeReceipt(imageData: Data) async throws -> [ItemRecognitionResult] {
        if let error = shouldThrow { throw error }
        return stubbedReceipt
    }
}

// MARK: - Real Implementation

final class GeminiService: GeminiServiceProtocol {

    // MARK: Configuration

    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    private let session: URLSession

    init(session: URLSession = .shared) throws {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
              !key.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }
        self.apiKey = key
        self.session = session
    }

    // MARK: Public API

    func recognizeItem(imageData: Data) async throws -> ItemRecognitionResult {
        let prompt = """
        你是一个家庭库存助手。分析这张物品照片，以 JSON 格式返回以下字段：
        {
          "name": "物品名称（中文）",
          "category": "从以下选择一个：衣物、食品、电子产品、文件、工具、药品、厨具、玩具、书籍、其他",
          "quantity": 数字（默认 1）,
          "expiryDate": "YYYY-MM-DD 或 null"
        }
        只返回 JSON，不要其他文字。
        """
        let results = try await callGemini(imageData: imageData, prompt: prompt)
        guard let first = results.first else { throw GeminiServiceError.noItemsRecognized }
        return first
    }

    func recognizeReceipt(imageData: Data) async throws -> [ItemRecognitionResult] {
        let prompt = """
        你是一个家庭库存助手。分析这张购物小票，提取所有商品信息，以 JSON 数组格式返回：
        [
          {
            "name": "物品名称（中文）",
            "category": "从以下选择一个：衣物、食品、电子产品、文件、工具、药品、厨具、玩具、书籍、其他",
            "quantity": 数字,
            "expiryDate": "YYYY-MM-DD 或 null"
          }
        ]
        只返回 JSON 数组，不要其他文字。
        """
        let results = try await callGemini(imageData: imageData, prompt: prompt)
        if results.isEmpty { throw GeminiServiceError.noItemsRecognized }
        return results
    }

    // MARK: Private

    private func callGemini(imageData: Data, prompt: String) async throws -> [ItemRecognitionResult] {
        let base64Image = imageData.base64EncodedString()

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw GeminiServiceError.networkError(error)
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> [ItemRecognitionResult] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiServiceError.invalidResponse
        }

        // Strip markdown code fences if present
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiServiceError.invalidResponse
        }

        // Try array first, then single object
        if let array = try? JSONDecoder().decode([ItemRecognitionDTO].self, from: jsonData) {
            return array.map { $0.toResult() }
        } else if let single = try? JSONDecoder().decode(ItemRecognitionDTO.self, from: jsonData) {
            return [single.toResult()]
        } else {
            throw GeminiServiceError.invalidResponse
        }
    }
}

// MARK: - DTO

private struct ItemRecognitionDTO: Decodable {
    let name: String
    let category: String?
    let quantity: Int?
    let expiryDate: String?

    func toResult() -> ItemRecognitionResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return ItemRecognitionResult(
            name: name,
            category: ItemCategory.allCases.first { $0.rawValue == category },
            quantity: quantity ?? 1,
            expiryDate: expiryDate.flatMap { dateFormatter.date(from: $0) }
        )
    }
}
