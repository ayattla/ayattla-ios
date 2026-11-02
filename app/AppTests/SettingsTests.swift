import XCTest
@testable import AyatTutla

final class SettingsTests: XCTestCase {
    private let tashkeel = CharacterSet(charactersIn: "\u{064B}"..."\u{0652}").union(CharacterSet(charactersIn: "\u{0670}"))

    func testFontScalesMatchSite() {
        XCTAssertEqual(FontScale.allCases.map(\.factor), [0.85, 1.0, 1.15])
        XCTAssertEqual(FontScale.m.title, "متوسط")
    }

    func testVersionTextUsesArabicDigits() {
        let s = SettingsView.versionText()
        XCTAssertFalse(s.contains(where: { $0.isASCII && $0.isNumber }), s)
        XCTAssertEqual(SettingsView.contentText(nil), "غير منزلة")
        XCTAssertTrue(SettingsView.contentText("2026.11").contains("٢٠٢٦.١١"))
    }

    func testCatalogMatchesSite() {
        XCTAssertEqual(Catalog.reciters.count, 34)
        XCTAssertEqual(Catalog.reciters.filter(\.wordHighlight).count, 11)
        XCTAssertEqual(Catalog.translations.first?.id, "")
        XCTAssertEqual(Set(Catalog.reciters.map(\.id)).count, 34)
    }

    func testOnboardingHasEveryStepAndNoTashkeel() {
        for step in OnboardingView.Step.allCases {
            let p = try! XCTUnwrap(OnboardingView.pages[step])
            for text in [p.title, p.body] {
                XCTAssertNil(text.rangeOfCharacter(from: tashkeel), text)
            }
        }
        for name in Catalog.reciters.map(\.name) + Catalog.translations.map(\.name) {
            XCTAssertNil(name.rangeOfCharacter(from: tashkeel), name)
        }
    }
}
