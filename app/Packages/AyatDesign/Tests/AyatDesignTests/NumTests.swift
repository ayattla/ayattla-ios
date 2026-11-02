import XCTest
@testable import AyatDesign

final class NumTests: XCTestCase {
    private func hasLatinDigit(_ s: String) -> Bool { s.contains(where: { $0.isASCII && $0.isNumber }) }

    func testDigits() {
        XCTAssertEqual(Num.digits("04:41"), "٠٤:٤١")
        XCTAssertEqual(Num.int(1446), "١٤٤٦")
    }

    func testDistance() {
        XCTAssertEqual(Num.distance(meters: 347), "٣٥٠ م")
        XCTAssertTrue(Num.distance(meters: 1234).hasSuffix(" كم"))
        XCTAssertFalse(hasLatinDigit(Num.distance(meters: 4870)))
    }

    func testDurationHasNoLatinDigits() {
        let s = Num.duration(minutes: 192)
        XCTAssertFalse(hasLatinDigit(s), s)
        XCTAssertTrue(s.contains("٣"), s)
    }
}
