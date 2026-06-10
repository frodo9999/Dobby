import XCTest
import CoreData
@testable import Dobby

/// Base class for all Core Data unit tests.
/// Uses an in-memory store — fast, isolated, no disk I/O.
class CoreDataTestCase: XCTestCase {
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }
}
