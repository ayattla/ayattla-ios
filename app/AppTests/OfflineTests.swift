import XCTest
@testable import AyatTutla

final class OfflineTests: XCTestCase {
    func testLevels() {
        XCTAssertEqual(OfflineTools.level("radio"), .online)
        XCTAssertEqual(OfflineTools.level("nearby-mosques"), .online)
        for id in ["listen", "clip", "hadith", "hadith-checker", "tajweed", "word-by-word", "ruqya"] {
            XCTAssertEqual(OfflineTools.level(id), .saved, id)
        }
        for id in ["azkar", "hisn-almuslim", "prayer-times", "qibla", "tasbih", "hijri", "zakat", "khatma", "mushaf", "duas", "kaffarah", "offline"] {
            XCTAssertEqual(OfflineTools.level(id), .full, id)
        }
    }

    func testMostToolsWorkOfflineAndTheCentreIsListed() {
        XCTAssertLessThanOrEqual(SiteTool.all.filter { $0.offlineLevel == .online }.count, 3)
        XCTAssertNotNil(SiteTool.tool("offline"))
        XCTAssertEqual(SiteTool.tool("offline")?.shortTitle, "بدون إنترنت")
    }

    func testSavedHadithSearchAndCheck() throws {
        let dir = SiteAPI.cacheDir
        let page = SiteAPI.HadithPage(
            cats: [.init(name: "العبادات", count: 2)], total: 2, page: 1,
            items: [
                .init(id: "t1", title: nil, text: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى", source: "متفق عليه", grade: "صحيح", cat: "العبادات", url: "u1", match: nil),
                .init(id: "t2", title: nil, text: "الطهور شطر الإيمان", source: "مسلم", grade: "صحيح", cat: "العبادات", url: "u2", match: nil),
            ])
        let file = dir.appendingPathComponent("hadith-test-offline")
        try JSONEncoder().encode(page).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let found = SiteAPI.savedHadith(cat: "", page: 1, query: "الأعمال")
        XCTAssertEqual(found?.items.first?.id, "t1")
        XCTAssertEqual(found?.offline, true)
        let checked = SiteAPI.checkHadithSaved("إنما الأعمال بالنيات")
        XCTAssertEqual(checked.first?.id, "t1")
        XCTAssertGreaterThanOrEqual(checked.first?.match ?? 0, 50)
        XCTAssertTrue(SiteAPI.checkHadithSaved("كلام لا علاقة له بشيء هنا").isEmpty)
    }

    @MainActor func testRecitationEstimateForJuzAmma() {
        let mb = OfflinePrep.estimateMB(Array(78...114))
        XCTAssertGreaterThan(mb, 20)
        XCTAssertLessThan(mb, 60)
    }
}
