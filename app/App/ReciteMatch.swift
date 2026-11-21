import Foundation
import AyatContent

/// Matching what the device heard (plain Arabic from speech recognition) against the mushaf text, for
/// «التسميع الذكي» and «البحث بالصوت». Nothing here changes or generates Quran text: the words shown
/// are always the pack's own words; this only decides which of them were recited.
///
/// Same rules as the Android app (data/Recite.kt); keep the two in step.
enum Recite {
    private static func isMark(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x0610...0x061A, 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x08D3...0x08FF, 0x0640: true
        default: false
        }
    }

    /// A word reduced for comparison: no marks, one alef, ى→ي, ة→ه, ؤ→و, ئ→ي, letters only.
    static func key(_ word: String) -> String {
        var out = String.UnicodeScalarView()
        for u in word.unicodeScalars where !isMark(u) {
            let m: Unicode.Scalar
            switch u {
            case "ٱ", "أ", "إ", "آ": m = "ا"
            case "ى": m = "ي"
            case "ة": m = "ه"
            case "ؤ": m = "و"
            case "ئ": m = "ي"
            default: m = u
            }
            if (0x0621...0x064A).contains(m.value) { out.append(m) }
        }
        return String(out)
    }

    /// The consonant outline (no long vowels or hamza), which survives Uthmani vs plain spelling.
    static func skeleton(_ key: String) -> String { String(key.filter { !"اويء".contains($0) }) }

    /// Words of an ayah as shown (stop marks and the ayah number stay with the word before them).
    /// Split on the space characters themselves (not on grapheme clusters: a stop mark after a space
    /// joins that space into one cluster), the same as Android.
    static func tokens(_ text: String) -> [String] {
        text.unicodeScalars.split { CharacterSet.whitespacesAndNewlines.contains($0) }
            .map { String(String.UnicodeScalarView($0)) }
    }

    /// Indexes into [tokens] of the words that are recited (tokens with letters).
    static func wordIndexes(_ tokens: [String]) -> [Int] { tokens.indices.filter { !key(tokens[$0]).isEmpty } }

    static func similar(_ expected: String, _ heard: String) -> Bool {
        if expected.isEmpty || heard.isEmpty { return false }
        if expected == heard { return true }
        let r = ratio(expected, heard)
        if min(expected.count, heard.count) <= 2 { return r >= 0.99 }
        if r >= 0.72 { return true }
        let a = skeleton(expected), b = skeleton(heard)
        return a.count >= 2 && (a == b || (a.count >= 4 && ratio(a, b) >= 0.8))
    }

    static func ratio(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty || y.isEmpty { return x.count == y.count ? 1 : 0 }
        var prev = Array(0...y.count), cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                cur[j] = min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return 1 - Double(prev[y.count]) / Double(max(x.count, y.count))
    }

    /// Heard text split into comparison keys.
    static func heardKeys(_ text: String) -> [String] { tokens(text).map(key).filter { !$0.isEmpty } }

    enum Mark { case hidden, ok, review }

    /// Where the recitation stands: how many words are revealed, and the mark of each word.
    struct Progress: Equatable {
        var revealed: Int
        var marks: [Mark]
        var done: Bool { revealed >= marks.count }
        var review: [Int] { marks.indices.filter { marks[$0] == .review } }
    }

    /// A hint the user asked for: reveals expected word [index] (counted as «راجع هذه الكلمة»).
    static func hint(_ index: Int) -> String { "#hint:\(index)" }

    /// Follows the heard words through the expected ones, in order. A skipped word and a word heard
    /// differently three times in a row are both marked for review, never as «خطأ». Before the first
    /// matched word anything heard (isti'adha, basmala, noise) is ignored, and a word repeated after it
    /// was matched is not counted against the reciter.
    static func align(_ expected: [String], _ heard: [String], lookahead: Int = 3) -> Progress {
        var marks = Array(repeating: Mark.hidden, count: expected.count)
        var p = 0, misses = 0, i = 0
        while i < heard.count && p < expected.count {
            let h = heard[i]
            if h.hasPrefix("#hint:") {
                if Int(h.dropFirst(6)) == p { marks[p] = .review; p += 1; misses = 0 }
                i += 1; continue
            }
            let next: String? = i + 1 < heard.count && !heard[i + 1].hasPrefix("#") ? heard[i + 1] : nil
            var matched = false
            // The recitation starts at the first word: before it is matched, no word is skipped.
            for j in 0...(p > 0 ? lookahead : 0) {
                let e = p + j
                if e >= expected.count { break }
                let single = similar(expected[e], h)
                let joined = !single && next != nil && similar(expected[e], h + next!)
                if single || joined {
                    for s in p..<e { marks[s] = .review }
                    if marks[e] != .review { marks[e] = .ok }
                    p = e + 1
                    misses = 0
                    if joined { i += 1 }
                    matched = true
                    break
                }
            }
            if !matched {
                let repeated = (1...2).contains { b in p - b >= 0 && similar(expected[p - b], h) }
                if !repeated && p > 0 {
                    misses += 1
                    if misses >= 3 { marks[p] = .review; p += 1; misses = 0 }
                }
            }
            i += 1
        }
        return Progress(revealed: p, marks: marks)
    }
}

/// Finds ayat from a few recited words, offline, over the whole mushaf. Scores each ayah by how many
/// of the heard words appear in it in order (allowing Uthmani vs plain spelling).
final class VoiceSearch: @unchecked Sendable {
    struct Hit: Identifiable { let ayah: Ayah; let score: Double; var id: String { ayah.id } }
    private let entries: [(Ayah, [String])]

    init(ayat: [Ayah]) {
        entries = ayat.map { a in (a, Recite.tokens(a.textUthmani).map(Recite.key).filter { !$0.isEmpty }) }
    }

    /// The whole mushaf from the bundled pack, built once.
    static let shared: VoiceSearch = {
        let lib = ContentLibrary.shared
        var all: [Ayah] = []
        for s in 1...114 { all += (try? lib.store?.ayat(surah: s, from: 1, to: 999)) ?? [] }
        return VoiceSearch(ayat: all)
    }()

    func find(_ heardText: String, limit: Int = 10) -> [Hit] {
        var heard = Recite.heardKeys(heardText)
        // A leading isti'adha is not what the user is looking for.
        let drop = ["اعوذ", "بالله", "من", "الشيطان", "الرجيم"]
        var k = 0
        while k < heard.count && k < drop.count && heard[k] == drop[k] { k += 1 }
        if k >= 4 { heard.removeFirst(k) }
        heard = Array(heard.prefix(12))
        guard !heard.isEmpty else { return [] }
        var out: [Hit] = []
        for (a, words) in entries {
            let s = score(words, heard)
            if s >= 0.6 { out.append(Hit(ayah: a, score: s)) }
        }
        out.sort { ($0.score, -$0.ayah.surah, -$0.ayah.ayah) > ($1.score, -$1.ayah.surah, -$1.ayah.ayah) }
        return Array(out.prefix(limit))
    }

    private func score(_ words: [String], _ heard: [String]) -> Double {
        guard !words.isEmpty else { return 0 }
        var best = 0, bestSpan = Int.max
        for start in words.indices {
            if !Recite.similar(words[start], heard[0]) && (heard.count < 2 || !Recite.similar(words[start], heard[1])) { continue }
            var w = start, n = 0, last = start
            for h in heard {
                var k = w
                let stop = min(words.count, w + 3)
                while k < stop && !Recite.similar(words[k], h) { k += 1 }
                if k < stop { n += 1; last = k; w = k + 1 }
                if w >= words.count { break }
            }
            let span = last - start
            if n > best || (n == best && span < bestSpan) { best = n; bestSpan = span }
        }
        return Double(best) / Double(heard.count)
    }
}
