import XCTest
@testable import AyatContent

/// Fixture built by tools/build_content_pack.py from placeholder strings (no real religious text).
final class ContentStoreTests: XCTestCase {
    private func store() throws -> ContentStore {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "fixture", withExtension: "sqlite", subdirectory: "Fixtures"))
        return try ContentStore(url: url)
    }

    func testSurahsAndRange() throws {
        let s = try store()
        XCTAssertEqual(try s.surahs().count, 114)
        let a = try s.ayat(surah: 1, from: 1, to: 2)
        XCTAssertEqual(a.map(\.id), ["1:1", "1:2"])
        XCTAssertEqual(a[0].textUthmani, "نَصٌّ أَوَّلُ 1:1", "text must come back byte for byte")
    }

    func testSurahNamesForUI() throws {
        let first = try XCTUnwrap(try store().surahs().first)
        XCTAssertEqual(first.namePlain, "سورة 1")
        XCTAssertEqual(first.shortName, "1")
        XCTAssertFalse(first.hasBasmala)
        XCTAssertEqual(try store().pageCount(), 114)
    }

    func testSearchIgnoresTashkeel() throws {
        XCTAssertEqual(try store().search("نص", limit: 500).count, 228)
        XCTAssertEqual(try store().search("نَصّ", limit: 500).count, 228)
    }

    func testFixtureIsPartialSoCompletenessFails() throws {
        XCTAssertThrowsError(try store().checkComplete())
    }

    func testAzkarAndTranslation() throws {
        let s = try store()
        XCTAssertEqual(try s.azkarCategories().first?.title, "باب اختبار")
        let z = try XCTUnwrap(try s.azkar(category: 1).first)
        XCTAssertEqual(z.count, 3); XCTAssertEqual(z.audioId, 7)
        XCTAssertEqual(try s.translation(edition: "muyassar", surah: 1, ayah: 1), "ترجمة اختبار 1:1")
    }

    func testReciterFolders() throws {
        XCTAssertEqual(try store().reciterFolders(), ["r1": "Test_64kbps"])
    }

    func testCleanMatchesBuilder() {
        XCTAssertEqual(ContentStore.clean("أَإِآ  ٱلـ"), "ااا ال")
    }
}
