import XCTest
import AVFoundation
import AyatDesign
@testable import AyatTutla

/// The site's media library client, favorites, the tool usage list and the video background reader.
final class MediaLibraryTests: XCTestCase {
    /// Two items as /api/media/search returns them (copied from a real response, 2026-11-04).
    static let sample = """
    {"items":[{"provider":"pixabay","mediaId":"128406","type":"video","tags":"mosque","authorName":"x","authorUrl":"https://pixabay.com/users/x/",
    "pageUrl":"https://pixabay.com/videos/id-128406/","thumbUrl":"https://cdn.pixabay.com/video/2022/08/19/128406-741495445_tiny.jpg",
    "previewUrl":"https://cdn.pixabay.com/video/2022/08/19/128406-741495445_tiny.mp4","width":1440,"height":2560,"duration":11,"curated":true},
    {"provider":"pexels","mediaId":6604492,"type":"image","thumbUrl":"https://images.pexels.com/a.jpg","previewUrl":null,
    "width":4000,"height":3000,"duration":null}],"fallback":false,"providers":["pixabay"]}
    """

    private struct Page: Decodable { let items: [MediaLibrary.Item] }

    func testDecodesSiteResponse() throws {
        let items = try JSONDecoder().decode(Page.self, from: Data(Self.sample.utf8)).items
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].type, .video)
        XCTAssertEqual(items[0].duration, 11)
        XCTAssertTrue(items[0].curated)
        XCTAssertTrue(items[0].isPortrait)
        XCTAssertEqual(items[1].mediaId, "6604492", "numeric ids are accepted")
        XCTAssertFalse(items[1].curated)
        XCTAssertFalse(items[1].isPortrait)
        XCTAssertEqual(items[1].providerName, "Pexels")
        XCTAssertNil(items[1].previewUrl)
    }

    func testRefKeyAndRawURL() throws {
        let r = MediaLibrary.Ref(provider: "pixabay", mediaId: "128406", type: .video)
        XCTAssertEqual(r.key, "pixabay:128406:video")
        XCTAssertEqual(MediaLibrary.Ref(key: r.key), r)
        XCTAssertNil(MediaLibrary.Ref(key: "pixabay:1"))
        XCTAssertNil(MediaLibrary.Ref(key: "pixabay:1:audio"))
        let c = try XCTUnwrap(URLComponents(url: MediaLibrary.rawURL(r, width: 540), resolvingAgainstBaseURL: false))
        XCTAssertEqual(c.host, "ayattla.com")
        XCTAssertEqual(c.path, "/api/media/raw")
        XCTAssertEqual(c.queryItems?.first { $0.name == "rm" }?.value, "pixabay:128406:video")
        XCTAssertEqual(c.queryItems?.first { $0.name == "w" }?.value, "540")
    }

    func testFavoritesKeepOnlyTheReference() {
        let saved = UserDefaults.standard.object(forKey: MediaLibrary.favoritesKey)
        defer { UserDefaults.standard.set(saved, forKey: MediaLibrary.favoritesKey) }
        MediaLibrary.favorites = []
        let a = MediaLibrary.Ref(provider: "pixabay", mediaId: "1", type: .image)
        let b = MediaLibrary.Ref(provider: "pexels", mediaId: "2", type: .video)
        MediaLibrary.toggleFavorite(a); MediaLibrary.toggleFavorite(b)
        XCTAssertEqual(MediaLibrary.favorites, [b, a], "newest first")
        XCTAssertEqual(UserDefaults.standard.array(forKey: MediaLibrary.favoritesKey) as? [String], ["pexels:2:video", "pixabay:1:image"],
                       "only provider, id and type are stored, no file links")
        MediaLibrary.toggleFavorite(a)
        XCTAssertEqual(MediaLibrary.favorites, [b])
        for i in 0..<70 { MediaLibrary.toggleFavorite(.init(provider: "pixabay", mediaId: "\(i + 100)", type: .image)) }
        XCTAssertEqual(MediaLibrary.favorites.count, 60, "at most 60, as the site")
    }

    func testFallbackCollectionsMatchTheSite() {
        let ids = MediaLibrary.fallbackCollections.map(\.id)
        XCTAssertTrue(["sky", "mosques", "night", "nature"].allSatisfy(ids.contains))
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testDurationText() {
        XCTAssertNil(MediaLibrary.durationText(nil))
        XCTAssertNil(MediaLibrary.durationText(0))
        let t = MediaLibrary.durationText(65)!
        XCTAssertTrue(t.hasPrefix("\u{2066}") && t.hasSuffix("\u{2069}"), "kept left to right inside Arabic text")
        XCTAssertEqual(t.filter { $0 != "\u{2066}" && $0 != "\u{2069}" }, "\(Num.int(1)):\(Num.int(0))\(Num.int(5))")
    }

    func testToolUsageOrdersByUse() {
        let saved = UserDefaults.standard.object(forKey: ToolUsage.key)
        defer { UserDefaults.standard.set(saved, forKey: ToolUsage.key) }
        ToolUsage.counts = [:]
        XCTAssertEqual(ToolUsage.top(3).map(\.id), ["listen", "prayer-times", "azkar"], "site defaults before any use")
        ToolUsage.record("zakat"); ToolUsage.record("zakat"); ToolUsage.record("qibla")
        let top = ToolUsage.top(4).map(\.id)
        XCTAssertEqual(Array(top.prefix(2)), ["zakat", "qibla"])
        XCTAssertEqual(Set(top).count, top.count, "no duplicates")
    }

    /// A background video is read frame by frame, and starts again when the clip is longer.
    @MainActor func testVideoFramesLoop() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
        buf.frameLength = 44_100
        try file.write(from: buf)
        let overlay = CardCanvas.render(.init(text: "", reference: "", template: nil, name: nil,
                                              background: CardOptions.backgrounds[0], fontScale: 1, ratio: .square,
                                              lightBackground: false, clearBackground: true), photo: nil)!
        let video = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try await VideoEngine.render([.init(frame: overlay, audio: url)], size: CGSize(width: 320, height: 320), to: video,
                                     background: .style(.aurora))
        let made = await VideoFrames(url: video)
        let frames = try XCTUnwrap(made)
        var got = 0
        for i in 0..<75 {   // 2.5 s at 30 fps from a 1 s video
            if frames.frame(at: Double(i) / 30) != nil { got += 1 }
        }
        frames.close()
        XCTAssertEqual(got, 75, "every frame has a picture, including after the video loops")

        // And it draws as a clip background.
        let again = await VideoFrames(url: video)
        let bg = MotionBackground.video(try XCTUnwrap(again), poster: nil)
        let still = bg.still(size: CGSize(width: 64, height: 64), t: 0.5)
        XCTAssertEqual(still.size, CGSize(width: 64, height: 64))
        let audioOnly = await VideoFrames(url: url)
        XCTAssertNil(audioOnly, "an audio file is not a video")
    }
}
