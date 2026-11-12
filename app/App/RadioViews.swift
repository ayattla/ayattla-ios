import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Radio (/tools/radio)

/// Live radio from the site's list (mp3quran.net). One shared player, so a station keeps playing
/// after leaving the screen and shows in the mini player.
@Observable
final class RadioPlayer {
    static let shared = RadioPlayer()

    /// The station loaded (playing or paused); nil when stopped.
    private(set) var playing: SiteAPI.Radio?
    private(set) var isPlaying = false
    private(set) var failed = false
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var stallObserver: NSObjectProtocol?

    func toggle(_ r: SiteAPI.Radio) {
        if playing == r { if isPlaying { pause() } else { resume() }; return }
        guard let url = URL(string: r.url) else { return }
        AudioCenter.shared.claim(self, spoken: false)
        failed = false
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status) { [weak self] item, _ in
            if item.status == .failed { DispatchQueue.main.async { self?.connectionLost() } }
        }
        if let stallObserver { NotificationCenter.default.removeObserver(stallObserver) }
        stallObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification,
                                                               object: item, queue: .main) { [weak self] _ in self?.connectionLost() }
        player.replaceCurrentItem(with: item)
        player.play()
        playing = r
        isPlaying = true
        AudioCenter.shared.changed()
    }

    func pause() { player.pause(); isPlaying = false; AudioCenter.shared.changed() }

    /// A live stream resumes at the live edge: reload the station rather than continue a stale buffer.
    func resume() {
        guard let r = playing else { return }
        playing = nil
        toggle(r)
    }

    func stop() {
        halt()
        AudioCenter.shared.release(self)
    }

    private func halt() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playing = nil
        isPlaying = false
    }

    private func connectionLost() {
        failed = true
        isPlaying = false
        AudioCenter.shared.changed()
    }
}

extension RadioPlayer: AudioSource {
    var audioIsPlaying: Bool { isPlaying }
    var audioTitle: String { playing?.name ?? "إذاعات القرآن" }
    var audioSubtitle: String { failed ? "انقطع الاتصال، اضغط للمحاولة" : "بث مباشر · إذاعات القرآن" }
    var audioIsLive: Bool { true }
    func audioPause() { pause() }
    func audioResume() { resume() }
    func audioNext() {}
    func audioPrevious() {}
    func audioStop() { halt() }
}

struct RadioView: View {
    @State private var radios: [SiteAPI.Radio] = []
    @State private var query = ""
    @State private var failed = false
    @State private var player = RadioPlayer.shared

    var body: some View {
        List {
            ToolHeadSection(id: "radio")
            ForEach(filtered) { r in
Group {
            Button { player.toggle(r) } label: {
                HStack {
                    Image(systemName: player.playing == r && player.isPlaying ? "pause.circle.fill" : "play.circle")
                        .font(.ui(.title2)).foregroundStyle(Brand.primary)
                    Text(r.name).foregroundStyle(.primary)
                    Spacer()
                    if player.playing == r {
                        if player.failed {
                            Text("انقطع الاتصال").font(.ui(.caption)).foregroundStyle(.red)
                        } else if player.isPlaying {
                            Image(systemName: "waveform").foregroundStyle(Brand.primaryInk)
                        }
                    }
                }
                .frame(minHeight: Brand.minTap)
            }
            .accessibilityLabel(player.playing == r && player.isPlaying ? "إيقاف \(r.name)" : "تشغيل \(r.name)")
        
}.listRowBackground(Brand.surface)
            }
}
        .overlay {
            if failed && radios.isEmpty {
                ContentUnavailableView("تعذر تحميل الإذاعات", systemImage: "antenna.radiowaves.left.and.right.slash",
                                       description: Text("تحقق من الاتصال ثم حاول مرة أخرى"))
            } else if radios.isEmpty {
                ProgressView()
            }
        }
        .brandScreen()
        .navigationTitle("الإذاعات")
        .searchable(text: $query, prompt: "ابحث في الإذاعات")
        .task {
            do { radios = try await SiteAPI.radios() } catch { failed = true }
        }
    }

    private var filtered: [SiteAPI.Radio] {
        let q = ContentStore.clean(query.trimmingCharacters(in: .whitespaces))
        return q.isEmpty ? radios : radios.filter { ContentStore.clean($0.name).localizedStandardContains(q) }
    }
}
