import XCTest
import AyatCalc
@testable import AyatTutla

final class HomeV5Tests: XCTestCase {
    func testLayoutRoundTripAndNewSectionsJoin() {
        let l = HomeLayoutStore.decode("quiz:0,prayer:1")
        XCTAssertEqual(l.first?.id, .quiz)
        XCTAssertEqual(l.first?.shown, false)
        XCTAssertEqual(l.count, HomeSectionID.allCases.count)
        XCTAssertEqual(HomeLayoutStore.decode(HomeLayoutStore.encode(l)), l)
        XCTAssertEqual(HomeLayoutStore.decode("").map(\.id), HomeSectionID.allCases)
    }

    func testSeededRandomIsStable() {
        var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }

    func testCountdownWithinSpan() {
        let c = PrayerCity.all[0]
        let place = PrayerTimesView.Place(name: c.name, lat: c.lat, lng: c.lng, zone: TimeZone(identifier: c.zone) ?? .current, method: c.method)
        let now = Date()
        let d = PrayerTimesView.Day(place: place, now: now)
        let r = PrayerHeroCard.countdown(d, place: place, now: now)
        XCTAssert((0...1).contains(r.progress))
        XCTAssertEqual(r.text.count, 8)
    }
}
