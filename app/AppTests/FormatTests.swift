import XCTest
@testable import AyatTutla

final class FormatTests: XCTestCase {
    func testArabicIndicDigits() {
        XCTAssertEqual(Num.digits("04:41"), "٠٤:٤١")
        XCTAssertEqual(Num.int(1446), "١٤٤٦")
    }

    func testDurationHasNoLatinDigits() {
        let s = Num.duration(minutes: 192)
        XCTAssertFalse(s.contains(where: { $0.isASCII && $0.isNumber }), s)
        XCTAssertTrue(s.contains("٣"), s)
    }

    func testQiblaAngleDiffWraps() {
        XCTAssertEqual(QiblaView.angleDiff(359, 1), 2, accuracy: 1e-9)
        XCTAssertEqual(QiblaView.angleDiff(10, 190), 180, accuracy: 1e-9)
    }
}
