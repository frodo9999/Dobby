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

// MARK: - Real Implementation (calls Dobby backend)

final class GeminiService: GeminiServiceProtocol {

    // MARK: Configuration

    /// Base URL for the Dobby Agent backend.
    /// Override via Info.plist key "DobbyAgentBaseURL" for local development.
    static var baseURL: String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "DobbyAgentBaseURL") as? String,
           !url.isEmpty {
            return url
        }
        return "https://dobby-agent-172253357017.us-central1.run.app"
    }

    private let session: URLSession

    init(session: URLSession = .shared) throws {
        self.session = session
    }

    // MARK: Public API

    func recognizeItem(imageData: Data) async throws -> ItemRecognitionResult {
        let results = try await callExtract(imageData: imageData, isReceipt: false)
        guard let first = results.first else { throw GeminiServiceError.noItemsRecognized }
        return first
    }

    func recognizeReceipt(imageData: Data) async throws -> [ItemRecognitionResult] {
        let results = try await callExtract(imageData: imageData, isReceipt: true)
        if results.isEmpty { throw GeminiServiceError.noItemsRecognized }
        return results
    }

    // MARK: Private

    private func callExtract(imageData: Data, isReceipt: Bool) async throws -> [ItemRecognitionResult] {
        let url = URL(string: "\(GeminiService.baseURL)/intake/extract?is_receipt=\(isReceipt)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Build multipart/form-data body
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(imageData: imageData, boundary: boundary)

        let data: Data
        do {
            let (responseData, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 422 {
                throw GeminiServiceError.noItemsRecognized
            }
            data = responseData
        } catch let error as GeminiServiceError {
            throw error
        } catch {
            throw GeminiServiceError.networkError(error)
        }

        return try parseExtractResponse(data)
    }

    private func buildMultipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"

        // file field
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(imageData)
        body.append(crlf.data(using: .utf8)!)

        // closing boundary
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    private func parseExtractResponse(_ data: Data) throws -> [ItemRecognitionResult] {
        struct ExtractResponse: Decodable {
            let items: [ItemDTO]
        }
        struct ItemDTO: Decodable {
            let name: String
            let category: String?
            let quantity: Int?
            let expiryDate: String?
        }

        guard let response = try? JSONDecoder().decode(ExtractResponse.self, from: data) else {
            throw GeminiServiceError.invalidResponse
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return response.items.map { dto in
            ItemRecognitionResult(
                name: dto.name,
                category: ItemCategory.allCases.first { $0.rawValue == dto.category },
                quantity: dto.quantity ?? 1,
                expiryDate: dto.expiryDate.flatMap { dateFormatter.date(from: $0) }
            )
        }
    }
}
