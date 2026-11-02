import XCTest
import AyatCalc
@testable import AyatTutla

final class PlansTests: XCTestCase {
    private let riyadh = PrayerCity.all[0]

    func testRemindersPlanAllKinds() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)   // a fixed moment
        let k = KhatmaPlan(days: 30, startDate: now)
        let items = Reminders.plan(now: now, azkar: true, dailyAyah: true, khatma: k, city: riyadh) { _ in "نص" }
        XCTAssertTrue(items.allSatisfy { $0.date > now })
        XCTAssertTrue(items.allSatisfy { $0.id.hasPrefix(Reminders.prefix) })
        XCTAssertEqual(Set(items.map(\.id)).count, items.count, "ids must be unique")
        let morning = items.filter { $0.id.contains("azkar.morning") }
        XCTAssertGreaterThanOrEqual(morning.count, 6)
        XCTAssertGreaterThanOrEqual(items.filter { $0.id.contains("khatma") }.count, 6)
        XCTAssertTrue(items.first { $0.id.contains("ayah") }?.body.contains("نص") ?? false)
    }

    func testNoRemindersWhenAllOff() {
        XCTAssertTrue(Reminders.plan(now: Date(), azkar: false, dailyAyah: false, khatma: nil, city: riyadh) { _ in nil }.isEmpty)
    }

    func testKhatmaDoneDayIsSkipped() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var k = KhatmaPlan(days: 30, startDate: now.addingTimeInterval(-86_400 * 10))
        k.completedDays = Set(1...30)
        XCTAssertTrue(Reminders.plan(now: now, azkar: false, dailyAyah: false, khatma: k, city: riyadh) { _ in nil }.isEmpty)
    }

    func testKhatmaStoreRoundTrip() {
        var p = KhatmaPlan(days: 10, startPage: 5, startDate: Date(timeIntervalSince1970: 1_800_000_000))
        p.completedDays = [1, 2]
        XCTAssertEqual(KhatmaStore.load(KhatmaStore.save(p)), p)
        XCTAssertNil(KhatmaStore.load(""))
    }

    func testCardSizesMatchSite() {
        XCTAssertEqual(Set(CardOptions.Ratio.allCases.map(\.rawValue)), ["1:1", "16:9", "4:5", "9:16"])
        XCTAssertEqual(CardOptions.Ratio.story.size, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(CardOptions.templates.count, 6)
    }

    @MainActor func testCardRendersAtFullSize() throws {
        let m = CardCanvas.Model(text: "نص", reference: "[١]", template: nil, name: nil,
                                 background: CardOptions.backgrounds[0], fontScale: 1, ratio: .portrait, lightBackground: false)
        let img = try XCTUnwrap(CardCanvas.render(m, photo: nil))
        XCTAssertEqual(img.size.width * img.scale, 1080, accuracy: 1)
        XCTAssertEqual(img.size.height * img.scale, 1350, accuracy: 1)
    }
}

final class TrackersTests: XCTestCase {
    func testQada() {
        // Same steps as on ayattla.com/tools/qada-salah: 30 days, «قضيت واحدة» on الفجر, «+» on الظهر.
        var s = QadaState()
        s.add(days: 30)
        s.makeUp(0); s.more(1)
        XCTAssertEqual(s.left, [29, 31, 30, 30, 30])
        XCTAssertEqual(s.status, "المتبقي: ١٥٠ صلاة — تم قضاء: ١")
        XCTAssertEqual(s.daysLeft, 31)
        s.per = 3
        XCTAssertEqual(s.plan, "بقضاء ٣ مع كل فرض تنتهي خلال نحو ١١ يوما بإذن الله")
        s.add(days: 5)
        XCTAssertEqual(s.left, [34, 36, 35, 35, 35])
        XCTAssertEqual(QadaState.paces.map(\.value), [1, 2, 3, 5])
    }

    func testQadaMigratesEarlierFormat() throws {
        let old = #"{"owed":[10,10,10,10,10],"done":[2,0,0,0,1],"perDay":4}"#
        let s = try JSONDecoder().decode(QadaState.self, from: Data(old.utf8))
        XCTAssertEqual(s.left, [8, 10, 10, 10, 9])
        XCTAssertEqual(s.done, 3)
        XCTAssertEqual(s.per, 3)
        let again = try JSONDecoder().decode(QadaState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(again, s)
    }

    func testTasbihMatchesSite() {
        XCTAssertEqual(TasbihView.targets, [33, 100, 1000, 0])
        XCTAssertEqual(TasbihView.targetTitle(0), "بدون هدف")
        XCTAssertEqual(TasbihView.targetTitle(33), "الهدف ٣٣")
        XCTAssertEqual(TasbihView.remainingText(count: 0, target: 33), "بقي ٣٣")
        XCTAssertNil(TasbihView.remainingText(count: 35, target: 33))
        XCTAssertNil(TasbihView.remainingText(count: 5, target: 0))
    }

    func testSawm() {
        let cal = Calendar(identifier: .gregorian)
        var s = SawmState(); s.required = 3
        let d = Date(timeIntervalSince1970: 1_800_000_000)
        s.tap(d, mode: .qada, cal: cal)
        s.tap(d.addingTimeInterval(86_400), mode: .tatawwu, cal: cal)
        XCTAssertEqual(s.qadaRemaining, 2)
        XCTAssertEqual(s.tatawwu, 1)
        s.tap(d, mode: .qada, cal: cal)
        XCTAssertEqual(s.qadaRemaining, 3)
        s.tap(d, mode: .tatawwu, cal: cal)
        XCTAssertEqual(s.tatawwu, 2)
    }
}
