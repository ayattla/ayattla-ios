import XCTest
import AVFoundation
@testable import AyatTutla

final class AnimatedTextTests: XCTestCase {
    func testPaceAndLimits() {
        let short = AnimatedText.timing(words: 4)
        for (a, b) in zip(short.starts, [0.6, 1.1, 1.6, 2.1]) { XCTAssertEqual(a, b, accuracy: 0.0001) }
        XCTAssertEqual(short.starts.count, 4)
        XCTAssertEqual(short.duration, 6)                 // at least 6 s
        let long = AnimatedText.timing(words: 200)
        XCTAssertEqual(long.duration, 30, accuracy: 0.001) // WhatsApp status limit
        XCTAssertLessThan(long.starts.last!, 30 - AnimatedText.hold)
    }

    func testSilentTrackLength() throws {
        let url = try AnimatedText.silentAudio(seconds: 2.5)
        defer { try? FileManager.default.removeItem(at: url) }
        let f = try AVAudioFile(forReading: url)
        XCTAssertEqual(f.length, 110_250)
    }
}
