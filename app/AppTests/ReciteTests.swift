import XCTest
import AyatContent
@testable import AyatTutla

/// Fixtures are Al-Fatiha in the pack's Uthmani spelling; heard text is plain spelling, as recognizers
/// write it. Same cases as the Android ReciteTest.
final class ReciteTests: XCTestCase {
    private let fatiha = [
        "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
        "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ",
        "ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
        "مَٰلِكِ يَوْمِ ٱلدِّينِ",
        "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
        "ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ",
    ]
    private var expected: [String] { fatiha.flatMap(Recite.tokens).map(Recite.key) }
    private func run(_ heard: String) -> Recite.Progress { Recite.align(expected, Recite.heardKeys(heard)) }

    func testUthmaniAndPlainSpellingMatch() {
        for (u, p) in [("ٱلصَّلَوٰةَ", "الصلاة"), ("إِبْرَٰهِۦمَ", "إبراهيم"), ("ٱلْكِتَٰبُ", "الكتاب"), ("شَىْءٍ", "شيء"), ("مَٰلِكِ", "مالك")] {
            XCTAssertTrue(Recite.similar(Recite.key(u), Recite.key(p)), "\(u) ~ \(p)")
        }
        XCTAssertFalse(Recite.similar(Recite.key("قَالَ"), Recite.key("كان")))
        XCTAssertFalse(Recite.similar(Recite.key("رَبِّ"), Recite.key("من")))
    }

    func testFullRecitationWithIstiadhaIsAllCorrect() {
        let p = run("أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين إياك نعبد وإياك نستعين اهدنا الصراط المستقيم")
        XCTAssertTrue(p.done)
        XCTAssertTrue(p.review.isEmpty)
    }

    func testSkippedWordsAreMarkedForReview() {
        let p = run("بسم الله الرحمن الرحيم الحمد لله رب العالمين مالك يوم الدين")
        XCTAssertEqual(p.revealed, 13)
        XCTAssertEqual(p.review, [8, 9])
    }

    func testWordHeardDifferentlyIsRevealedForReview() {
        let p = run("بسم الله الرحمن الرحيم الحمد لله رب الناس الناس الناس الرحمن")
        XCTAssertEqual(p.review, [7])
        XCTAssertEqual(p.revealed, 9)
    }

    func testHintRevealsNextWordForReview() {
        let p = Recite.align(expected, Recite.heardKeys("بسم الله") + [Recite.hint(2)] + Recite.heardKeys("الرحيم"))
        XCTAssertEqual(p.revealed, 4)
        XCTAssertEqual(p.review, [2])
    }

    func testStopMarksAreNotWords() {
        let t = Recite.tokens("لَا رَيْبَ ۛ فِيهِ ۛ هُدًى")
        XCTAssertEqual(t.count, 6)
        XCTAssertEqual(Recite.wordIndexes(t), [0, 1, 3, 5])
    }

    func testVoiceSearchFindsTheAyah() {
        let ayat = fatiha.enumerated().map { Ayah(surah: 1, ayah: $0.offset + 1, textUthmani: $0.element, page: 1, juz: 1) }
            + [Ayah(surah: 112, ayah: 1, textUthmani: "قُلْ هُوَ ٱللَّهُ أَحَدٌ", page: 604, juz: 30)]
        let vs = VoiceSearch(ayat: ayat)
        XCTAssertEqual(vs.find("إياك نعبد وإياك نستعين").first?.ayah.ayah, 5)
        XCTAssertEqual(vs.find("قل هو الله أحد").first?.ayah.surah, 112)
        XCTAssertTrue(vs.find("كتب عليكم الصيام").isEmpty)
    }
}

final class WelcomeTests: XCTestCase {
    /// Every answer points only to tools that really exist in the app.
    func testAnswersPointToRealTools() {
        for id in (Welcome.uses + Welcome.likes).flatMap(\.tools) { XCTAssertNotNil(SiteTool.tool(id), "missing tool \(id)") }
    }

    func testSameIdsAsAndroid() {
        XCTAssertEqual(Welcome.Step.allCases.map(\.rawValue), ["hello", "uses", "likes", "listen", "reminders", "theme", "done"])
        XCTAssertEqual(Welcome.uses.map(\.id), ["quran", "listen", "status", "clips", "azkar", "hadith", "cards", "gifts", "tafsir", "hifz", "all"])
    }

    func testHomeOrderMovesInterestsUpWithoutHidingAnything() {
        let base = HomeSectionID.allCases
        UserDefaults.standard.set(["azkar"], forKey: "welcome.uses")
        defer { UserDefaults.standard.removeObject(forKey: "welcome.uses") }
        let order = Welcome.homeOrder(base)
        XCTAssertEqual(Set(order), Set(base))
        XCTAssertEqual(order.count, base.count)
        XCTAssertEqual(order.first, .prayer)
        XCTAssertLessThan(order.firstIndex(of: .dhikr)!, order.firstIndex(of: .create)!)
    }

    func testStatsKeysAreCleaned() {
        XCTAssertEqual(Stats.clean("tool_opened"), "tool_opened")
        XCTAssertEqual(Stats.clean("prayer-times"), "prayer-times")
        XCTAssertEqual(Stats.clean("نص حر"), "")
        XCTAssertLessThanOrEqual(Stats.clean(String(repeating: "x", count: 100)).count, 48)
    }
}
