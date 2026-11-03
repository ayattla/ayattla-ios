import XCTest
@testable import AyatTutla

/// Only one source plays at a time; a stopped source leaves the mini player.
final class AudioCenterTests: XCTestCase {
    final class Fake: AudioSource {
        var playing = false, stopped = false
        var audioIsPlaying: Bool { playing }
        var audioTitle: String { "عنوان" }
        var audioSubtitle: String { "" }
        var audioIsLive: Bool { false }
        func audioPause() { playing = false }
        func audioResume() { playing = true }
        func audioNext() {}
        func audioPrevious() {}
        func audioStop() { playing = false; stopped = true }
    }

    func testClaimStopsThePreviousSource() {
        let c = AudioCenter.shared
        let a = Fake(), b = Fake()
        c.claim(a); a.playing = true
        c.claim(b); b.playing = true
        XCTAssertTrue(a.stopped)
        XCTAssertTrue(c.active === b)
        c.toggle()
        XCTAssertFalse(b.playing)
        c.release(a)                       // not active: no effect
        XCTAssertTrue(c.active === b)
        c.release(b)
        XCTAssertNil(c.active)
    }
}
