import XCTest
@testable import AyatCalc

final class KhatmaTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testThirtyDaysCoverEveryPageOnce() {
        let p = KhatmaPlan(days: 30, startDate: start)
        var seen: [Int] = []
        for d in 1...30 { seen += Array(p.range(day: d)!) }
        XCTAssertEqual(seen, Array(1...604))
        XCTAssertEqual(p.range(day: 1), 1...20)
        XCTAssertNil(p.range(day: 31))
    }

    func testStartPageAndUnevenDays() {
        let p = KhatmaPlan(days: 7, startPage: 300, startDate: start)
        var seen: [Int] = []
        for d in 1...7 { seen += Array(p.range(day: d)!) }
        XCTAssertEqual(seen, Array(300...604))
        let sizes = (1...7).map { p.range(day: $0)!.count }
        XCTAssertLessThanOrEqual(sizes.max()! - sizes.min()!, 1)
    }

    func testMoreDaysThanPages() {
        let p = KhatmaPlan(days: 10, startPage: 600, startDate: start)
        let covered = (1...10).compactMap { p.range(day: $0) }.flatMap { Array($0) }
        XCTAssertEqual(covered, Array(600...604))
    }

    func testPrayerSplit() {
        let parts = KhatmaPlan.splitOverPrayers(1...20)
        XCTAssertEqual(parts.compactMap { $0 }.flatMap { Array($0) }, Array(1...20))
        XCTAssertEqual(parts[0], 1...4)
        XCTAssertEqual(KhatmaPlan.splitOverPrayers(5...7).compactMap { $0 }.count, 3)
    }

    func testDayNumber() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let p = KhatmaPlan(days: 30, startDate: start)
        XCTAssertEqual(p.day(on: start, calendar: cal), 1)
        XCTAssertEqual(p.day(on: start.addingTimeInterval(86_400 * 3), calendar: cal), 4)
    }
}
