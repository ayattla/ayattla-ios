import XCTest
@testable import AyatTutla

final class JourneyTests: XCTestCase {
    private func pages(_ n: Int) -> Journey.Day { Journey.Day(pages: Set(1...n)) }

    func testStreakAndBest() {
        let t = Journey.dayNumber()
        let j = Journey(days: [t: pages(1), t - 1: pages(3), t - 2: Journey.Day(ayat: 7), t - 4: pages(2)], goal: 2)
        XCTAssertEqual(j.streak(), 3)
        XCTAssertEqual(j.best, 3)
    }

    func testOpenTodayKeepsYesterday() {
        let t = Journey.dayNumber()
        XCTAssertEqual(Journey(days: [t - 1: pages(2), t - 2: pages(2)], goal: 2).streak(), 2)
    }

    func testFewAyatDoNotCount() {
        let t = Journey.dayNumber()
        XCTAssertEqual(Journey(days: [t: Journey.Day(ayat: 3), t - 1: pages(1)], goal: 2).streak(), 1)
        XCTAssertTrue(Journey.Day(hifz: 1).active)
    }

    func testGoalWeekAndLabels() {
        let t = Journey.dayNumber()
        let j = Journey(days: [t: pages(4)], goal: 4)
        XCTAssertTrue(j.goalMet())
        XCTAssertEqual(j.week().count, 7)
        XCTAssertEqual(j.week().last?.value.pages.count, 4)
        XCTAssertEqual(Journey.goalLabel(2), "صفحتان")
        XCTAssertEqual(Journey.streakLabel(1), "يوم واحد")
        XCTAssertEqual(Journey.date(of: t).timeIntervalSince1970 > 0, true)
        XCTAssertEqual(Journey.dayNumber(Journey.date(of: t)), t)
    }
}
