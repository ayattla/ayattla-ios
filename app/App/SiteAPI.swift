import Foundation
import AyatContent

/// Read-only client for ayattla.com's public JSON endpoints (the same ones the site's pages use).
/// Responses are saved on the phone so tools keep working without internet.
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
        /// Built from the hadith saved on the phone (no connection).
        var offline: Bool? = nil
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

    /// GET /api/hadith/browse?cat=&page=&q=  (12 per page, as on /tools/hadith). Offline: the saved collection.
    static func hadith(cat: String, page: Int, query: String, preferNetwork: Bool = true) async throws -> HadithPage {
        var c = URLComponents(url: base.appendingPathComponent("api/hadith/browse"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "cat", value: cat), .init(name: "page", value: String(page)), .init(name: "q", value: query)]
        do {
            return try await get(c.url!, cacheKey: "hadith-\(cat)-\(page)-\(query)", maxAge: preferNetwork ? 6 * 3600 : .infinity)
        } catch {
            if let saved = savedHadith(cat: cat, page: page, query: query) { return saved }
            throw error
        }
    }

    /// Every hadith saved on the phone (from pages opened or prepared), without repeats.
    static func savedCollection() -> (cats: [HadithPage.Cat], items: [Hadith]) {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: cacheDir.path)) ?? []).filter { $0.hasPrefix("hadith") }.sorted()
        var seen = Set<String>(); var items: [Hadith] = []; var cats: [HadithPage.Cat] = []
        for f in files {
            guard let d = try? Data(contentsOf: cacheDir.appendingPathComponent(f)), let p = try? JSONDecoder().decode(HadithPage.self, from: d) else { continue }
            if p.cats.count > cats.count { cats = p.cats }
            for h in p.items where seen.insert(h.id + h.url).inserted { items.append(h) }
        }
        return (cats, items)
    }

    /// A page of the saved collection, filtered as the site does (category, words of the search).
    static func savedHadith(cat: String, page: Int, query: String) -> HadithPage? {
        let (cats, all) = savedCollection()
        guard !all.isEmpty else { return nil }
        let words = ContentStore.clean(query).split(separator: " ").map(String.init).filter { $0.count > 1 }
        let list = all.filter { h in
            (cat.isEmpty || h.cat == cat) && (words.isEmpty || { let t = ContentStore.clean(h.text + " " + (h.title ?? "")); return words.allSatisfy { t.contains($0) } }())
        }
        let savedCats = cats.map { c in HadithPage.Cat(name: c.name, count: all.filter { $0.cat == c.name }.count) }.filter { $0.count > 0 }
        return HadithPage(cats: savedCats, total: list.count, page: page, items: Array(list.dropFirst((page - 1) * 12).prefix(12)), offline: true)
    }

    /// Offline check: the saved hadith whose words best match the pasted text (match = share of words found).
    static func checkHadithSaved(_ text: String) -> [Hadith] {
        let q = Set(ContentStore.clean(text).split(separator: " ").map(String.init).filter { $0.count > 2 })
        guard !q.isEmpty else { return [] }
        return savedCollection().items.map { h -> (Hadith, Int) in
            let t = Set(ContentStore.clean(h.text).split(separator: " ").map(String.init))
            return (h, q.filter { t.contains($0) }.count * 100 / q.count)
        }
        .filter { $0.1 >= 50 }.sorted { $0.1 > $1.1 }.prefix(5)
        .map { Hadith(id: $0.0.id, title: $0.0.title, text: $0.0.text, source: $0.0.source, grade: $0.0.grade, cat: $0.0.cat, url: $0.0.url, match: $0.1) }
    }

    /// POST /api/hadith/check {"text": ...}  (as on /tools/hadith-checker)
    static func checkHadith(_ text: String) async throws -> HadithCheck {
        guard Net.isOnline else { throw URLError(.notConnectedToInternet) }
        var r = URLRequest(url: base.appendingPathComponent("api/hadith/check"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONEncoder().encode(["text": text])
        r.timeoutInterval = 30
        let (data, resp) = try await URLSession.site.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(HadithCheck.self, from: data)
    }

    /// GET /api/radios (mp3quran.net streams, as on /tools/radio)
    static func radios() async throws -> [Radio] {
        try await (get(base.appendingPathComponent("api/radios"), cacheKey: "radios", maxAge: 24 * 3600) as Radios).radios
    }

    /// Cache first, then network, then stale cache:
    /// 1. a copy younger than `maxAge` is used without touching the server (many users opening
    ///    the same page no longer each cost a request, and the screen opens instantly);
    /// 2. otherwise the server, with one retry after a short pause for timeouts and 5xx;
    /// 3. if that fails, any older copy (works offline and while the server is busy).
    private static func get<T: Decodable>(_ url: URL, cacheKey: String, maxAge: TimeInterval = 0) async throws -> T {
        let file = cacheDir.appendingPathComponent(cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "x")
        // Offline: a saved copy at once, else a clear «no connection» instead of waiting for a timeout.
        if !Net.isOnline {
            if let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(T.self, from: data) { return value }
            throw URLError(.notConnectedToInternet)
        }
        if maxAge > 0,
           let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           Date().timeIntervalSince(modified) < maxAge,
           let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(T.self, from: data) {
            return value
        }
        do {
            let data = try await fetch(url)
            let value = try JSONDecoder().decode(T.self, from: data)
            try? data.write(to: file, options: .atomic)
            return value
        } catch {
            if let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(T.self, from: data) { return value }
            throw error
        }
    }

    /// One GET with a single retry (after 1.5 s) when the failure is transient.
    private static func fetch(_ url: URL) async throws -> Data {
        var attempt = 0
        while true {
            do {
                var r = URLRequest(url: url)
                r.timeoutInterval = 20
                let (data, resp) = try await URLSession.site.data(for: r)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 { return data }
                throw URLError(code >= 500 || code == 429 ? .cannotConnectToHost : .badServerResponse)
            } catch let e as URLError where attempt == 0 && Self.transient(e) {
                attempt += 1
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private static func transient(_ e: URLError) -> Bool {
        [.timedOut, .cannotConnectToHost, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed].contains(e.code)
    }

    /// Saved answers live in Application Support (not Caches, which iOS may empty), so tools keep working offline.
    static var cacheDir: URL {
        let d = OfflinePrep.root.appendingPathComponent("site-api", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
}

extension URLSession {
    /// One session for ayattla.com and Quran.com requests: at most 4 connections per host, so a
    /// burst of taps queues on the phone instead of opening a connection each on the server, and
    /// no request (a full video included) can hang longer than 5 minutes. Shares the app's
    /// URLCache, so the servers' cache headers keep working.
    static let site: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpMaximumConnectionsPerHost = 4
        c.timeoutIntervalForResource = 300
        c.urlCache = .shared
        return URLSession(configuration: c)
    }()
}
