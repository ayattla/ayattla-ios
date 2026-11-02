import XCTest
import AVFoundation
@testable import AyatTutla

final class SiteFeaturesTests: XCTestCase {
    func testPackHasRuqyaAsmaAndQuranComIDs() throws {
        let lib = ContentLibrary.shared
        let r = try XCTUnwrap(lib.ruqya)
        XCTAssertFalse(r.items.isEmpty)
        XCTAssertEqual(lib.asma.count, 99)
        let ids = try XCTUnwrap(try lib.store?.reciterQuranComIDs())
        XCTAssertFalse(ids.isEmpty)
        XCTAssertTrue(ids.keys.allSatisfy { k in Catalog.reciters.first { $0.id == k }?.wordHighlight == true })
    }

    func testTajweedHTMLParsing() {
        let html = #"قُلْ هُوَ <span class="tj-ham_wasl">ٱ</span>للَّهُ أَحَ<span class="tj-qalaqah">د</span>ٌ <span class="tj-end">١</span>"#
        let a = Tajweed.attributed(html)
        XCTAssertEqual(String(a.characters), "قُلْ هُوَ ٱللَّهُ أَحَدٌ \u{06DD}١")
        XCTAssertTrue(a.runs.contains { $0.foregroundColor != nil })
    }

    func testWordCountSkipsPauseMarksAndEndMarker() {
        XCTAssertEqual(QuranWords.count("ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًۭى لِّلْمُتَّقِينَ \u{06DD}٢"), 7)
        let h = QuranWords.highlighted("أ ۖ ب ج", word: 1, color: .red)
        let colored = h.runs.filter { $0.foregroundColor != nil }.map { String(h[$0.range].characters) }
        XCTAssertEqual(colored, ["ب"])
    }

    func testDownloadsLocalLookup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let d = RecitationDownloads(root: root)
        XCTAssertNil(d.local(folder: "F", surah: 1, ayah: 1))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("F"), withIntermediateDirectories: true)
        for a in 1...7 { try Data([1]).write(to: d.file(folder: "F", surah: 1, ayah: a)) }
        XCTAssertTrue(d.isDownloaded(folder: "F", surah: 1, ayahCount: 7))
        XCTAssertEqual(d.inventory { $0 == 1 ? 7 : 3 }["F"], [1])
        d.delete(folder: "F", surah: 1, ayahCount: 7)
        XCTAssertFalse(d.isDownloaded(folder: "F", surah: 1, ayahCount: 7))
    }

    /// End to end against the live services (skipped offline): site tajweed and words, Quran.com timings,
    /// and a highlighted clip of Al-Ikhlas.
    @MainActor func testLiveTajweedWordsAndHighlightedClip() async throws {
        do {
            let tj = try await QF.tajweed(chapter: 112)
            XCTAssertEqual(tj.verses.count, 4)
            let w = try await QF.words(chapter: 112, lang: "en")
            XCTAssertEqual(w.verses.first?.words.count, 4)
            let id = try XCTUnwrap(try ContentLibrary.shared.store?.reciterQuranComIDs().values.first)
            let rec = try await QF.recitation(id, chapter: 112)
            XCTAssertEqual(rec.audio_file.timestamps.count, 4)
            // Our Tanzil words must line up with Quran.com's timed words for Al-Ikhlas.
            for a in try XCTUnwrap(try ContentLibrary.shared.store?.ayat(surah: 112, from: 1, to: 4)) {
                let st = try XCTUnwrap(rec.audio_file.timestamps.first { $0.verse_key == "112:\(a.ayah)" })
                XCTAssertEqual(st.segments.map { Int($0[0]) }.max(), QuranWords.count(a.textUthmani), "112:\(a.ayah)")
            }
        } catch let e as URLError {
            throw XCTSkip("offline: \(e)")
        }
    }
}
