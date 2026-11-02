import XCTest
import AVFoundation
@testable import AyatTutla

final class VideoEngineTests: XCTestCase {
    private func tone(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(seconds * 44_100)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        for i in 0..<Int(frames) { buf.floatChannelData![0][i] = 0.1 * sin(Float(i) * 0.05) }
        try file.write(from: buf)
        return url
    }

    @MainActor private func frame(_ ratio: CardOptions.Ratio) -> UIImage {
        CardCanvas.render(.init(text: "نص", reference: "[١]", template: nil, name: nil, background: CardOptions.backgrounds[0],
                                fontScale: 1, ratio: ratio, lightBackground: false), photo: nil)!
    }

    @MainActor func testRendersMP4WithVideoAndAudioForTheWholeLength() async throws {
        let segs = [VideoEngine.Segment(frame: frame(.square), audio: try tone(seconds: 1.0)),
                    VideoEngine.Segment(frame: frame(.square), audio: try tone(seconds: 0.5))]
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try await VideoEngine.render(segs, size: CardOptions.Ratio.square.size, to: out)
        let asset = AVURLAsset(url: out)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 1.5, accuracy: 0.15)
        let v = try await asset.loadTracks(withMediaType: .video)
        let a = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(v.count, 1); XCTAssertEqual(a.count, 1)
        let size = try await v[0].load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1080))
        let vdur = try await v[0].load(.timeRange).duration.seconds
        XCTAssertEqual(vdur, duration, accuracy: 0.15, "video must last as long as the audio")
    }

    func testNoSegmentsFails() async {
        do {
            try await VideoEngine.render([], size: CGSize(width: 2, height: 2), to: URL(fileURLWithPath: "/tmp/x.mp4"))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? VideoEngine.Failure, .noSegments)
        }
    }

    /// End to end with real EveryAyah audio (skipped if the runner is offline).
    @MainActor func testClipFromEveryAyah() async throws {
        let folder = try XCTUnwrap(try ContentLibrary.shared.store?.reciterFolders()["basit_murattal"])
        let fetcher = RecitationFetcher(folder: folder)
        defer { fetcher.cleanUp() }
        let audio: [URL]
        do { audio = try await fetcher.fetch([(112, 1), (112, 2)]) { _ in } } catch { throw XCTSkip("offline: \(error)") }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try await VideoEngine.render(audio.map { .init(frame: frame(.story), audio: $0) }, size: CardOptions.Ratio.story.size, to: out)
        let d = try await AVURLAsset(url: out).load(.duration).seconds
        XCTAssertGreaterThan(d, 1)
    }
}
