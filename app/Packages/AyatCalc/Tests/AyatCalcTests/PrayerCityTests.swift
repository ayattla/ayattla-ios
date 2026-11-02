import XCTest
@testable import AyatCalc

final class PrayerCityTests: XCTestCase {
    func testCitiesMatchGolden() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "prayer_times_2026-11-02", withExtension: "json", subdirectory: "Golden"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let cases = try XCTUnwrap(json["cases"] as? [[String: Any]])
        XCTAssertEqual(PrayerCity.all.map(\.name), cases.map { $0["city"] as! String })
        for (city, c) in zip(PrayerCity.all, cases) {
            XCTAssertEqual(city.lat, c["lat"] as! Double)
            XCTAssertEqual(city.lng, c["lng"] as! Double)
            XCTAssertEqual(city.zone, c["zone"] as! String)
            XCTAssertEqual(city.method, PrayerTimes.Method(fajrAngle: c["fajrAngle"] as! Double, isha: c["isha"] as! Double))
            XCTAssertNotNil(TimeZone(identifier: city.zone), city.name)
        }
        XCTAssertEqual(PrayerCity.named("جدة")?.zone, "Asia/Riyadh")
    }

    private func riyadh(day: Int) -> PrayerTimes {
        let c = PrayerCity.all[0]
        return PrayerTimes.compute(year: 2026, month: 11, day: day, lat: c.lat, lng: c.lng, tzHours: 3, method: c.method)
    }

    func testDisplayMinuteMatchesHHMM() {
        let t = riyadh(day: 2)
        for p in Prayer.allCases {
            let m = PrayerTimes.displayMinute(t.hours(p))
            XCTAssertEqual(String(format: "%02d:%02d", m / 60, m % 60), PrayerTimes.hhmm(t.hours(p)))
        }
    }

    /// Riyadh 2026-11-02 on the site: 04:41 06:01 11:37 14:49 17:13 18:43.
    func testNextPrayerSkipsSunriseAndRollsOver() {
        let today = riyadh(day: 2), tomorrow = riyadh(day: 3)
        XCTAssertEqual(PrayerTimes.next(after: 4 * 60, today: today, tomorrow: tomorrow),
                       .init(prayer: .fajr, minutesUntil: 41, isTomorrow: false))
        XCTAssertEqual(PrayerTimes.next(after: 5 * 60, today: today, tomorrow: tomorrow),
                       .init(prayer: .dhuhr, minutesUntil: 6 * 60 + 37, isTomorrow: false))
        XCTAssertEqual(PrayerTimes.next(after: 11 * 60 + 37, today: today, tomorrow: tomorrow).prayer, .asr)
        let late = PrayerTimes.next(after: 19 * 60, today: today, tomorrow: tomorrow)
        XCTAssertEqual(late.prayer, .fajr); XCTAssertTrue(late.isTomorrow)
        XCTAssertEqual(late.minutesUntil, (24 - 19) * 60 + PrayerTimes.displayMinute(tomorrow.fajr))
    }
}
