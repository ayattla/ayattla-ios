import XCTest
@testable import AyatTutla

final class SavedAyatTests: XCTestCase {
    func testNotesAndTags() {
        let a = RecitationPlayer.Position(surah: 2, ayah: 255), b = RecitationPlayer.Position(surah: 1, ayah: 1)
        var raw = FavoriteNotes.setting("", a, .init(note: " للحفظ هذا الأسبوع ", tag: "حفظ"))
        raw = FavoriteNotes.setting(raw, b, .init(note: "", tag: "تدبر"))
        XCTAssertEqual(FavoriteNotes.all(raw)["2:255"], .init(note: "للحفظ هذا الأسبوع", tag: "حفظ"))
        XCTAssertEqual(Set(FavoriteNotes.tags(raw)), ["حفظ", "تدبر"])
        raw = FavoriteNotes.setting(raw, b, .init())        // empty entry removes it
        XCTAssertNil(FavoriteNotes.all(raw)["1:1"])
        XCTAssertEqual(FavoriteNotes.tags(raw), ["حفظ"])
    }

    func testRepeatTitles() {
        XCTAssertEqual(RecitationPlayer.repeats.map(RecitationPlayer.repeatTitle),
                       ["مرة واحدة", "٣ مرات", "٥ مرات", "١٠ مرات", "بلا حد"])
    }
}
