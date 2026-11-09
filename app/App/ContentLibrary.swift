import Foundation
import CoreText
import AyatContent

/// The offline content pack bundled in the app (Content/content-v1.sqlite, built and verified on CI
/// from the approved sources). Opened once; nil when the pack is missing or fails its checks.
final class ContentLibrary: @unchecked Sendable {
    static let shared = ContentLibrary()

    let store: ContentStore?
    let version: String?
    let problem: String?
    let basmala: String?
    let surahs: [Surah]
    let pageCount: Int
    /// Chapters of Hisn al-Muslim, read once (screens used to query them on every redraw).
    let azkarCategories: [ZikrCategory]
    /// Tasbih phrases from the pack (meta "tasbih_phrases", a JSON list); empty until the source is added.
    let tasbihPhrases: [String]

    /// Family name of the bundled mushaf font; falls back to the system font if it is missing.
    static let mushafFont = "Amiri Quran"

    init(bundle: Bundle = .main) {
        Self.registerFonts(bundle)
        var store: ContentStore?
        var problem: String?
        if let url = bundle.url(forResource: "content-v1", withExtension: "sqlite", subdirectory: "Content") {
            do {
                // The pack sits in the signed app bundle, so it cannot change between launches of
                // the same build: hash it once per build instead of on every launch.
                let build = Self.buildStamp(bundle)
                if UserDefaults.standard.string(forKey: Self.verifiedKey) != build,
                   let shaURL = bundle.url(forResource: "content-v1.sqlite", withExtension: "sha256", subdirectory: "Content"),
                   let line = try? String(contentsOf: shaURL, encoding: .utf8),
                   let digest = line.split(separator: " ").first {
                    try ContentStore.verify(url: url, sha256: String(digest))
                    UserDefaults.standard.set(build, forKey: Self.verifiedKey)
                }
                let s = try ContentStore(url: url)
                try s.checkComplete()
                store = s
            } catch {
                problem = "\(error)"
            }
        } else {
            problem = "missing"
        }
        self.store = store
        self.problem = problem
        self.version = (try? store?.meta("content_version")) ?? nil
        self.basmala = (try? store?.basmala()) ?? nil
        self.surahs = (try? store?.surahs()) ?? []
        self.pageCount = (try? store?.pageCount()) ?? 0
        self.azkarCategories = (try? store?.azkarCategories()) ?? []
        let raw = ((try? store?.meta("tasbih_phrases")) ?? nil) ?? "[]"
        self.tasbihPhrases = (try? JSONDecoder().decode([String].self, from: Data(raw.utf8))) ?? []
    }

    var isReady: Bool { store != nil }

    /// Ayat of one mushaf page. Pages redraw often (the highlight moves with each verse during
    /// playback, font size, rotation), so recent pages are kept instead of queried every time.
    func page(_ n: Int) -> [Ayah] {
        let key = NSNumber(value: n)
        if let hit = pageCache.object(forKey: key) { return hit.ayat }
        let ayat = (try? store?.page(n)) ?? []
        if !ayat.isEmpty { pageCache.setObject(PageBox(ayat), forKey: key) }
        return ayat
    }

    private final class PageBox { let ayat: [Ayah]; init(_ a: [Ayah]) { ayat = a } }
    private let pageCache: NSCache<NSNumber, PageBox> = {
        let c = NSCache<NSNumber, PageBox>()
        c.countLimit = 40
        return c
    }()

    private static let verifiedKey = "content.verifiedBuild"

    /// Version, build and pack size: a new build or a different pack is hashed again.
    private static func buildStamp(_ bundle: Bundle) -> String {
        let v = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let size = (bundle.url(forResource: "content-v1", withExtension: "sqlite", subdirectory: "Content"))
            .flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } ?? 0
        return "\(v)-\(b)-\(size)"
    }

    func surah(_ id: Int) -> Surah? { surahs.indices.contains(id - 1) ? surahs[id - 1] : nil }

    private static func registerFonts(_ bundle: Bundle) {
        for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Content") ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
