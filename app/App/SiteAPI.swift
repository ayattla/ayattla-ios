import Foundation

/// Read-only client for ayattla.com's public JSON endpoints (the same ones the site's pages use).
/// Responses are cached on disk so the last result shows when the device is offline.
enum SiteAPI {
    static let base = URL(string: "https://ayattla.com")!

    struct Hadith: Codable, Identifiable, Hashable {
        let id: String
        let title: String?
        let text: String
        let source: String
        let grade: String
        let cat: String?
        let url: String
        let match: Int?

        enum CodingKeys: String, CodingKey { case id, title, text, source, grade, cat, url, match }

        init(id: String, title: String?, text: String, source: String, grade: String, cat: String?, url: String, match: Int?) {
            self.id = id; self.title = title; self.text = text; self.source = source
            self.grade = grade; self.cat = cat; self.url = url; self.match = match
        }

        /// The site sends ids as strings; numbers are accepted too.
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            if let s = try? c.decode(String.self, forKey: .id) { id = s } else { id = String(try c.decode(Int.self, forKey: .id)) }
            title = try c.decodeIfPresent(String.self, forKey: .title)
            text = try c.decode(String.self, forKey: .text)
            source = (try? c.decode(String.self, forKey: .source)) ?? ""
            grade = (try? c.decode(String.self, forKey: .grade)) ?? ""
            cat = try? c.decode(String.self, forKey: .cat)
            url = (try? c.decode(String.self, forKey: .url)) ?? ""
            match = (try? c.decode(Int.self, forKey: .match)) ?? (try? c.decode(Double.self, forKey: .match)).map { Int($0) }
        }
    }

    struct HadithPage: Codable {
        struct Cat: Codable, Hashable { let name: String; let count: Int }
        let cats: [Cat]
        let total: Int
        let page: Int
        let items: [Hadith]
    }

    struct HadithCheck: Codable {
        let query_words: Int?
        let items: [Hadith]
    }

    struct Radio: Codable, Identifiable, Hashable {
        let name: String
        let url: String
        var id: String { url }
    }

    struct Radios: Codable { let radios: [Radio] }

    /// GET /api/hadith/browse?cat=&page=&q=  (12 per page, as on /tools/hadith)
    static func hadith(cat: String, page: Int, query: String) async throws -> HadithPage {
        var c = URLComponents(url: base.appendingPathComponent("api/hadith/browse"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "cat", value: cat), .init(name: "page", value: String(page)), .init(name: "q", value: query)]
        return try await get(c.url!, cacheKey: "hadith-\(cat)-\(page)-\(query)")
    }

    /// POST /api/hadith/check {"text": ...}  (as on /tools/hadith-checker)
    static func checkHadith(_ text: String) async throws -> HadithCheck {
        var r = URLRequest(url: base.appendingPathComponent("api/hadith/check"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONEncoder().encode(["text": text])
        r.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(HadithCheck.self, from: data)
    }

    /// GET /api/radios (mp3quran.net streams, as on /tools/radio)
    static func radios() async throws -> [Radio] {
        try await (get(base.appendingPathComponent("api/radios"), cacheKey: "radios") as Radios).radios
    }

    private static func get<T: Decodable>(_ url: URL, cacheKey: String) async throws -> T {
        let file = cacheDir.appendingPathComponent(cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "x")
        do {
            var r = URLRequest(url: url)
            r.timeoutInterval = 20
            let (data, resp) = try await URLSession.shared.data(for: r)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let value = try JSONDecoder().decode(T.self, from: data)
            try? data.write(to: file)
            return value
        } catch {
            if let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(T.self, from: data) { return value }
            throw error
        }
    }

    private static let cacheDir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("site-api", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
}
