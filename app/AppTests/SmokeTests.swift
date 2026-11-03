import XCTest
@testable import AyatTutla

final class SmokeTests: XCTestCase {
    func testFiveTabs() {
        XCTAssertEqual(Tab.allCases.map(\.title), ["الرئيسية", "القرآن", "اصنع", "الأذكار", "المزيد"])
        XCTAssertEqual(Tab.allCases.map(\.longTitle), ["الرئيسية", "القرآن الكريم", "صناعة المحتوى", "الأذكار والحديث", "المزيد والأدوات"])
    }
}
