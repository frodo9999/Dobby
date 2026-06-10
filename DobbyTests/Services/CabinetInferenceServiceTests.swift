import XCTest
import CoreData
@testable import Dobby

final class CabinetInferenceServiceTests: CoreDataTestCase {

    // MARK: - Helpers

    private func makeRoom(name: String) -> Room {
        let room = Room(context: context)
        room.name = name
        return room
    }

    private func makeCabinet(name: String, room: Room, summary: String = "") -> Cabinet {
        let cabinet = Cabinet(context: context)
        cabinet.name = name
        cabinet.room = room
        cabinet.contentSummary = summary
        return cabinet
    }

    private func makeItem(name: String, category: ItemCategory, cabinet: Cabinet) -> Item {
        let item = Item(context: context)
        item.name = name
        item.category = category.rawValue
        item.cabinet = cabinet
        return item
    }

    // MARK: - Exact name match (priority 1)

    func test_findBestCabinet_exactNameMatch_returnsThatCabinet() {
        let room = makeRoom(name: "厨房")
        let fridge = makeCabinet(name: "冰箱", room: room, summary: "食品")
        let shelf = makeCabinet(name: "货架", room: room, summary: "其他")
        _ = makeItem(name: "牛奶", category: .food, cabinet: fridge)

        let result = CabinetInferenceService.findBestCabinet(
            for: ItemRecognitionResult(name: "牛奶", category: .food),
            in: [fridge, shelf]
        )

        XCTAssertEqual(result, fridge)
    }

    func test_findBestCabinet_nameMatchIsCaseInsensitive() {
        let room = makeRoom(name: "厨房")
        let fridge = makeCabinet(name: "冰箱", room: room)
        _ = makeItem(name: "牛奶", category: .food, cabinet: fridge)

        let result = CabinetInferenceService.findBestCabinet(
            for: ItemRecognitionResult(name: "牛奶"),
            in: [fridge]
        )

        XCTAssertEqual(result, fridge)
    }

    // MARK: - Summary match (priority 2)

    func test_findBestCabinet_summaryContainsCategory_returnsThatCabinet() {
        let room = makeRoom(name: "厨房")
        let foodCabinet = makeCabinet(name: "食品柜", room: room, summary: "食品、饼干、零食")
        let toolCabinet = makeCabinet(name: "工具箱", room: room, summary: "工具、螺丝刀")

        let result = CabinetInferenceService.findBestCabinet(
            for: ItemRecognitionResult(name: "新品饼干", category: .food),
            in: [foodCabinet, toolCabinet]
        )

        XCTAssertEqual(result, foodCabinet)
    }

    func test_findBestCabinet_summaryContainsItemName_returnsThatCabinet() {
        let room = makeRoom(name: "书房")
        let bookshelf = makeCabinet(name: "书架", room: room, summary: "书籍；Python编程、算法导论")
        let drawer = makeCabinet(name: "抽屉", room: room, summary: "文件；合同、发票")

        let result = CabinetInferenceService.findBestCabinet(
            for: ItemRecognitionResult(name: "Python编程", category: .books),
            in: [bookshelf, drawer]
        )

        XCTAssertEqual(result, bookshelf)
    }

    // MARK: - No match

    func test_findBestCabinet_noMatch_returnsNil() {
        let room = makeRoom(name: "厨房")
        let cabinet = makeCabinet(name: "工具箱", room: room, summary: "工具、螺丝刀")

        let result = CabinetInferenceService.findBestCabinet(
            for: ItemRecognitionResult(name: "神秘物品xyz", category: .other),
            in: [cabinet]
        )

        XCTAssertNil(result)
    }

    func test_findBestCabinet_emptyCabinetList_returnsNil() {
        let result = CabinetInferenceService.findBestCabinet(
            for: ItemRecognitionResult(name: "牛奶", category: .food),
            in: []
        )

        XCTAssertNil(result)
    }

    // MARK: - rebuildContentSummary

    func test_rebuildContentSummary_withItems_containsCategories() {
        let room = makeRoom(name: "厨房")
        let cabinet = makeCabinet(name: "冰箱", room: room)
        _ = makeItem(name: "牛奶", category: .food, cabinet: cabinet)
        _ = makeItem(name: "果汁", category: .food, cabinet: cabinet)

        cabinet.rebuildContentSummary()

        XCTAssertTrue(cabinet.contentSummary.contains("食品"))
    }

    func test_rebuildContentSummary_withItems_containsItemNames() {
        let room = makeRoom(name: "书房")
        let cabinet = makeCabinet(name: "书架", room: room)
        _ = makeItem(name: "Swift编程", category: .books, cabinet: cabinet)

        cabinet.rebuildContentSummary()

        XCTAssertTrue(cabinet.contentSummary.contains("Swift编程"))
    }

    func test_rebuildContentSummary_emptyItems_producesEmptyString() {
        let room = makeRoom(name: "厨房")
        let cabinet = makeCabinet(name: "空柜子", room: room)

        cabinet.rebuildContentSummary()

        XCTAssertEqual(cabinet.contentSummary, "")
    }
}
