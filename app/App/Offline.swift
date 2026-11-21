import SwiftUI
import Network
import Observation
import AyatDesign

/// Whether the device can reach the internet (NWPathMonitor). Debug builds accept `-offline 1`
/// to show the app as it is without internet (CI screenshots and checks).
@Observable
final class Net {
    static let shared = Net()

    private(set) var online = true
    private(set) var expensive = false
    var simulateOffline = false

    var isOnline: Bool { online && !simulateOffline }

    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        #if DEBUG
        simulateOffline = UserDefaults.standard.string(forKey: "offline") == "1"
        #endif
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.online = path.status == .satisfied
                self?.expensive = path.isExpensive || path.isConstrained
            }
        }
        monitor.start(queue: DispatchQueue(label: "net.monitor"))
    }

    /// Read from any thread (the site client checks it before a request).
    static var isOnline: Bool { shared.isOnline }
}

/// How much of a tool works without internet.
enum OfflineLevel: CaseIterable {
    case full, saved, online

    var label: String {
        switch self {
        case .full: "يعمل بدون إنترنت"
        case .saved: "يعمل بما حفظته"
        case .online: "يحتاج إنترنت"
        }
    }
    var hint: String {
        switch self {
        case .full: "كل ما في هذه الأداة محفوظ في التطبيق"
        case .saved: "يعمل بدون إنترنت بما حمّلته أو فتحته من قبل"
        case .online: "هذه الأداة تحتاج اتصالا بالإنترنت"
        }
    }
    var symbol: String {
        switch self {
        case .full: "checkmark.circle.fill"
        case .saved: "arrow.down.circle.fill"
        case .online: "icloud.slash"
        }
    }
    var color: Color {
        switch self {
        case .full: Brand.primaryInk
        case .saved: Brand.goldInk
        case .online: Brand.muted
        }
    }
}

enum OfflineTools {
    static let online: Set<String> = ["radio", "nearby-mosques"]
    static let saved: Set<String> = ["clip", "listen", "ruqya", "kids-juz-amma", "hadith", "hadith-card", "hadith-checker",
                                     "tajweed", "word-by-word", "asma-ul-husna", "crypto-zakat",
                                     // Speech recognition works offline where iOS supports Arabic on the device.
                                     "tasmee", "voice-search"]

    static func level(_ id: String) -> OfflineLevel {
        if online.contains(id) { return .online }
        if saved.contains(id) { return .saved }
        return .full
    }
}

extension SiteTool {
    var offlineLevel: OfflineLevel { OfflineTools.level(id) }
    /// Offline and this tool needs internet: its tile is dimmed with a «cloud off» mark.
    var dimmedOffline: Bool { !Net.isOnline && offlineLevel == .online }
}

/// «جهّز التطبيق للعمل بدون إنترنت»: keeps on the phone the hadith collection, the tajweed text and
/// word meanings of chosen surahs, and the curated backgrounds; recitations download separately.
/// Everything is the same data the tools use online, stored as it is.
@MainActor @Observable
final class OfflinePrep {
    static let shared = OfflinePrep()

    private(set) var running = false
    private(set) var stage = ""
    private(set) var progress = 0.0
    private(set) var lastResult: String?
    private(set) var version = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Juz Amma and the surahs most read on their own (Al-Fatiha, Al-Kahf, Ya-Sin, Ar-Rahman, Al-Waqi'a, Al-Mulk).
    static let essentialSurahs: [Int] = [1, 18, 36, 55, 56, 67] + Array(78...114)
    static let autoKey = "offline.auto"
    static let prepKey = "offline.prepAt"

    struct Status { var hadith = 0; var tajweed = 0; var words = 0; var images = 0; var recitations: Int64 = 0; var heard: Int64 = 0; var total: Int64 = 0 }

    nonisolated static var root: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Offline", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        var u = d; var v = URLResourceValues(); v.isExcludedFromBackup = true; try? u.setResourceValues(v)
        return d
    }

    func status() -> Status {
        var s = Status()
        let fm = FileManager.default
        let api = Self.root.appendingPathComponent("site-api")
        let hadithFiles = ((try? fm.contentsOfDirectory(atPath: api.path)) ?? []).filter { $0.hasPrefix("hadith") }
        var ids = Set<String>()
        for f in hadithFiles {
            if let d = try? Data(contentsOf: api.appendingPathComponent(f)), let p = try? JSONDecoder().decode(SiteAPI.HadithPage.self, from: d) {
                p.items.forEach { ids.insert($0.id) }
            }
        }
        s.hadith = ids.count
        let qf = ((try? fm.contentsOfDirectory(atPath: Self.root.appendingPathComponent("qf").path)) ?? [])
        s.tajweed = qf.filter { $0.hasPrefix("tj-") }.count
        s.words = Set(qf.filter { $0.hasPrefix("wbw-") }.compactMap { $0.split(separator: "-").dropFirst().first }).count
        s.images = ((try? fm.contentsOfDirectory(atPath: MediaCache.directory.path)) ?? []).filter { $0.contains("raw-") }.count
        let dl = RecitationDownloads.shared
        s.recitations = Self.size(dl.root)
        s.heard = Self.size(dl.heardRoot)
        s.total = Self.size(Self.root) + Self.size(MediaCache.directory) + s.heard
        return s
    }

    nonisolated static func size(_ dir: URL) -> Int64 {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var t: Int64 = 0
        for case let f as URL in e { t += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return t
    }

    func start(surahs: [Int] = OfflinePrep.essentialSurahs) {
        guard !running else { return }
        running = true; lastResult = nil; progress = 0
        task = Task { [weak self] in
            guard let self else { return }
            var failures = 0
            defer { self.running = false; self.stage = ""; self.version += 1 }
            // 1. Hadith: every page of every category.
            self.stage = "الأحاديث الصحيحة والحسنة"
            if let first = try? await SiteAPI.hadith(cat: "", page: 1, query: "") {
                let pages = first.cats.flatMap { c in (1...max((c.count + 11) / 12, 1)).map { (c.name, $0) } }
                for (i, (cat, p)) in pages.enumerated() {
                    if Task.isCancelled { self.lastResult = "أوقفت التجهيز. ما حُفظ يبقى على جهازك."; return }
                    self.progress = Double(i) / Double(max(pages.count, 1)) / 3
                    if (try? await SiteAPI.hadith(cat: cat, page: p, query: "", preferNetwork: false)) == nil { failures += 1 }
                    if i % 10 == 0 { self.version += 1 }
                }
            } else { failures += 1 }
            // 2. Tajweed and word meanings.
            self.stage = "التجويد ومعاني الكلمات"
            for (i, s) in surahs.enumerated() {
                if Task.isCancelled { self.lastResult = "أوقفت التجهيز. ما حُفظ يبقى على جهازك."; return }
                self.progress = 1.0 / 3 + Double(i) / Double(surahs.count) / 3
                if (try? await QF.tajweed(chapter: s)) == nil { failures += 1 }
                if (try? await QF.words(chapter: s, lang: "en")) == nil { failures += 1 }
                self.version += 1
            }
            // 3. Curated backgrounds.
            self.stage = "الخلفيات المختارة"
            let cats = ["mosques", "nature", "night", "sky", "sea"]
            for (i, c) in cats.enumerated() {
                if Task.isCancelled { self.lastResult = "أوقفت التجهيز. ما حُفظ يبقى على جهازك."; return }
                self.progress = 2.0 / 3 + Double(i) / Double(cats.count) / 3
                let items = ((try? await MediaLibrary.search(.image, category: c)) ?? []).filter(\.curated).prefix(10)
                for it in items { if (try? await MediaLibrary.image(it)) == nil { failures += 1 } }
                self.version += 1
            }
            self.progress = 1
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.prepKey)
            self.lastResult = failures == 0 ? "اكتمل التجهيز. الأدوات تعمل الآن بدون إنترنت."
                : "اكتمل التجهيز إلا بعض الملفات. أعد المحاولة عند اتصال أفضل لإكمالها."
        }
    }

    /// Downloads the recitation of `surahs` (Juz Amma by default) with the reciter folder.
    func downloadRecitations(folder: String, reciterName: String, surahs: [Int] = Array(78...114), label: String = "جزء عم") {
        guard !running else { return }
        running = true; lastResult = nil; progress = 0
        let lib = ContentLibrary.shared
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.running = false; self.stage = ""; self.version += 1 }
            var failures = 0
            for (i, id) in surahs.enumerated() {
                if Task.isCancelled { self.lastResult = "أوقفت التحميل. ما حُمّل يبقى على جهازك."; return }
                let count = lib.surah(id)?.ayahCount ?? 0
                self.stage = "تلاوة \(label) · سورة \(lib.surah(id)?.shortName ?? "")"
                self.progress = Double(i) / Double(surahs.count)
                await RecitationDownloads.shared.download(folder: folder, surah: id, ayahCount: count)
                if !RecitationDownloads.shared.isDownloaded(folder: folder, surah: id, ayahCount: count) { failures += 1 }
            }
            self.progress = 1
            self.lastResult = failures == 0 ? "حُمّلت تلاوة \(label) بصوت \(reciterName). تسمعها الآن بدون إنترنت."
                : "حُمّلت أغلب السور. أعد المحاولة عند اتصال أفضل لإكمال \(Num.int(failures)) سورة."
        }
    }

    func cancel() { task?.cancel() }

    /// About 60 KB an ayah at 64 kbps.
    static func estimateMB(_ surahs: [Int]) -> Int {
        max(surahs.reduce(0) { $0 + (ContentLibrary.shared.surah($1)?.ayahCount ?? 0) } * 60 / 1024, 1)
    }

    /// Once a week, on Wi-Fi, in release builds: the saved files are refreshed quietly.
    func maybeAuto() {
        #if DEBUG
        return
        #else
        let d = UserDefaults.standard
        guard Net.shared.isOnline, !Net.shared.expensive, d.object(forKey: Self.autoKey) as? Bool ?? true else { return }
        guard Date().timeIntervalSince1970 - d.double(forKey: Self.prepKey) > 7 * 86_400 else { return }
        start()
        #endif
    }

    /// Removes the saved hadith, tajweed, meanings, backgrounds and listened recitations (not downloaded surahs).
    func clearSaved() {
        let fm = FileManager.default
        try? fm.removeItem(at: Self.root)
        try? fm.removeItem(at: MediaCache.directory)
        try? fm.removeItem(at: RecitationDownloads.shared.heardRoot)
        UserDefaults.standard.removeObject(forKey: Self.prepKey)
        version += 1
    }
}
