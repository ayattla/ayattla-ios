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
                if let shaURL = bundle.url(forResource: "content-v1.sqlite", withExtension: "sha256", subdirectory: "Content"),
                   let line = try? String(contentsOf: shaURL, encoding: .utf8),
                   let digest = line.split(separator: " ").first {
                    try ContentStore.verify(url: url, sha256: String(digest))
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
        let raw = ((try? store?.meta("tasbih_phrases")) ?? nil) ?? "[]"
        self.tasbihPhrases = (try? JSONDecoder().decode([String].self, from: Data(raw.utf8))) ?? []
    }

    var isReady: Bool { store != nil }

    func surah(_ id: Int) -> Surah? { surahs.indices.contains(id - 1) ? surahs[id - 1] : nil }

    private static func registerFonts(_ bundle: Bundle) {
        for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Content") ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
