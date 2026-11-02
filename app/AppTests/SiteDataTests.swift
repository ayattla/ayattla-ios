import XCTest
@testable import AyatTutla

final class SiteDataTests: XCTestCase {
    func testPackHasGuideAndDuas() throws {
        let lib = ContentLibrary.shared
        let g = try XCTUnwrap(lib.prayerGuide)
        XCTAssertFalse(g.sections.isEmpty)
        XCTAssertTrue(g.sections.allSatisfy { !$0.items.isEmpty })
        XCTAssertTrue(g.sections.flatMap(\.items).allSatisfy { $0.url.contains("hadeethenc.com") })
        let d = try XCTUnwrap(lib.duas)
        XCTAssertFalse(d.quran.isEmpty)
        XCTAssertFalse(d.needs.isEmpty)
        for q in d.quran {
            let ayat = try XCTUnwrap(try lib.store?.ayat(surah: q.s, from: q.a, to: q.b))
            XCTAssertEqual(ayat.count, q.b - q.a + 1)
        }
    }

    func testHadithDecodingAcceptsStringAndNumberIds() throws {
        let json = #"{"query_words":3,"items":[{"id":"4560","title":"ت","text":"نص","source":"متفق عليه","grade":"صحيح","cat":"ب","url":"https://hadeethenc.com/ar/browse/hadith/4560","match":100},{"id":7,"text":"نص","source":"س","grade":"ح","url":""}]}"#
        let r = try JSONDecoder().decode(SiteAPI.HadithCheck.self, from: Data(json.utf8))
        XCTAssertEqual(r.items.map(\.id), ["4560", "7"])
        XCTAssertEqual(r.items[0].match, 100)
        let page = #"{"cats":[{"name":"العقيدة","count":665}],"total":0,"page":1,"items":[]}"#
        XCTAssertEqual(try JSONDecoder().decode(SiteAPI.HadithPage.self, from: Data(page.utf8)).cats.first?.count, 665)
    }

    func testHifzPickSkipsPauseMarksAndRespectsShare() {
        let words = ["كلمة", "ۖ", "ثانية", "ثالثة", "رابعة"]
        let keys = (0..<5).map { "k\($0)" }
        XCTAssertEqual(HifzTestView.pick(keys, words: words, share: 1, seed: 1), ["k0", "k2", "k3", "k4"])
        XCTAssertEqual(HifzTestView.pick(keys, words: words, share: 0.5, seed: 7).count, 2)
        XCTAssertFalse(HifzTestView.pick(keys, words: words, share: 0.5, seed: 7).contains("k1"))
    }

    /// Live site endpoints used by the hadith, checker and radio screens (skipped offline).
    func testLiveEndpoints() async throws {
        do {
            let page = try await SiteAPI.hadith(cat: "", page: 1, query: "الصلاة")
            XCTAssertGreaterThan(page.total, 0)
            XCTAssertFalse(page.items.isEmpty)
            let radios = try await SiteAPI.radios()
            XCTAssertGreaterThan(radios.count, 10)
        } catch let e as URLError {
            throw XCTSkip("offline: \(e)")
        }
    }
}
