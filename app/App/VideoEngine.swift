import Foundation
import AVFoundation
import CoreVideo
import UIKit

/// On-device video engine (docs/TECHNICAL_AUDIT.md §4, first stage): one still frame per segment,
/// shown for exactly as long as that segment's audio, H.264 + AAC in an MP4.
/// Word highlighting needs Quran.com timings (permission pending), so it is not drawn yet.
enum VideoEngine {
    struct Segment {
        let frame: UIImage
        let audio: URL
    }

    enum Failure: Error, Equatable { case noSegments, noAudioTrack(Int), writer(String), export(String) }

    static let fps: Int32 = 30

    /// Renders `segments` into an MP4 at `out`. `progress` goes from 0 to 1.
    static func render(_ segments: [Segment], size: CGSize, to out: URL, background: MotionBackground? = nil,
                       progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        guard !segments.isEmpty else { throw Failure.noSegments }
        try? FileManager.default.removeItem(at: out)

        // 1. Audio: segments back to back.
        let comp = AVMutableComposition()
        guard let audioTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.writer("audio track")
        }
        var starts: [CMTime] = []
        var cursor = CMTime.zero
        for (i, s) in segments.enumerated() {
            let asset = AVURLAsset(url: s.audio)
            let duration = try await asset.load(.duration)
            guard let src = try await asset.loadTracks(withMediaType: .audio).first else { throw Failure.noAudioTrack(i) }
            try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: src, at: cursor)
            starts.append(cursor)
            cursor = cursor + duration
        }
        let total = cursor
        progress(0.1)

        // 2. Silent video: each frame appended at its segment's start, held until the next.
        let silent = out.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + "-v.mp4")
        defer { try? FileManager.default.removeItem(at: silent) }
        if let background {
            // Animated: every frame is drawn (background at time t, then that segment's text over it).
            try await writeMotion(segments.map(\.frame), at: starts, end: total, size: size, background: background, to: silent) {
                progress(0.1 + 0.3 * $0)
            }
        } else {
            try await writeFrames(segments.map(\.frame), at: starts, end: total, size: size, to: silent)
        }
        progress(0.4)

        // 3. Mux video and audio.
        let video = AVURLAsset(url: silent)
        guard let vsrc = try await video.loadTracks(withMediaType: .video).first,
              let vtrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.writer("video track")
        }
        let vdur = try await video.load(.duration)
        try vtrack.insertTimeRange(CMTimeRange(start: .zero, duration: min(vdur, total)), of: vsrc, at: .zero)

        guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.export("session")
        }
        export.outputURL = out
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        let ticker = Task {
            while !Task.isCancelled {
                progress(0.4 + 0.6 * Double(export.progress))
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        await export.export()
        ticker.cancel()
        guard export.status == .completed else { throw Failure.export(export.error?.localizedDescription ?? "\(export.status.rawValue)") }
        progress(1)
    }

    private static func writeFrames(_ frames: [UIImage], at starts: [CMTime], end: CMTime, size: CGSize, to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let w = Int(size.width) / 2 * 2, h = Int(size.height) / 2 * 2
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000, AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
        ])
        guard writer.canAdd(input) else { throw Failure.writer("input") }
        writer.add(input)
        guard writer.startWriting() else { throw Failure.writer(writer.error?.localizedDescription ?? "start") }
        writer.startSession(atSourceTime: .zero)

        func append(_ image: UIImage, _ t: CMTime) async throws {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 10_000_000) }
            guard let buffer = pixelBuffer(image, width: w, height: h) else { throw Failure.writer("pixel buffer") }
            guard adaptor.append(buffer, withPresentationTime: t) else { throw Failure.writer(writer.error?.localizedDescription ?? "append") }
        }
        for (i, f) in frames.enumerated() { try await append(f, starts[i]) }
        // Repeat the last frame one frame before the end so the track lasts the whole audio.
        let last = CMTimeSubtract(end, CMTime(value: 1, timescale: fps))
        if let f = frames.last, last > starts[starts.count - 1] { try await append(f, last) }
        input.markAsFinished()
        writer.endSession(atSourceTime: end)
        await writer.finishWriting()
        guard writer.status == .completed else { throw Failure.writer(writer.error?.localizedDescription ?? "finish") }
    }

    private static func makeWriter(url: URL, size: CGSize) throws -> (AVAssetWriter, AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor, Int, Int) {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let w = Int(size.width) / 2 * 2, h = Int(size.height) / 2 * 2
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000, AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
        ])
        guard writer.canAdd(input) else { throw Failure.writer("input") }
        writer.add(input)
        guard writer.startWriting() else { throw Failure.writer(writer.error?.localizedDescription ?? "start") }
        writer.startSession(atSourceTime: .zero)
        return (writer, input, adaptor, w, h)
    }

    private static func writeMotion(_ overlays: [UIImage], at starts: [CMTime], end: CMTime, size: CGSize,
                                    background: MotionBackground, to url: URL,
                                    progress: (Double) -> Void) async throws {
        let (writer, input, adaptor, w, h) = try makeWriter(url: url, size: size)
        let cgOverlays = overlays.map(\.cgImage)
        let startSeconds = starts.map(\.seconds)
        let total = end.seconds
        let frames = max(1, Int((total * Double(fps)).rounded(.up)))
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        var seg = 0
        for i in 0..<frames {
            try Task.checkCancellation()
            let t = Double(i) / Double(fps)
            while seg + 1 < startSeconds.count && startSeconds[seg + 1] <= t { seg += 1 }
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            var pb: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) }
            if pb == nil {
                CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                                    [kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pb)
            }
            guard let buffer = pb else { throw Failure.writer("pixel buffer") }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: w, height: h, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                background.draw(in: ctx, size: rect.size, t: t, total: total)
                if let o = cgOverlays[seg] { ctx.draw(o, in: rect) }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps)) else {
                throw Failure.writer(writer.error?.localizedDescription ?? "append")
            }
            if i % 15 == 0 { progress(Double(i) / Double(frames)) }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: end)
        await writer.finishWriting()
        guard writer.status == .completed else { throw Failure.writer(writer.error?.localizedDescription ?? "finish") }
    }

    static func pixelBuffer(_ image: UIImage, width w: Int, height h: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pb)
        guard let pb, let cg = image.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return pb
    }
}

/// Fetches EveryAyah ayah audio into a temporary folder for one export; the folder is removed
/// afterwards (offline storage needs EveryAyah's permission, docs/CONTENT_AND_LICENSES.md).
struct RecitationFetcher {
    let folder: String
    let dir: URL

    init(folder: String) {
        self.folder = folder
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString)", isDirectory: true)
    }

    func fetch(_ items: [(surah: Int, ayah: Int)], progress: @escaping @Sendable (Double) -> Void) async throws -> [URL] {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [URL] = []
        for (i, it) in items.enumerated() {
            guard let url = RecitationPlayer.url(folder: folder, surah: it.surah, ayah: it.ayah) else { throw URLError(.badURL) }
            let (tmp, resp) = try await URLSession.shared.download(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let dest = dir.appendingPathComponent(String(format: "%03d%03d-%d.mp3", it.surah, it.ayah, i))
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            out.append(dest)
            progress(Double(i + 1) / Double(items.count))
        }
        return out
    }

    func cleanUp() { try? FileManager.default.removeItem(at: dir) }
}
