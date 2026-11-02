import XCTest
import UIKit
@testable import AyatTutla

/// Runs against the content pack the CI content job bundles into the app.
final class ContentTests: XCTestCase {
    private let lib = ContentLibrary.shared

    func testBundledPackIsCompleteAndVerified() throws {
        XCTAssertTrue(lib.isReady, "content pack missing or failed its checks: \(lib.problem ?? "")")
        XCTAssertEqual(lib.surahs.count, 114)
        XCTAssertEqual(lib.pageCount, 604)
        XCTAssertEqual(lib.surahs.filter(\.hasBasmala).count, 112)
        XCTAssertFalse(lib.surahs[0].hasBasmala)
        XCTAssertFalse(lib.surahs[8].hasBasmala)
        XCTAssertNotNil(lib.basmala)
        XCTAssertEqual(lib.version, "1")
    }

    func testSurahNamesHaveNoTashkeel() {
        let tashkeel = CharacterSet(charactersIn: "\u{064B}"..."\u{0652}").union(CharacterSet(charactersIn: "\u{0670}"))
        for s in lib.surahs {
            XCTAssertNil(s.shortName.rangeOfCharacter(from: tashkeel), s.shortName)
            XCTAssertFalse(s.shortName.hasPrefix("سورة"), s.shortName)
        }
    }

    func testEveryReciterHasAFolder() throws {
        let folders = try XCTUnwrap(try lib.store?.reciterFolders())
        for r in Catalog.reciters { XCTAssertNotNil(folders[r.id], r.id) }
    }

    func testAzkarChapters() throws {
        let cats = try XCTUnwrap(try lib.store?.azkarCategories())
        XCTAssertEqual(cats.count, 135)
        for t in AzkarView.pinned { XCTAssertTrue(cats.contains { $0.title == t }, t) }
    }

    func testAyahOfTheDayPicksExist() throws {
        for p in AyahOfTheDay.picks {
            let ayat = try XCTUnwrap(try lib.store?.ayat(surah: p.surah, from: p.from, to: p.to))
            XCTAssertEqual(ayat.count, p.to - p.from + 1, "\(p)")
        }
    }

    func testFontsRegistered() {
        _ = lib
        XCTAssertFalse(UIFont.fontNames(forFamilyName: ContentLibrary.mushafFont).isEmpty, "Amiri Quran")
        XCTAssertFalse(UIFont.fontNames(forFamilyName: "Amiri").isEmpty, "Amiri")
    }
}

final class QuranLogicTests: XCTestCase {
    func testFavoritesToggle() {
        var raw = ""
        raw = Favorites.toggled(raw, .init(surah: 2, ayah: 255))
        raw = Favorites.toggled(raw, .init(surah: 1, ayah: 1))
        XCTAssertEqual(raw, "1:1,2:255")
        raw = Favorites.toggled(raw, .init(surah: 2, ayah: 255))
        XCTAssertEqual(Favorites.list(raw), [.init(surah: 1, ayah: 1)])
    }

    func testEveryAyahURL() {
        XCTAssertEqual(RecitationPlayer.url(folder: "Abdul_Basit_Murattal_192kbps", surah: 2, ayah: 7)?.absoluteString,
                       "https://everyayah.com/data/Abdul_Basit_Murattal_192kbps/002007.mp3")
    }

    func testAyahLinkParsing() {
        XCTAssertEqual(MushafReader.position(URL(string: "ayah:2:255")!), .init(surah: 2, ayah: 255))
        XCTAssertNil(MushafReader.position(URL(string: "https://x.y")!))
    }

    func testAyatCountWording() {
        XCTAssertEqual(QuranText.ayatCount(7), "٧ آيات")
        XCTAssertEqual(QuranText.ayatCount(286), "٢٨٦ آية")
    }

    func testAzkarProgressResetsDaily() {
        let d = UserDefaults(suiteName: "azkar-test")!
        d.removePersistentDomain(forName: "azkar-test")
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        AzkarProgress.set(5, 2, d, now: day1)
        XCTAssertEqual(AzkarProgress.counts(d, now: day1)["5"], 2)
        XCTAssertEqual(AzkarProgress.counts(d, now: day1.addingTimeInterval(86_400 * 2)), [:])
    }
}
