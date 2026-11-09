import SwiftUI
import AyatDesign

/// Quran.com (Quran Foundation) data used the same way as on ayattla.com: tajweed text and word
/// meanings through the site's own endpoints (/api/qf/tajweed/{chapter}, /api/qf/words/{chapter}),
/// and word timings for highlighting from api.quran.com. Cached on the device for at most 6 days,
/// as Quran Foundation's terms require (docs/CONTENT_AND_LICENSES.md).
enum QF {
    static let maxAge: TimeInterval = 6 * 86_400

    struct TajweedChapter: Codable {
        struct Verse: Codable, Hashable { let key: String; let html: String }
        let chapter: Int
        let verses: [Verse]
    }

    struct WordsChapter: Codable {
        struct Word: Codable, Hashable { let t: String; let m: String }
        struct Verse: Codable, Hashable { let key: String; let n: Int; let words: [Word]; let tafsir: String? }
        let chapter: Int
        let lang: String?
        let verses: [Verse]
        let pagination: Pagination?
        struct Pagination: Codable { let next_page: Int? }
    }

    struct Recitation: Codable {
        struct AudioFile: Codable {
            struct Stamp: Codable {
                let verse_key: String
                let timestamp_from: Int
                let timestamp_to: Int
                let segments: [[Double]]
            }
            let audio_url: String
            let timestamps: [Stamp]
        }
        let audio_file: AudioFile
    }

    /// Word-meaning languages offered on /tools/word-by-word.
    static let wordLanguages: [(String, String)] = [("en", "English"), ("ur", "اردو"), ("id", "Indonesia"), ("tr", "Türkçe"),
                                                    ("bn", "বাংলা"), ("fr", "Français")]

    static func tajweed(chapter: Int) async throws -> TajweedChapter {
        try await get(SiteAPI.base.appendingPathComponent("api/qf/tajweed/\(chapter)"), key: "tj-\(chapter)")
    }

    /// All pages of a chapter's word meanings (50 verses per page on the site's endpoint).
    static func words(chapter: Int, lang: String) async throws -> WordsChapter {
        var verses: [WordsChapter.Verse] = []
        var page: Int? = 1
        while let p = page {
            var c = URLComponents(url: SiteAPI.base.appendingPathComponent("api/qf/words/\(chapter)"), resolvingAgainstBaseURL: false)!
            c.queryItems = [.init(name: "lang", value: lang), .init(name: "page", value: String(p))]
            let r: WordsChapter = try await get(c.url!, key: "wbw-\(chapter)-\(lang)-\(p)")
            verses += r.verses
            page = r.pagination?.next_page
            if verses.count > 300 { break }
        }
        return WordsChapter(chapter: chapter, lang: lang, verses: verses, pagination: nil)
    }

    /// Chapter audio and word timings for a Quran.com chapter recitation.
    static func recitation(_ id: Int, chapter: Int) async throws -> Recitation {
        try await get(URL(string: "https://api.quran.com/api/v4/chapter_recitations/\(id)/\(chapter)?segments=true")!,
                      key: "rec-\(id)-\(chapter)")
    }

    private static let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("qf", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private static func get<T: Decodable>(_ url: URL, key: String) async throws -> T {
        let file = dir.appendingPathComponent(key)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
           let date = attrs[.modificationDate] as? Date, Date().timeIntervalSince(date) < maxAge,
           let data = try? Data(contentsOf: file), let v = try? JSONDecoder().decode(T.self, from: data) {
            return v
        }
        var r = URLRequest(url: url)
        r.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let v = try JSONDecoder().decode(T.self, from: data)
        try? data.write(to: file, options: .atomic)
        return v
    }

    /// Removes cached Quran.com data older than 6 days (called at launch).
    static func purgeOld() {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            if let d = try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               Date().timeIntervalSince(d) > maxAge { try? fm.removeItem(at: f) }
        }
    }
}

/// Tajweed colors from the site's tokens (--tj-*), light and dark.
enum Tajweed {
    static let rules: [(String, String)] = [
        ("ham_wasl", "همزة الوصل"), ("laam_shamsiyah", "اللام الشمسية"), ("slnt", "حرف لا ينطق"),
        ("madda_normal", "مد طبيعي (حركتان)"), ("madda_permissible", "مد جائز (٢ أو ٤ أو ٦)"),
        ("madda_obligatory", "مد واجب (٤ أو ٥)"), ("madda_necessary", "مد لازم (٦ حركات)"), ("qalaqah", "قلقلة"),
        ("ghunnah", "غنة"), ("ikhafa", "إخفاء"), ("ikhafa_shafawi", "إخفاء شفوي"), ("iqlab", "إقلاب"),
        ("idgham_ghunnah", "إدغام بغنة"), ("idgham_wo_ghunnah", "إدغام بلا غنة"), ("idgham_shafawi", "إدغام شفوي"),
        ("idgham_mutajanisayn", "إدغام متجانسين"), ("idgham_mutaqaribayn", "إدغام متقاربين"),
    ]

    /// rule → (light, dark) from the site's --tj-* variables.
    static let palette: [String: (UInt32, UInt32)] = [
        "ham_wasl": (0x9A9A9A, 0x8E948F), "laam_shamsiyah": (0x9A9A9A, 0x8E948F), "slnt": (0x9A9A9A, 0x8E948F),
        "madda_normal": (0x3B6FE0, 0x7EA2FF), "madda_permissible": (0x2F45D8, 0x8C97FF),
        "madda_obligatory": (0x1F3AAE, 0xA6B4FF), "madda_necessary": (0x0A1E8C, 0xC2C9FF),
        "qalaqah": (0xC8102E, 0xFF6B7A), "ghunnah": (0xE8701A, 0xFFA35C), "ikhafa": (0x8A1FA0, 0xD58BE6),
        "ikhafa_shafawi": (0xC21AA8, 0xF07BDC), "iqlab": (0x1E9FD6, 0x6FD0FF),
        "idgham_ghunnah": (0x137A60, 0x5CD4B2), "idgham_wo_ghunnah": (0x1C8A1C, 0x7BDB7B),
        "idgham_shafawi": (0x137A60, 0x5CD4B2), "idgham_mutajanisayn": (0x4E9F00, 0xA6E05C),
        "idgham_mutaqaribayn": (0x8C8C8C, 0xB4B4B4),
    ]

    static func color(_ rule: String) -> Color? {
        palette[rule].map { Color(light: $0.0, dark: $0.1) }
    }

    /// Parses the site's tajweed HTML (`<span class="tj-rule">…</span>`, `tj-end` for the ayah number)
    /// into colored text. Text inside the tags is kept exactly. Works on UTF-16 (NSString), because a
    /// tag's ">" followed by a combining mark is one Character and would not match as text.
    static let tag = try! NSRegularExpression(pattern: "<span class=\"tj-([a-z_]+)\">(.*?)</span>", options: [.dotMatchesLineSeparators])

    static func attributed(_ html: String) -> AttributedString {
        let ns = html as NSString
        var out = AttributedString()
        var pos = 0
        for m in tag.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > pos {
                out += AttributedString(unescape(ns.substring(with: NSRange(location: pos, length: m.range.location - pos))))
            }
            let rule = ns.substring(with: m.range(at: 1))
            let inner = unescape(ns.substring(with: m.range(at: 2)))
            if rule == "end" {
                out += AttributedString("\u{06DD}" + inner)
            } else {
                var part = AttributedString(inner)
                if let c = color(rule) { part.foregroundColor = c }
                out += part
            }
            pos = m.range.location + m.range.length
        }
        if pos < ns.length { out += AttributedString(unescape(ns.substring(from: pos))) }
        return out
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
    }
}
