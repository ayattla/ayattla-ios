import XCTest
import AyatCalc
@testable import AyatTutla

final class NotifyPlannerTests: XCTestCase {
    let riyadh = TimeZone(identifier: "Asia/Riyadh")!
    // Fajr 4:50, sunrise 6:10, Dhuhr 11:40, Asr 14:50, Maghrib 17:10, Isha 18:40.
    let t = PrayerTimes(fajr: 4 + 50 / 60, sunrise: 6 + 10 / 60, dhuhr: 11 + 40 / 60, asr: 14 + 50 / 60, maghrib: 17 + 10 / 60, isha: 18 + 40 / 60)

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 1) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = riyadh
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }
    func hm(_ d: Date) -> String {
        var c = Calendar(identifier: .gregorian); c.timeZone = riyadh
        let x = c.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", x.hour!, x.minute!)
    }
    var inputs: NotifyPlanner.Inputs {
        NotifyPlanner.Inputs(place: "الرياض", zone: riyadh, times: { [t] _ in t }, hijriDay: { [self] d in
            var c = Calendar(identifier: .gregorian); c.timeZone = riyadh
            return c.component(.day, from: d) == 18 ? 13 : 1
        })
    }

    func testNothingWhenOff() { XCTAssertTrue(NotifyPlanner.plan(NotifyConfig(), now: date(2026, 11, 16), days: 2, inputs).isEmpty) }

    func testFivePrayersNoSunrise() {
        var c = NotifyConfig()
        for p in NotifyConfig.fivePrayers { c.setAlert(p, .init(on: true)) }
        let day = NotifyPlanner.plan(c, now: date(2026, 11, 16), days: 1, inputs)
        XCTAssertEqual(day.count, 5)
        XCTAssertFalse(day.contains { $0.title.contains("الشروق") })
        XCTAssertEqual(hm(day[0].date), "04:50")
    }

    func testBeforeAndIqama() {
        var c = NotifyConfig()
        c.setAlert(.dhuhr, .init(on: true, before: 10, iqama: 20))
        XCTAssertEqual(NotifyPlanner.plan(c, now: date(2026, 11, 16), days: 1, inputs).map { hm($0.date) }, ["11:30", "11:40", "12:00"])
    }

    func testQuietHoldsAzkarNotPrayers() {
        var c = NotifyConfig()
        c.setAlert(.fajr, .init(on: true)); c.wake = true; c.quiet = true
        XCTAssertEqual(NotifyPlanner.plan(c, now: date(2026, 11, 16), days: 1, inputs).map(\.title), ["حان وقت صلاة الفجر"])
    }

    func testFastingAndWhiteDays() {
        var c = NotifyConfig(); c.fasting = true; c.whiteDays = true
        let week = NotifyPlanner.plan(c, now: date(2026, 11, 16), days: 7, inputs)   // Monday 16 Nov
        var cal = Calendar(identifier: .gregorian); cal.timeZone = riyadh
        XCTAssertEqual(week.filter { $0.title == "تذكير بالصيام" }.map { cal.component(.weekday, from: $0.date) }, [4, 1]) // Wednesday, Sunday
        XCTAssertEqual(week.filter { $0.title == "الأيام البيض" }.map { cal.component(.day, from: $0.date) }, [17])
    }

    func testSavedConfigRoundTripsAndOldKeysMigrate() {
        let d = UserDefaults(suiteName: "notify-test")!
        d.removePersistentDomain(forName: "notify-test")
        d.set(true, forKey: "notify.azkar")
        XCTAssertTrue(NotifyConfig.load(d).morning && NotifyConfig.load(d).evening)
        var c = NotifyConfig(); c.sleep = true; c.setAlert(.isha, .init(on: true, silent: true))
        c.save(d)
        XCTAssertEqual(NotifyConfig.load(d), c)
    }
}
