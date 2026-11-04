import Foundation
import AVFoundation
import Observation
import AyatDesign

/// Ayah-by-ayah recitation from EveryAyah, as on the site's listen tool (repeat each ayah 1/3/5,
/// speed). Plays a downloaded copy when there is one (RecitationDownloads). Goes through
/// AudioCenter, so it keeps playing in the background and from the mini player.
@Observable
final class RecitationPlayer {
    struct Position: Equatable, Hashable { var surah: Int; var ayah: Int }

    /// Times each ayah plays; 0 repeats it until the listener moves on (as the site's "∞").
    static let repeats = [1, 3, 5, 10, 0]
    static func repeatTitle(_ n: Int) -> String {
        switch n {
        case 0: "بلا حد"
        case 1: "مرة واحدة"
        default: "\(Num.int(n)) مرات"
        }
    }
    static let speeds: [Float] = [0.75, 1.0, 1.25, 1.5]

    private(set) var current: Position?
    private(set) var isPlaying = false
    private(set) var failed = false
    /// Stop after this ayah (e.g. the end of a ruqya passage).
    @ObservationIgnored var stopAt: Position?
    var repeatEach = 1
    /// Stop after the last ayah of the surah instead of moving on (kids' Juz Amma, as on the site).
    var stopsAtSurahEnd = false
    var speed: Float = 1.0 { didSet { if isPlaying { player.rate = speed } } }
    /// Where the current ayah is (seconds), for the progress bar; updated four times a second.
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    /// How many times the current ayah has played (for «٢ من ٣»).
    var playCount: Int { playedThisAyah + 1 }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var playedThisAyah = 0
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored var folder: String?
    @ObservationIgnored var ayahCount: (Int) -> Int = { _ in 0 }

    init() {
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
                                                             object: nil, queue: .main) { [weak self] note in
            guard let self, (note.object as? AVPlayerItem) === self.player.currentItem else { return }
            self.finishedAyah()
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] t in
            guard let self else { return }
            let d = self.player.currentItem?.duration.seconds ?? 0
            self.duration = d.isFinite ? d : 0
            self.elapsed = t.seconds.isFinite ? t.seconds : 0
        }
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    /// https://everyayah.com/data/<folder>/SSSAAA.mp3
    static func url(folder: String, surah: Int, ayah: Int) -> URL? {
        URL(string: String(format: "https://everyayah.com/data/%@/%03d%03d.mp3", folder, surah, ayah))
    }

    func play(from p: Position) {
        guard let folder, let url = Self.url(folder: folder, surah: p.surah, ayah: p.ayah) else { failed = true; return }
        AudioCenter.shared.claim(self)
        failed = false
        current = p
        playedThisAyah = 0
        elapsed = 0; duration = 0
        // A downloaded copy (Library → التنزيلات) plays without internet.
        let item = AVPlayerItem(url: RecitationDownloads.shared.local(folder: folder, surah: p.surah, ayah: p.ayah) ?? url)
        statusObserver = item.observe(\.status) { [weak self] item, _ in
            if item.status == .failed {
                DispatchQueue.main.async { self?.failed = true; self?.isPlaying = false; AudioCenter.shared.changed() }
            }
        }
        player.replaceCurrentItem(with: item)
        player.playImmediately(atRate: speed)
        isPlaying = true
        AudioCenter.shared.changed()
    }

    func toggle(startAt p: Position) {
        if isPlaying {
            pause()
        } else if current != nil, player.currentItem != nil, !failed {
            resume()
        } else {
            play(from: p)
        }
    }

    /// Moves within the current ayah (0…1), from the progress bar.
    func seek(fraction: Double) {
        guard duration > 0 else { return }
        let t = CMTime(seconds: duration * min(max(fraction, 0), 1), preferredTimescale: 600)
        elapsed = t.seconds
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func pause() {
        player.pause()
        isPlaying = false
        AudioCenter.shared.changed()
    }

    func resume() {
        guard current != nil, player.currentItem != nil else { return }
        AudioCenter.shared.claim(self)
        player.playImmediately(atRate: speed)
        isPlaying = true
        AudioCenter.shared.changed()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        current = nil
        AudioCenter.shared.release(self)
    }

    /// Reciter name for the lock screen, from the folder (content pack reciter table).
    var reciterName: String {
        guard let folder else { return "" }
        let id = ((try? ContentLibrary.shared.store?.reciterFolders()) ?? [:]).first { $0.value == folder }?.key
        return id.flatMap { Catalog.reciter($0)?.name } ?? ""
    }

    func next() {
        guard let c = current else { return }
        if c == stopAt { stop(); return }
        if c.ayah < ayahCount(c.surah) { play(from: .init(surah: c.surah, ayah: c.ayah + 1)) }
        else if stopsAtSurahEnd { stop() }
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
        if repeatEach == 0 || playedThisAyah < repeatEach {
            player.seek(to: .zero)
            player.playImmediately(atRate: speed)
        } else {
            next()
        }
    }
}

extension RecitationPlayer: AudioSource {
    var audioIsPlaying: Bool { isPlaying }
    var audioTitle: String { current.map(QuranText.reference) ?? "تلاوة" }
    var audioSubtitle: String { reciterName }
    var audioIsLive: Bool { false }
    func audioPause() { pause() }
    func audioResume() { resume() }
    func audioNext() { next() }
    func audioPrevious() { previous() }
    func audioStop() {
        // Called when another source takes over: stop without releasing twice.
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        current = nil
    }
}
