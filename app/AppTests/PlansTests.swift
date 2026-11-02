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
        XCTAssertEqual(CardOptions.Ratio.allCases.map(\.rawValue).sorted(), ["1:1", "16:9", "4:5", "9:16"])
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
