import XCTest
@testable import LockIn

final class LockInTests: XCTestCase {
    func testSidebarSectionHasFourCases() {
        XCTAssertEqual(SidebarSection.allCases.count, 4)
    }
}
