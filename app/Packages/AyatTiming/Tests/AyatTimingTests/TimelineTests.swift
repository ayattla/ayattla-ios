import XCTest
@testable import AyatTiming

final class TimelineTests: XCTestCase {
    typealias W = Timeline.Word
    let t = Timeline(ayat: [
        .init(ayah: 1, startMs: 0, endMs: 3000, words: [W(position: 1, startMs: 200, endMs: 900), W(position: 2, startMs: 1000, endMs: 2800)]),
        .init(ayah: 2, startMs: 3000, endMs: 6000, words: [W(position: 1, startMs: 3100, endMs: 4000), W(position: 2, startMs: 4200, endMs: 5900)])
    ])

    func testValid() throws { try t.validate(audioDurationMs: 6000) }

    func testActiveWord() {
        XCTAssertEqual(t.active(at: 100)?.ayah, 1); XCTAssertNil(t.active(at: 100)?.position)
        XCTAssertEqual(t.active(at: 500)?.position, 1)
        XCTAssertEqual(t.active(at: 950)?.position, 1, "gap keeps previous word lit")
        XCTAssertEqual(t.active(at: 1500)?.position, 2)
        XCTAssertEqual(t.active(at: 3050)?.ayah, 2); XCTAssertNil(t.active(at: 3050)?.position)
        XCTAssertEqual(t.active(at: 5000)?.position, 2)
        XCTAssertNil(t.active(at: 6000))
        XCTAssertNil(t.active(at: -1))
    }

    func testRejectsOutOfOrder() {
        let bad = Timeline(ayat: [.init(ayah: 1, startMs: 0, endMs: 3000,
                                        words: [W(position: 1, startMs: 1000, endMs: 1500), W(position: 2, startMs: 500, endMs: 900)])])
        XCTAssertThrowsError(try bad.validate()) { XCTAssertEqual($0 as? Timeline.Problem, .outOfOrder(ayah: 1, position: 2)) }
    }

    func testRejectsBeyondAudio() {
        XCTAssertThrowsError(try t.validate(audioDurationMs: 5000)) { XCTAssertEqual($0 as? Timeline.Problem, .beyondAudio(ayah: 2)) }
    }

    func testShift() {
        let s = t.shifted(by: 1200)
        XCTAssertEqual(s.ayat[0].words[0].startMs, 1400)
        XCTAssertEqual(s.active(at: 1700)?.position, 1)
    }
}
