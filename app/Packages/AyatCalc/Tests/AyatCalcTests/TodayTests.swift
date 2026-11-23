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

final class SeasonsTests: XCTestCase {
    private func keys(_ wd: Int, _ m: Int, _ d: Int, _ s: TodaySlot) -> [String] {
        Seasons.notes(weekday: wd, hijriMonth: m, hijriDay: d, slot: s, maghrib: "5:10 م", fajrTomorrow: "4:50 ص").map(\.key)
    }

    func testFridayDuringTheDay() {
        XCTAssertEqual(keys(5, 5, 3, .morning), ["kahf", "salawat"])
        XCTAssertFalse(keys(5, 5, 3, .hadith).contains("kahf"))
    }

    func testRamadan() {
        XCTAssertEqual(keys(2, 9, 3, .wird), ["iftar", "khatma"])
        XCTAssertEqual(keys(2, 9, 3, .hadith), ["tarawih", "khatma"])
        XCTAssertEqual(keys(2, 9, 3, .night), ["suhoor", "khatma"])
        XCTAssertTrue(Seasons.notes(weekday: 2, hijriMonth: 9, hijriDay: 3, slot: .wird, maghrib: "5:10 م", fajrTomorrow: "")[0].title.contains("5:10"))
    }

    func testDhulHijjah() {
        XCTAssertEqual(keys(2, 12, 8, .night), ["takbir", "arafah-eve"])
        XCTAssertEqual(keys(2, 12, 9, .morning), ["takbir", "arafah"])
        XCTAssertEqual(keys(2, 12, 10, .morning), ["eid"])
    }

    func testVoluntaryFastsNamedTheNightBefore() {
        XCTAssertEqual(keys(7, 5, 3, .night), ["fast-mon"])
        XCTAssertEqual(keys(3, 5, 13, .night), ["fast-thu", "white"])
        XCTAssertEqual(keys(7, 9, 13, .night), ["suhoor", "khatma"])
        XCTAssertEqual(keys(1, 5, 3, .morning), [])
    }

    func testIsoWeekday() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let fri = c.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        XCTAssertEqual(Seasons.isoWeekday(fri, calendar: c), 5)
    }

    func testNoTashkeel() {
        let marks = CharacterSet(charactersIn: "\u{064B}"..."\u{0652}")
        for wd in 1...7 { for m in [5, 9, 12] { for d in 1...14 { for s in TodaySlot.allCases {
            for n in Seasons.notes(weekday: wd, hijriMonth: m, hijriDay: d, slot: s, maghrib: "5:10 م", fajrTomorrow: "4:50 ص") {
                XCTAssertNil((n.title + n.line).rangeOfCharacter(from: marks), n.key)
            }
        } } } }
    }
}
