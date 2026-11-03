import SwiftUI
import AVFoundation
import Photos
import AyatDesign

/// «نص متحرك بلا صوت», the status editor's third output on the site: the card's text is lit word
/// by word at a calm reading pace, then held, as an MP4 with no recitation. Built on the same
/// timeline renderer as word highlighting, fed a silent track.
enum AnimatedText {
    /// Seconds per word, and the limits of the whole clip (WhatsApp statuses stop at 30 s).
    static let pace = 0.5, lead = 0.6, hold = 2.0, maxDuration = 30.0

    /// Times at which each word lights up, and the clip length.
    static func timing(words: Int) -> (starts: [Double], duration: Double) {
        guard words > 0 else { return ([], 4) }
        let step = min(pace, (maxDuration - lead - hold) / Double(words))
        let starts = (0..<words).map { lead + Double($0) * step }
        return (starts, max(6, lead + Double(words) * step + hold))
    }

    @MainActor static func render(_ model: CardCanvas.Model, photo: UIImage?, color: UInt32 = 0xF7CD6E,
                                  progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let words = QuranWords.count(model.text)
        let (starts, duration) = timing(words: words)
        var keys: [VideoEngine.Keyframe] = [.init(time: 0) { CardCanvas.render(model, photo: photo) }]
        for (i, t) in starts.enumerated() {
            var m = model
            m.highlightWord = i
            m.highlightColor = color
            let frame = m
            keys.append(.init(time: t) { CardCanvas.render(frame, photo: photo) })
        }
        // Last word lit, then the whole text plain for the hold.
        keys.append(.init(time: duration - hold) { CardCanvas.render(model, photo: photo) })
        let silence = try silentAudio(seconds: duration)
        defer { try? FileManager.default.removeItem(at: silence) }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("حالة-\(UUID().uuidString.prefix(6)).mp4")
        try await VideoEngine.renderTimeline(audio: silence, range: CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600)),
                                             keyframes: keys, size: model.ratio.size, to: out, progress: progress)
        return out
    }

    /// A silent PCM file of the given length (the timeline renderer takes its length from audio).
    static func silentAudio(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let total = AVAudioFrameCount(seconds * 44_100)
        let chunk: AVAudioFrameCount = 44_100
        var written: AVAudioFrameCount = 0
        while written < total {
            let n = min(chunk, total - written)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
            buffer.frameLength = n           // new buffers are zero-filled
            try file.write(from: buffer)
            written += n
        }
        return url
    }
}

/// Button that renders the animated-text status, then offers sharing and saving.
struct AnimatedTextButton: View {
    let model: CardCanvas.Model
    let photo: UIImage?
    let title: String

    enum Phase: Equatable { case idle, working(Double), done(URL), failed }
    @State private var phase = Phase.idle
    @State private var savedToPhotos = false

    var body: some View {
        switch phase {
        case .idle, .failed:
            Button {
                Task { await make() }
            } label: {
                Label("نص متحرك بلا صوت (فيديو)", systemImage: "text.word.spacing")
            }
            if phase == .failed {
                Text("تعذر إنشاء الفيديو").font(.ui(.footnote)).foregroundStyle(.red)
            }
        case .working(let p):
            ProgressView(value: p) { Text("إنشاء النص المتحرك").font(.ui(.footnote)) }
                .tint(Brand.primaryInk)
        case .done(let url):
            ShareLink(item: url) { Label("مشاركة النص المتحرك", systemImage: "square.and.arrow.up") }
            Button {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { ok, _ in Task { @MainActor in savedToPhotos = ok } }
            } label: { Label(savedToPhotos ? "حفظ في الصور ✓" : "حفظ في الصور", systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down") }
                .disabled(savedToPhotos)
            Button("نص متحرك جديد") { phase = .idle; savedToPhotos = false }
        }
    }

    @MainActor private func make() async {
        phase = .working(0)
        do {
            let url = try await AnimatedText.render(model, photo: photo) { p in
                Task { @MainActor in phase = .working(p) }
            }
            let thumb = CardCanvas.render(model, photo: photo)
            _ = try? ProjectStore.shared.add(kind: .status, title: title, file: url, thumbnail: thumb,
                                              ratio: model.ratio.rawValue, settings: nil)
            phase = .done(url)
        } catch {
            phase = .failed
        }
    }
}
