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

final class AzkarLogTests: XCTestCase {
    func testLogAndStreak() {
        let d = UserDefaults(suiteName: "azlog")!
        d.removePersistentDomain(forName: "azlog")
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        for back in 0..<3 {
            let day = cal.date(byAdding: .day, value: -back, to: now)!
            AzkarLog.record("أذكار الصباح", 1, d, now: day)
            AzkarLog.record("أذكار المساء", back == 2 ? 0.5 : 1, d, now: day)
        }
        XCTAssertEqual(AzkarLog.streak(["أذكار الصباح", "أذكار المساء"], now: now, d), 2)
        XCTAssertEqual(AzkarLog.fraction("أذكار المساء", on: cal.date(byAdding: .day, value: -2, to: now)!, d), 0.5)
    }

    func testListenPositionIsKept() {
        let d = UserDefaults.standard
        d.set("ar.alafasy|18|10", forKey: RecitationPlayer.lastKey)
        let last = RecitationPlayer.lastListened(d)
        XCTAssertEqual(last?.folder, "ar.alafasy")
        XCTAssertEqual(last?.position, .init(surah: 18, ayah: 10))
    }
}
