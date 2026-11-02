import Foundation

// STATUS: written without a Swift toolchain; NOT compiled yet. Logic mirrored and tested in
// tools/check_timeline.py.

/// Word timings for a recited range, in milliseconds from the start of the audio.
/// Matches `Timing` in docs/app-api-v1.openapi.yaml.
public struct Timeline: Equatable, Sendable, Codable {
    public struct Word: Equatable, Sendable, Codable { public let position, startMs, endMs: Int }
    public struct AyahSpan: Equatable, Sendable, Codable {
        public let ayah, startMs, endMs: Int
        public let words: [Word]
    }
    public let ayat: [AyahSpan]

    public init(ayat: [AyahSpan]) { self.ayat = ayat }

    public enum Problem: Error, Equatable {
        case empty
        case badSpan(ayah: Int)
        case outOfOrder(ayah: Int, position: Int)
        case wordOutsideAyah(ayah: Int, position: Int)
        case beyondAudio(ayah: Int)
    }

    /// Rejects timings that would highlight the wrong word. The app never highlights with
    /// a timeline that fails this check; it falls back to whole-ayah display instead.
    public func validate(audioDurationMs: Int? = nil, toleranceMs: Int = 40) throws {
        guard !ayat.isEmpty else { throw Problem.empty }
        var lastAyahEnd = Int.min
        for a in ayat {
            guard a.endMs > a.startMs, a.startMs + toleranceMs >= lastAyahEnd else { throw Problem.badSpan(ayah: a.ayah) }
            if let d = audioDurationMs, a.endMs > d + toleranceMs { throw Problem.beyondAudio(ayah: a.ayah) }
            var lastEnd = a.startMs - toleranceMs, lastPos = 0
            for w in a.words {
                guard w.position > lastPos, w.endMs >= w.startMs, w.startMs + toleranceMs >= lastEnd else {
                    throw Problem.outOfOrder(ayah: a.ayah, position: w.position)
                }
                guard w.startMs + toleranceMs >= a.startMs, w.endMs <= a.endMs + toleranceMs else {
                    throw Problem.wordOutsideAyah(ayah: a.ayah, position: w.position)
                }
                lastEnd = w.endMs; lastPos = w.position
            }
            lastAyahEnd = a.endMs
        }
    }

    /// The ayah and word to highlight at time `ms`. Between words the previous word stays lit
    /// (no flicker); before the first word of an ayah nothing in it is lit.
    public func active(at ms: Int) -> (ayah: Int, position: Int?)? {
        guard let ai = Self.lastIndex(in: ayat, where: { $0.startMs <= ms }) else { return nil }
        let a = ayat[ai]
        if ms >= a.endMs, ai == ayat.count - 1 { return nil }
        let wi = Self.lastIndex(in: a.words, where: { $0.startMs <= ms })
        return (a.ayah, wi.map { a.words[$0].position })
    }

    /// Shift every time by `offsetMs`, e.g. after prepending the basmala clip.
    public func shifted(by offsetMs: Int) -> Timeline {
        Timeline(ayat: ayat.map { a in
            AyahSpan(ayah: a.ayah, startMs: a.startMs + offsetMs, endMs: a.endMs + offsetMs,
                     words: a.words.map { Word(position: $0.position, startMs: $0.startMs + offsetMs, endMs: $0.endMs + offsetMs) })
        })
    }

    /// Binary search: last index whose element satisfies a monotone predicate.
    static func lastIndex<T>(in xs: [T], where p: (T) -> Bool) -> Int? {
        var lo = 0, hi = xs.count
        while lo < hi { let m = (lo + hi) / 2; if p(xs[m]) { lo = m + 1 } else { hi = m } }
        return lo == 0 ? nil : lo - 1
    }
}
