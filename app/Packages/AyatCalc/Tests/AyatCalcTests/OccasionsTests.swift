import XCTest
@testable import AyatCalc

final class OccasionsTests: XCTestCase {
    private func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testNextOccasionsAreAheadAndOnTheRightHijriDay() {
        let today = utc(2026, 11, 2)
        for u in Occasion.upcoming(from: today) {
            XCTAssertGreaterThanOrEqual(u.days, 0)
            XCTAssertLessThan(u.days, 356)
            XCTAssertEqual(Hijri.fromGregorian(u.gregorian.addingTimeInterval(12 * 3600)), u.hijri, u.occasion.name)
            XCTAssertEqual(u.hijri.month, u.occasion.hijriMonth)
            XCTAssertEqual(u.hijri.day, u.occasion.hijriDay)
        }
        let days = Occasion.upcoming(from: today).map(\.days)
        XCTAssertEqual(days, days.sorted())
    }

    func testOnTheDayItselfIsZero() {
        let today = utc(2026, 11, 2)
        let ramadan = Occasion.ramadan.next(from: today)
        let onDay = Occasion.ramadan.next(from: ramadan.gregorian.addingTimeInterval(12 * 3600))
        XCTAssertEqual(onDay.days, 0)
        XCTAssertEqual(onDay.hijri, ramadan.hijri)
    }

    func testFitrFollowsRamadanAndAdhaFollowsArafah() {
        let today = utc(2026, 11, 2)
        let r = Occasion.ramadan.next(from: today), f = Occasion.eidFitr.next(from: today)
        XCTAssertTrue([29, 30].contains(f.days - r.days))
        XCTAssertEqual(Occasion.eidAdha.next(from: today).days - Occasion.arafah.next(from: today).days, 1)
    }

    func testMonthLengthsAndExactConversion() {
        for m in 1...12 { XCTAssertTrue([29, 30].contains(Hijri.daysInMonth(year: 1448, month: m))) }
        let total = (1...12).map { Hijri.daysInMonth(year: 1448, month: $0) }.reduce(0, +)
        XCTAssertTrue((354...355).contains(total))
        let h = Hijri.Date(year: 1448, month: 9, day: 1)
        XCTAssertEqual(Hijri.fromGregorian(Hijri.toGregorianExact(h)!), h)
    }
}
