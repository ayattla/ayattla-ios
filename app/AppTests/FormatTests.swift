import XCTest
import AyatDesign
@testable import AyatTutla

final class FormatTests: XCTestCase {
    func testArabicIndicDigitsFromDesignPackage() {
        XCTAssertEqual(Num.digits("04:41"), "٠٤:٤١")
    }

    func testQiblaAngleDiffWraps() {
        XCTAssertEqual(QiblaView.angleDiff(359, 1), 2, accuracy: 1e-9)
        XCTAssertEqual(QiblaView.angleDiff(10, 190), 180, accuracy: 1e-9)
    }
}
