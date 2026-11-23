import XCTest
@testable import AyatCalc

final class TodayTests: XCTestCase {
    // Fajr 4:50, sunrise 6:10, Dhuhr 11:40, Asr 14:50, Maghrib 17:10, Isha 18:40 (same day as the Android test).
    private let t = PrayerTimes(fajr: 4 + 50 / 60.0, sunrise: 6 + 10 / 60.0, dhuhr: 11 + 40 / 60.0,
                                asr: 14 + 50 / 60.0, maghrib: 17 + 10 / 60.0, isha: 18 + 40 / 60.0)
    private func m(_ h: Int, _ mm: Int) -> Int { h * 60 + mm }

    func testSlotFollowsThePrayers() {
        XCTAssertEqual(TodayPlan.slot(minute: m(2, 0), times: t), .night)
        XCTAssertEqual(TodayPlan.slot(minute: m(4, 52), times: t), .morning)
        XCTAssertEqual(TodayPlan.slot(minute: m(11, 30), times: t), .morning)
        XCTAssertEqual(TodayPlan.slot(minute: m(11, 45), times: t), .wird)
        XCTAssertEqual(TodayPlan.slot(minute: m(15, 0), times: t), .evening)
        XCTAssertEqual(TodayPlan.slot(minute: m(17, 30), times: t), .hadith)
        XCTAssertEqual(TodayPlan.slot(minute: m(21, 0), times: t), .night)
    }

    func testNightBeforeFajrBelongsToYesterday() {
        XCTAssertEqual(TodayPlan.daysBack(minute: m(2, 0), times: t), 1)
        XCTAssertEqual(TodayPlan.daysBack(minute: m(5, 0), times: t), 0)
    }

    func testNextWrapsAroundTheDay() {
        XCTAssertEqual(TodaySlot.morning.next, .wird)
        XCTAssertEqual(TodaySlot.night.next, .morning)
    }

    func testSamePickAllDayAndNoTashkeel() {
        XCTAssertEqual(TodayPlan.pick(["a", "b", "c"], dayNumber: 20_000), TodayPlan.pick(["a", "b", "c"], dayNumber: 20_000))
        XCTAssertNotEqual(TodayPlan.pick(["a", "b", "c"], dayNumber: 20_000), TodayPlan.pick(["a", "b", "c"], dayNumber: 20_001))
        XCTAssertNil(TodayPlan.pick([String](), dayNumber: 1))
        let tashkeel = CharacterSet(charactersIn: "\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}")
        for s in TodaySlot.allCases { XCTAssertNil((s.title + s.line).rangeOfCharacter(from: tashkeel)) }
    }
}
