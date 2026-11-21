import SwiftUI
import Observation
import AyatDesign

/// «رحلتي مع القرآن»: what was done each day — mushaf pages read, ayat heard, hifz portions — the
/// daily goal in pages, and the run of days in a row with time for the Quran. Kept on the phone only.
@Observable
final class Journey {
    static let shared = Journey()

    /// One day: the pages opened (each once a day), ayat heard, hifz portions learnt or reviewed.
    struct Day: Codable, Equatable {
        var pages: Set<Int> = []
        var ayat = 0
        var hifz = 0
        /// A day counts in the run with at least one page, five ayat heard, or one hifz portion.
        var active: Bool { !pages.isEmpty || ayat >= 5 || hifz > 0 }
    }

    static let goals = [1, 2, 4, 10, 20]

    private(set) var days: [Int: Day] = [:]
    private(set) var goal = 2

    private struct Stored: Codable { var goal: Int; var days: [String: Day] }

    @ObservationIgnored private let file: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("journey.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(Stored.self, from: data) {
            goal = s.goal
            days = Dictionary(uniqueKeysWithValues: s.days.compactMap { k, v in Int(k).map { ($0, v) } })
        }
    }

    /// For tests: start from given days.
    init(days: [Int: Day], goal: Int) { self.days = days; self.goal = goal }

    static func dayNumber(_ date: Date = Date()) -> Int {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let utc = Calendar(identifier: .gregorian)
        var u = utc; u.timeZone = TimeZone(identifier: "UTC")!
        return Int((u.date(from: c)?.timeIntervalSince1970 ?? 0) / 86_400)
    }
    static func date(of day: Int) -> Date {
        var u = Calendar(identifier: .gregorian); u.timeZone = TimeZone(identifier: "UTC")!
        let utc = Date(timeIntervalSince1970: Double(day) * 86_400)
        let c = u.dateComponents([.year, .month, .day], from: utc)
        return Calendar(identifier: .gregorian).date(from: c) ?? utc
    }
    var today: Int { Self.dayNumber() }

    private func update(_ d: Int? = nil, _ f: (inout Day) -> Void) {
        let key = d ?? today
        var v = days[key] ?? Day()
        let old = v
        f(&v)
        guard v != old else { return }
        days[key] = v
        save()
    }

    func readPage(_ p: Int) { guard (1...604).contains(p) else { return }; update { $0.pages.insert(p) } }
    func listened(_ n: Int = 1) { update { $0.ayat += n } }
    func hifzDone() { update { $0.hifz += 1 } }
    func setGoal(_ n: Int) { goal = min(max(n, 1), 40); save() }

    func day(_ d: Int? = nil) -> Day { days[d ?? today] ?? Day() }
    var pagesToday: Int { day().pages.count }
    func goalMet(_ d: Int? = nil) -> Bool { day(d).pages.count >= goal }

    /// Days in a row ending today (or yesterday while today is still open).
    func streak(now: Int? = nil) -> Int {
        let n0 = now ?? today
        var d = day(n0).active ? n0 : n0 - 1
        var n = 0
        while day(d).active { n += 1; d -= 1 }
        return n
    }

    var best: Int {
        var best = 0, run = 0, prev = Int.min
        for d in days.filter({ $0.value.active }).keys.sorted() {
            run = (d == prev + 1) ? run + 1 : 1; best = max(best, run); prev = d
        }
        return best
    }

    /// The last seven days, oldest first.
    func week(now: Int? = nil) -> [(day: Int, value: Day)] {
        let n0 = now ?? today
        return (0..<7).reversed().map { (n0 - $0, day(n0 - $0)) }
    }

    var monthPages: Int {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.dateComponents([.year, .month], from: Date())
        return days.filter { k, _ in
            let c = cal.dateComponents([.year, .month], from: Self.date(of: k)); return c.year == now.year && c.month == now.month
        }.values.reduce(0) { $0 + $1.pages.count }
    }
    var totalAyat: Int { days.values.reduce(0) { $0 + $1.ayat } }
    var totalHifz: Int { days.values.reduce(0) { $0 + $1.hifz } }

    private func save() {
        let keep = days.filter { $0.key > today - 400 }
        let s = Stored(goal: goal, days: Dictionary(uniqueKeysWithValues: keep.map { (String($0.key), $0.value) }))
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: file, options: .atomic) }
    }

    static func goalLabel(_ n: Int) -> String {
        switch n { case 1: "صفحة"; case 2: "صفحتان"; case 20: "جزء"; case 3...10: "\(n) صفحات"; default: "\(n) صفحة" }
    }
    static func streakLabel(_ n: Int) -> String {
        switch n { case 1: "يوم واحد"; case 2: "يومان متتاليان"; case 3...10: "\(n) أيام متتالية"; default: "\(n) يوما متتاليا" }
    }
}
