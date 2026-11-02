import Foundation

/// Countdown targets of ayattla.com/tools/occasions: Ramadan, the two Eids and Arafah,
/// on the Umm al-Qura calendar.
public enum Occasion: String, CaseIterable, Sendable, Identifiable {
    case ramadan, eidFitr, arafah, eidAdha
    public var id: String { rawValue }

    /// UI names (no tashkeel).
    public var name: String {
        switch self {
        case .ramadan: "رمضان"
        case .eidFitr: "عيد الفطر"
        case .arafah: "يوم عرفة"
        case .eidAdha: "عيد الأضحى"
        }
    }

    public var hijriMonth: Int {
        switch self {
        case .ramadan: 9
        case .eidFitr: 10
        case .arafah, .eidAdha: 12
        }
    }

    public var hijriDay: Int {
        switch self {
        case .ramadan, .eidFitr: 1
        case .arafah: 9
        case .eidAdha: 10
        }
    }

    public struct Upcoming: Equatable, Sendable {
        public let occasion: Occasion
        public let hijri: Hijri.Date
        public let gregorian: Date
        /// Whole days from `today` (0 = today).
        public let days: Int
    }

    /// The next time this occasion falls on or after the civil day of `today` (UTC days, like `Hijri`).
    public func next(from today: Date) -> Upcoming {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.startOfDay(for: today)
        let h = Hijri.fromGregorian(today)
        for year in [h.year, h.year + 1] {
            let target = Hijri.Date(year: year, month: hijriMonth, day: hijriDay)
            guard let g = Hijri.toGregorian(target) else { continue }
            let gDay = utc.startOfDay(for: g)
            if gDay >= start {
                let days = utc.dateComponents([.day], from: start, to: gDay).day ?? 0
                return Upcoming(occasion: self, hijri: target, gregorian: gDay, days: days)
            }
        }
        preconditionFailure("an occasion always occurs within two Hijri years")
    }

    /// All occasions, soonest first.
    public static func upcoming(from today: Date) -> [Upcoming] {
        allCases.map { $0.next(from: today) }.sorted { $0.days < $1.days }
    }
}

extension Hijri {
    /// Gregorian date of a Hijri date, or nil when the day does not exist in that month
    /// (for example day 30 of a 29-day month).
    public static func toGregorianExact(_ h: Date) -> Foundation.Date? {
        guard let g = toGregorian(h), fromGregorian(g) == h else { return nil }
        return g
    }

    /// Number of days in a Hijri month (29 or 30) on Umm al-Qura.
    public static func daysInMonth(year: Int, month: Int) -> Int {
        toGregorianExact(Date(year: year, month: month, day: 30)) == nil ? 29 : 30
    }
}
