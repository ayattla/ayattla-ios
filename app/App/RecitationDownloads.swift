import SwiftUI
import Observation
import AyatDesign

/// Recitations saved on the device for listening without internet (owner decision 2026-11-03:
/// same features as the site). Ayah files from EveryAyah in Application Support/Recitations/<folder>/.
@Observable
final class RecitationDownloads {
    static let shared = RecitationDownloads()

    struct Job: Equatable { let folder: String; let surah: Int; var progress: Double }

    private(set) var active: Job?
    private(set) var failed: String?
    let root: URL

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recitations", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        var url = self.root
        var v = URLResourceValues(); v.isExcludedFromBackup = true
        try? url.setResourceValues(v)
    }

    func file(folder: String, surah: Int, ayah: Int) -> URL {
        root.appendingPathComponent(folder, isDirectory: true).appendingPathComponent(String(format: "%03d%03d.mp3", surah, ayah))
    }

    /// Local file if this ayah has been downloaded.
    func local(folder: String, surah: Int, ayah: Int) -> URL? {
        let f = file(folder: folder, surah: surah, ayah: ayah)
        return FileManager.default.fileExists(atPath: f.path) ? f : nil
    }

    func isDownloaded(folder: String, surah: Int, ayahCount: Int) -> Bool {
        ayahCount > 0 && (1...ayahCount).allSatisfy { local(folder: folder, surah: surah, ayah: $0) != nil }
    }

    /// Downloaded surahs per reciter folder: [folder: [surah]].
    func inventory(ayahCounts: (Int) -> Int) -> [String: [Int]] {
        var out: [String: [Int]] = [:]
        for f in (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [] {
            let surahs = (1...114).filter { isDownloaded(folder: f, surah: $0, ayahCount: ayahCounts($0)) }
            if !surahs.isEmpty { out[f] = surahs }
        }
        return out
    }

    func size(folder: String) -> Int64 {
        let d = root.appendingPathComponent(folder)
        let files = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    @MainActor
    func download(folder: String, surah: Int, ayahCount: Int) async {
        guard active == nil else { return }
        failed = nil
        active = Job(folder: folder, surah: surah, progress: 0)
        defer { active = nil }
        let dir = root.appendingPathComponent(folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for a in 1...max(ayahCount, 1) {
            if Task.isCancelled { return }
            if local(folder: folder, surah: surah, ayah: a) != nil { active?.progress = Double(a) / Double(ayahCount); continue }
            guard let url = RecitationPlayer.url(folder: folder, surah: surah, ayah: a) else { continue }
            do {
                let (tmp, resp) = try await URLSession.shared.download(from: url)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                try? FileManager.default.removeItem(at: file(folder: folder, surah: surah, ayah: a))
                try FileManager.default.moveItem(at: tmp, to: file(folder: folder, surah: surah, ayah: a))
            } catch {
                failed = "تعذر تنزيل الآية \(Num.int(a))، تحقق من الاتصال"
                return
            }
            active?.progress = Double(a) / Double(ayahCount)
        }
    }

    func delete(folder: String, surah: Int, ayahCount: Int) {
        for a in 1...max(ayahCount, 1) { try? FileManager.default.removeItem(at: file(folder: folder, surah: surah, ayah: a)) }
    }
}

/// Library → التنزيلات: download a surah for the chosen reciter, list and delete downloads.
struct DownloadsView: View {
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var surah = 1
    @State private var refresh = 0
    private var dl = RecitationDownloads.shared
    private let lib = ContentLibrary.shared

    var body: some View {
        let folders = (try? lib.store?.reciterFolders()) ?? [:]
        let inv = dl.inventory { lib.surah($0)?.ayahCount ?? 0 }
        List {
            Section {
                Picker("القارئ", selection: $reciter) { ForEach(Catalog.reciters) { Text($0.name).tag($0.id) } }
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                if let job = dl.active {
                    ProgressView(value: job.progress) { Text("جار تنزيل \(lib.surah(job.surah)?.shortName ?? "")") }
                        .tint(Brand.primary)
                } else if let folder = folders[reciter] {
                    let count = lib.surah(surah)?.ayahCount ?? 0
                    if dl.isDownloaded(folder: folder, surah: surah, ayahCount: count) {
                        Label("محفوظة على الجهاز", systemImage: "checkmark.circle.fill").foregroundStyle(Brand.primaryInk)
                    } else {
                        Button {
                            Task { await dl.download(folder: folder, surah: surah, ayahCount: count); refresh += 1 }
                        } label: { Label("تنزيل للاستماع دون إنترنت", systemImage: "arrow.down.circle") }
                    }
                }
                if let f = dl.failed { Text(f).font(.footnote).foregroundStyle(.red) }
            } header: { Text("تنزيل سورة") } footer: {
                Text("التلاوة من EveryAyah آية آية، وتستخدم في المصحف وصانع المقاطع دون اتصال.")
            }
            ForEach(Catalog.reciters.filter { folders[$0.id].map { inv[$0] != nil } ?? false }) { r in
                let folder = folders[r.id]!
                Section("\(r.name) · \(ByteCountFormatter.string(fromByteCount: dl.size(folder: folder), countStyle: .file))") {
                    ForEach(inv[folder] ?? [], id: \.self) { s in
                        Text("\(Num.int(s)). \(lib.surah(s)?.shortName ?? "")")
                            .swipeActions {
                                Button("حذف", role: .destructive) {
                                    dl.delete(folder: folder, surah: s, ayahCount: lib.surah(s)?.ayahCount ?? 0); refresh += 1
                                }
                            }
                    }
                }
            }
        }
        .id(refresh)
    }
}
