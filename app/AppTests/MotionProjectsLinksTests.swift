import XCTest
import AVFoundation
@testable import AyatTutla

final class RouteTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(Route.parse(URL(string: "ayattla://ayah/2/255")!), .ayah(surah: 2, ayah: 255))
        XCTAssertNil(Route.parse(URL(string: "ayattla://ayah/2/999")!))
        XCTAssertNil(Route.parse(URL(string: "ayattla://ayah/115/1")!))
        XCTAssertEqual(Route.parse(URL(string: "ayattla://studio/new?type=video&s=1&a=1&b=7")!), .newClip(surah: 1, from: 1, to: 7))
        XCTAssertEqual(Route.parse(URL(string: "ayattla://studio/new?type=card&s=2&a=255")!), .newCard(surah: 2, from: 255, to: 255))
        XCTAssertEqual(Route.parse(URL(string: "ayattla://tools/qada-salah")!), .tool(.qada))
        XCTAssertEqual(Route.parse(URL(string: "ayattla://khatma")!), .khatma)
        XCTAssertEqual(Route.parse(URL(string: Route.azkarLink("أذكار المساء"))!), .azkar("أذكار المساء"))
        XCTAssertNil(Route.parse(URL(string: "https://ayattla.com/tools/zakat")!))
    }

    func testRemindersCarryLinks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = Reminders.plan(now: now, azkar: true, dailyAyah: true, khatma: nil, city: .all[0]) { _ in nil }
        XCTAssertTrue(items.allSatisfy { $0.link.flatMap { URL(string: $0) }.flatMap(Route.parse) != nil })
    }
}

final class ProjectStoreTests: XCTestCase {
    func testAddListReloadDelete() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProjectStore(dir: dir)
        let img = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { c in
            UIColor.green.setFill(); c.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let e = EditorSettings(surah: 2, from: 255, to: 255, ratio: "1:1", background: "emerald", fontScale: 1,
                               template: "", name: "", reciter: "sudais")
        let p = try store.addImage(img, kind: .card, title: "بطاقة", ratio: "1:1", settings: e)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(p).path))
        XCTAssertEqual(ProjectStore(dir: dir).projects.first?.settings, e, "index survives a reload")
        store.delete(p)
        XCTAssertTrue(ProjectStore(dir: dir).projects.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(p).path))
    }
}

final class MotionTests: XCTestCase {
    private func pixel(_ img: UIImage, _ x: Int, _ y: Int) -> [UInt8] {
        let cg = img.cgImage!
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return px
    }

    func testEveryStyleDrawsAndMoves() {
        let size = CGSize(width: 120, height: 200)
        for s in MotionStyle.allCases {
            let a = MotionBackground.style(s).still(size: size, t: 0)
            let b = MotionBackground.style(s).still(size: size, t: 4)
            XCTAssertEqual(a.size, size)
            XCTAssertNotEqual(a.pngData(), b.pngData(), "\(s) should change over time")
            XCTAssertGreaterThan(pixel(a, 60, 100)[3], 0, "\(s) is opaque")
        }
    }

    @MainActor func testMotionClipRenders() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
        buf.frameLength = 44_100
        try file.write(from: buf)
        let overlay = CardCanvas.render(.init(text: "نص", reference: "", template: nil, name: nil,
                                              background: CardOptions.backgrounds[0], fontScale: 1, ratio: .square,
                                              lightBackground: false, clearBackground: true), photo: nil)!
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try await VideoEngine.render([.init(frame: overlay, audio: url)], size: CGSize(width: 540, height: 540), to: out,
                                     background: .style(.aurora))
        let asset = AVURLAsset(url: out)
        XCTAssertEqual(try await asset.load(.duration).seconds, 1, accuracy: 0.15)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
        let f1 = try await gen.image(at: CMTime(value: 1, timescale: 10)).image
        let f2 = try await gen.image(at: CMTime(value: 9, timescale: 10)).image
        XCTAssertNotEqual(UIImage(cgImage: f1).pngData(), UIImage(cgImage: f2).pngData(), "background moves between frames")
    }
}
