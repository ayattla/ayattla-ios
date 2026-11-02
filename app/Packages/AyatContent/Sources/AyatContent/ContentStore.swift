import Foundation
import SQLite3
import CryptoKit

// STATUS: written without a Swift toolchain; NOT compiled yet. SQL statements are
// checked against a real pack in tools/check_content_sql.py.

public struct Surah: Equatable, Sendable, Identifiable {
    public let id: Int
    public let nameAr: String
    public let nameEn: String?
    public let ayahCount: Int
    public let revelation: String?
    public let pageStart: Int?
}

/// One ayah exactly as stored in the pack. `textUthmani` is shown; `textClean` is for search only.
public struct Ayah: Equatable, Sendable, Identifiable {
    public let surah: Int
    public let ayah: Int
    public let textUthmani: String
    public let page: Int?
    public let juz: Int?
    public var id: String { "\(surah):\(ayah)" }
}

public struct ZikrCategory: Equatable, Sendable, Identifiable { public let id: Int; public let title: String }
public struct Zikr: Equatable, Sendable, Identifiable {
    public let id: Int, category: Int
    public let text: String
    public let count: Int
    public let reference: String?, note: String?
    public let audioId: Int?
}

public enum ContentError: Error, Equatable {
    case open(String), query(String), checksum(expected: String, actual: String), incomplete(Int)
}

/// Read-only access to content-vN.sqlite built by tools/build_content_pack.py.
public final class ContentStore: @unchecked Sendable {
    public static let expectedAyat = 6236
    private var db: OpaquePointer?
    private let lock = NSLock()

    public init(url: URL) throws {
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            throw ContentError.open(String(cString: sqlite3_errmsg(db)))
        }
    }
    deinit { sqlite3_close(db) }

    /// Verifies the file against the manifest digest before first use.
    public static func verify(url: URL, sha256 expected: String) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected.lowercased() else { throw ContentError.checksum(expected: expected, actual: actual) }
    }

    public func meta(_ key: String) throws -> String? {
        try rows("SELECT value FROM meta WHERE key = ?", [.text(key)]) { $0.text(0) }.first ?? nil
    }

    /// Fails if the pack does not hold the full mushaf.
    public func checkComplete() throws {
        let n = try rows("SELECT count(*) FROM ayah", []) { $0.int(0) }.first ?? 0
        guard n == Self.expectedAyat else { throw ContentError.incomplete(n) }
    }

    public func surahs() throws -> [Surah] {
        try rows("SELECT id, name_ar, name_en, ayah_count, revelation, page_start FROM surah ORDER BY id", []) {
            Surah(id: $0.int(0), nameAr: $0.text(1) ?? "", nameEn: $0.text(2), ayahCount: $0.int(3),
                  revelation: $0.text(4), pageStart: $0.intOrNil(5))
        }
    }

    public func ayat(surah: Int, from: Int, to: Int) throws -> [Ayah] {
        try rows("SELECT surah, ayah, text_uthmani, page, juz FROM ayah WHERE surah = ? AND ayah BETWEEN ? AND ? ORDER BY ayah",
                 [.int(surah), .int(from), .int(to)], map: Self.ayah)
    }

    public func page(_ n: Int) throws -> [Ayah] {
        try rows("SELECT surah, ayah, text_uthmani, page, juz FROM ayah WHERE page = ? ORDER BY surah, ayah",
                 [.int(n)], map: Self.ayah)
    }

    /// Full-text search that ignores tashkeel and alef forms, like the site.
    public func search(_ query: String, limit: Int = 50) throws -> [Ayah] {
        let terms = Self.clean(query).split(separator: " ").map { "\"\($0.replacingOccurrences(of: "\"", with: ""))\"" }
        guard !terms.isEmpty else { return [] }
        return try rows("""
            SELECT a.surah, a.ayah, a.text_uthmani, a.page, a.juz FROM ayah_fts f
            JOIN ayah a ON a.rowid = f.rowid WHERE ayah_fts MATCH ? ORDER BY a.surah, a.ayah LIMIT ?
            """, [.text(terms.joined(separator: " ")), .int(limit)], map: Self.ayah)
    }

    public func translation(edition: String, surah: Int, ayah: Int) throws -> String? {
        try rows("SELECT text FROM translation WHERE edition = ? AND surah = ? AND ayah = ?",
                 [.text(edition), .int(surah), .int(ayah)]) { $0.text(0) }.first ?? nil
    }

    public func azkarCategories() throws -> [ZikrCategory] {
        try rows("SELECT id, title FROM azkar_category ORDER BY id", []) { ZikrCategory(id: $0.int(0), title: $0.text(1) ?? "") }
    }

    public func azkar(category: Int) throws -> [Zikr] {
        try rows("SELECT id, category, text, count, reference, note, audio_id FROM azkar WHERE category = ? ORDER BY id",
                 [.int(category)]) {
            Zikr(id: $0.int(0), category: $0.int(1), text: $0.text(2) ?? "", count: $0.int(3),
                 reference: $0.text(4), note: $0.text(5), audioId: $0.intOrNil(6))
        }
    }

    /// Same normalization as tools/build_content_pack.py `clean()` (search only).
    public static func clean(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            switch u.value {
            case 0x0610...0x061A, 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x0640: continue
            case 0x0622, 0x0623, 0x0625, 0x0671: out.unicodeScalars.append("\u{0627}")
            default: out.unicodeScalars.append(u)
            }
        }
        return out.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: - SQLite plumbing

    enum Bind { case int(Int), text(String) }
    struct Row {
        let stmt: OpaquePointer
        func int(_ i: Int32) -> Int { Int(sqlite3_column_int64(stmt, i)) }
        func intOrNil(_ i: Int32) -> Int? { sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : int(i) }
        func text(_ i: Int32) -> String? { sqlite3_column_text(stmt, i).map { String(cString: $0) } }
    }
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private static func ayah(_ r: Row) -> Ayah {
        Ayah(surah: r.int(0), ayah: r.int(1), textUthmani: r.text(2) ?? "", page: r.intOrNil(3), juz: r.intOrNil(4))
    }

    func rows<T>(_ sql: String, _ binds: [Bind], map: (Row) -> T) throws -> [T] {
        lock.lock(); defer { lock.unlock() }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            throw ContentError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(s) }
        for (i, b) in binds.enumerated() {
            let idx = Int32(i + 1)
            switch b {
            case .int(let v): sqlite3_bind_int64(s, idx, Int64(v))
            case .text(let v): sqlite3_bind_text(s, idx, v, -1, Self.transient)
            }
        }
        var out: [T] = []
        while true {
            let rc = sqlite3_step(s)
            if rc == SQLITE_ROW { out.append(map(Row(stmt: s))) }
            else if rc == SQLITE_DONE { break }
            else { throw ContentError.query(String(cString: sqlite3_errmsg(db))) }
        }
        return out
    }
}
