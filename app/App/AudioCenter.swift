import SwiftUI
import AVFoundation
import MediaPlayer
import Observation
import AyatDesign

/// Something that plays audio through the app: recitations (mushaf, ruqya, kids' Juz Amma) and
/// the radio. Only one source plays at a time; AudioCenter pauses the others.
protocol AudioSource: AnyObject {
    var audioIsPlaying: Bool { get }
    var audioTitle: String { get }
    var audioSubtitle: String { get }
    /// Live streams have no next/previous and no position.
    var audioIsLive: Bool { get }
    func audioPause()
    func audioResume()
    func audioNext()
    func audioPrevious()
    func audioStop()
}

/// The app's single audio coordinator (master prompt §10): one active source, the mini player,
/// lock-screen and Control Center controls, headphones and Bluetooth, and interruptions such as
/// calls. Sources call `claim` when they start and `changed` when their state moves.
@Observable
final class AudioCenter {
    static let shared = AudioCenter()

    private(set) var active: AudioSource?
    /// Bumped on every change so views that read the active source refresh.
    private(set) var revision = 0
    /// A screen that shows its own full controls for the active source hides the mini player.
    var fullPlayerShown = false
    var nowPlayingSheet = false

    @ObservationIgnored private var resumeAfterInterruption = false
    @ObservationIgnored private var commandsReady = false

    private init() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            self?.interruption(n)
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in
            // Unplugging headphones or a Bluetooth device pauses, as Apple's apps do.
            guard let raw = n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            self?.active?.audioPause()
            self?.changed()
        }
    }

    /// Called by a source right before it starts: stops any other source and activates the session.
    func claim(_ source: AudioSource, spoken: Bool = true) {
        if let old = active, old !== source { old.audioStop() }
        active = source
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: spoken ? .spokenAudio : .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        setUpCommands()
        changed()
    }

    /// Called by a source when it stops for good (not when it pauses).
    func release(_ source: AudioSource) {
        guard active === source else { return }
        active = nil
        changed()
    }

    func changed() {
        revision &+= 1
        updateNowPlaying()
    }

    var isPlaying: Bool { active?.audioIsPlaying ?? false }

    func toggle() {
        guard let a = active else { return }
        if a.audioIsPlaying { a.audioPause() } else { a.audioResume() }
        changed()
    }

    func stop() {
        active?.audioStop()
        active = nil
        changed()
    }

    // MARK: Lock screen and Control Center

    private func setUpCommands() {
        guard !commandsReady else { return }
        commandsReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            guard let a = self?.active else { return .noActionableNowPlayingItem }
            a.audioResume(); self?.changed(); return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let a = self?.active else { return .noActionableNowPlayingItem }
            a.audioPause(); self?.changed(); return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard self?.active != nil else { return .noActionableNowPlayingItem }
            self?.toggle(); return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            guard let a = self?.active, !a.audioIsLive else { return .commandFailed }
            a.audioNext(); self?.changed(); return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            guard let a = self?.active, !a.audioIsLive else { return .commandFailed }
            a.audioPrevious(); self?.changed(); return .success
        }
    }

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let a = active else { center.nowPlayingInfo = nil; return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: a.audioTitle,
            MPMediaItemPropertyArtist: a.audioSubtitle,
            MPMediaItemPropertyAlbumTitle: "آيات تتلى",
            MPNowPlayingInfoPropertyPlaybackRate: a.audioIsPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: a.audioIsLive,
        ]
        if let image = UIImage(named: "LogoFull") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        center.nowPlayingInfo = info
        let c = MPRemoteCommandCenter.shared()
        c.nextTrackCommand.isEnabled = !a.audioIsLive
        c.previousTrackCommand.isEnabled = !a.audioIsLive
    }

    // MARK: Interruptions (calls, alarms, other apps)

    private func interruption(_ n: Notification) {
        guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw), let a = active else { return }
        switch type {
        case .began:
            resumeAfterInterruption = a.audioIsPlaying
            a.audioPause()
        case .ended:
            let opts = (n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init) ?? []
            if resumeAfterInterruption && opts.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
                a.audioResume()
            }
            resumeAfterInterruption = false
        @unknown default: break
        }
        changed()
    }
}

// MARK: - Mini player

/// Fixed mini player above the bottom bar on every section, as long as something is playing or
/// paused. Tapping it opens the full controls.
struct MiniPlayerBar: View {
    @State private var center = AudioCenter.shared

    var body: some View {
        let _ = center.revision
        if let a = center.active, !center.fullPlayerShown {
            HStack(spacing: 10) {
                Button { center.nowPlayingSheet = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: a.audioIsLive ? "antenna.radiowaves.left.and.right" : "waveform")
                            .font(.ui(.body)).foregroundStyle(Brand.onDeepAccent)
                            .frame(width: 36, height: 36)
                            .background(Brand.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.audioTitle).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.ink).lineLimit(1)
                            Text(a.audioSubtitle).font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("المشغل: \(a.audioTitle)، \(a.audioSubtitle)")
                .accessibilityHint("يفتح المشغل الكامل")
                Button { center.toggle() } label: {
                    Image(systemName: a.audioIsPlaying ? "pause.fill" : "play.fill")
                        .font(.ui(.body)).foregroundStyle(Brand.primaryInk)
                        .frame(width: Brand.minTap, height: Brand.minTap)
                }
                .accessibilityLabel(a.audioIsPlaying ? "إيقاف مؤقت" : "تشغيل")
                Button { center.stop() } label: {
                    Image(systemName: "xmark").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.muted)
                        .frame(width: Brand.minTap, height: Brand.minTap)
                }
                .accessibilityLabel("إغلاق المشغل")
            }
            .padding(.leading, 8).padding(.trailing, 4).padding(.vertical, 6)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            .padding(.horizontal, 12).padding(.bottom, 6)
            .frame(maxWidth: 640)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Full player sheet opened from the mini player.
struct NowPlayingSheet: View {
    @State private var center = AudioCenter.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = center.revision
        VStack(spacing: 22) {
            Capsule().fill(Brand.lineStrong).frame(width: 40, height: 5).padding(.top, 10)
            if let a = center.active {
                Image("LogoFull").resizable().scaledToFit().frame(width: 120, height: 120)
                    .padding(24)
                    .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text(a.audioTitle).font(.ui(.title2, .semibold)).foregroundStyle(Brand.ink).multilineTextAlignment(.center)
                    Text(a.audioSubtitle).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                }
                HStack(spacing: 28) {
                    if !a.audioIsLive {
                        Button { a.audioPrevious(); center.changed() } label: {
                            Image(systemName: "forward.end.fill").font(.ui(.title2)).frame(width: 56, height: 56)
                        }
                        .accessibilityLabel("الآية السابقة")
                    }
                    Button { center.toggle() } label: {
                        Image(systemName: a.audioIsPlaying ? "pause.fill" : "play.fill")
                            .font(.ui(.title)).foregroundStyle(Brand.onPrimary)
                            .frame(width: 76, height: 76).background(Brand.primary, in: Circle())
                    }
                    .accessibilityLabel(a.audioIsPlaying ? "إيقاف مؤقت" : "تشغيل")
                    if !a.audioIsLive {
                        Button { a.audioNext(); center.changed() } label: {
                            Image(systemName: "backward.end.fill").font(.ui(.title2)).frame(width: 56, height: 56)
                        }
                        .accessibilityLabel("الآية التالية")
                    }
                }
                .foregroundStyle(Brand.primaryInk)
                Button(role: .destructive) { center.stop(); dismiss() } label: {
                    Text("إيقاف التشغيل").font(.ui(.subheadline, .medium)).frame(minHeight: Brand.minTap)
                }
            } else {
                ContentUnavailableView("لا يوجد تشغيل", systemImage: "waveform")
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Brand.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
