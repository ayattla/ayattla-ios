import Foundation
import AVFoundation
import Observation

/// Ayah-by-ayah recitation streamed from EveryAyah, as on the site's listen tool
/// (repeat each ayah 1/3/5, speed). Nothing is downloaded or stored: offline audio needs
/// EveryAyah's permission (docs/CONTENT_AND_LICENSES.md).
@Observable
final class RecitationPlayer {
    struct Position: Equatable, Hashable { var surah: Int; var ayah: Int }

    static let repeats = [1, 3, 5]
    static let speeds: [Float] = [0.75, 1.0, 1.25, 1.5]

    private(set) var current: Position?
    private(set) var isPlaying = false
    private(set) var failed = false
    var repeatEach = 1
    var speed: Float = 1.0 { didSet { if isPlaying { player.rate = speed } } }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var playedThisAyah = 0
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored var folder: String?
    @ObservationIgnored var ayahCount: (Int) -> Int = { _ in 0 }

    init() {
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
                                                             object: nil, queue: .main) { [weak self] note in
            guard let self, (note.object as? AVPlayerItem) === self.player.currentItem else { return }
            self.finishedAyah()
        }
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    /// https://everyayah.com/data/<folder>/SSSAAA.mp3
    static func url(folder: String, surah: Int, ayah: Int) -> URL? {
        URL(string: String(format: "https://everyayah.com/data/%@/%03d%03d.mp3", folder, surah, ayah))
    }

    func play(from p: Position) {
        guard let folder, let url = Self.url(folder: folder, surah: p.surah, ayah: p.ayah) else { failed = true; return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        failed = false
        current = p
        playedThisAyah = 0
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status) { [weak self] item, _ in
            if item.status == .failed { DispatchQueue.main.async { self?.failed = true; self?.isPlaying = false } }
        }
        player.replaceCurrentItem(with: item)
        player.playImmediately(atRate: speed)
        isPlaying = true
    }

    func toggle(startAt p: Position) {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else if current != nil, player.currentItem != nil, !failed {
            player.playImmediately(atRate: speed)
            isPlaying = true
        } else {
            play(from: p)
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        current = nil
    }

    func next() {
        guard let c = current else { return }
        if c.ayah < ayahCount(c.surah) { play(from: .init(surah: c.surah, ayah: c.ayah + 1)) }
        else if c.surah < 114 { play(from: .init(surah: c.surah + 1, ayah: 1)) }
        else { stop() }
    }

    func previous() {
        guard let c = current else { return }
        if c.ayah > 1 { play(from: .init(surah: c.surah, ayah: c.ayah - 1)) }
        else if c.surah > 1 { play(from: .init(surah: c.surah - 1, ayah: ayahCount(c.surah - 1))) }
    }

    private func finishedAyah() {
        playedThisAyah += 1
        if playedThisAyah < repeatEach {
            player.seek(to: .zero)
            player.playImmediately(atRate: speed)
        } else {
            next()
        }
    }
}
