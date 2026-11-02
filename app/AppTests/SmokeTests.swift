import XCTest
@testable import AyatTutla

final class SmokeTests: XCTestCase {
    func testFiveTabs() {
        XCTAssertEqual(Tab.allCases.map(\.title), ["الرئيسية", "القرآن", "الاستوديو", "مكتبتي", "الأدوات"])
    }
}
