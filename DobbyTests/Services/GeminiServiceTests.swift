import XCTest
@testable import Dobby

final class GeminiServiceTests: XCTestCase {

    // MARK: - MockGeminiService — happy paths

    func test_recognizeItem_returnsStubbed() async throws {
        let mock = MockGeminiService()
        mock.stubbedItem = ItemRecognitionResult(name: "牛奶", category: .food, quantity: 2)

        let result = try await mock.recognizeItem(imageData: Data())

        XCTAssertEqual(result.name, "牛奶")
        XCTAssertEqual(result.category, .food)
        XCTAssertEqual(result.quantity, 2)
    }

    func test_recognizeReceipt_returnsMultipleItems() async throws {
        let mock = MockGeminiService()
        mock.stubbedReceipt = [
            ItemRecognitionResult(name: "苹果", category: .food, quantity: 3),
            ItemRecognitionResult(name: "洗发水", category: .other, quantity: 1)
        ]

        let results = try await mock.recognizeReceipt(imageData: Data())

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "苹果")
        XCTAssertEqual(results[1].name, "洗发水")
    }

    // MARK: - MockGeminiService — error paths

    func test_recognizeItem_throwsMissingAPIKey() async {
        let mock = MockGeminiService()
        mock.shouldThrow = .missingAPIKey

        do {
            _ = try await mock.recognizeItem(imageData: Data())
            XCTFail("Expected error to be thrown")
        } catch GeminiServiceError.missingAPIKey {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_recognizeReceipt_throwsNoItemsRecognized() async {
        let mock = MockGeminiService()
        mock.shouldThrow = .noItemsRecognized

        do {
            _ = try await mock.recognizeReceipt(imageData: Data())
            XCTFail("Expected error to be thrown")
        } catch GeminiServiceError.noItemsRecognized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - ItemRecognitionResult defaults

    func test_itemRecognitionResult_defaultQuantityIsOne() {
        let result = ItemRecognitionResult(name: "测试")
        XCTAssertEqual(result.quantity, 1)
    }

    func test_itemRecognitionResult_defaultCategoryIsNil() {
        let result = ItemRecognitionResult(name: "测试")
        XCTAssertNil(result.category)
    }

    func test_itemRecognitionResult_defaultExpiryIsNil() {
        let result = ItemRecognitionResult(name: "测试")
        XCTAssertNil(result.expiryDate)
    }

    // MARK: - GeminiServiceError localized descriptions

    func test_missingAPIKeyError_hasChineseDescription() {
        let error = GeminiServiceError.missingAPIKey
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        // Sanity check: contains Chinese characters
        XCTAssertTrue(error.errorDescription?.contains("API") ?? false)
    }

    func test_noItemsRecognizedError_hasDescription() {
        let error = GeminiServiceError.noItemsRecognized
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
}
