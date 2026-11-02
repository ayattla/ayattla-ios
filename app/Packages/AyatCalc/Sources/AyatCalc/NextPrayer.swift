import Foundation

/// The six times shown in the prayer-times list, in display order.
public enum Prayer: Int, CaseIterable, Sendable, Identifiable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
    public var id: Int { rawValue }

    /// UI names, same as the site (no tashkeel).
    public var name: String {
        switch self {
        case .fajr: "الفجر"
        case .sunrise: "الشروق"
        case .dhuhr: "الظهر"
        case .asr: "العصر"
        case .maghrib: "المغرب"
        case .isha: "العشاء"
        }
    }

    /// Sunrise is listed but is not one of the five prayers.
    public var isPrayer: Bool { self != .sunrise }
}

extension PrayerTimes {
    public func hours(_ p: Prayer) -> Double {
        switch p {
        case .fajr: fajr
        case .sunrise: sunrise
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }

    /// Minute of the day as displayed by `hhmm` (same rounding), 0..<1440.
    public static func displayMinute(_ hours: Double) -> Int {
        let h = Astro.fix(hours + 0.5 / 60, 24)
        let H = Int(h.rounded(.down))
        return H * 60 + Int(((h - Double(H)) * 60).rounded(.down))
    }

    public struct Next: Equatable, Sendable {
        public let prayer: Prayer
        public let minutesUntil: Int
        public let isTomorrow: Bool
    }

    /// The next of the five prayers strictly after `minuteOfDay` (local time).
    /// After isha it is tomorrow's fajr, computed from `tomorrow`.
    public static func next(after minuteOfDay: Int, today: PrayerTimes, tomorrow: PrayerTimes) -> Next {
        for p in Prayer.allCases where p.isPrayer {
            let m = displayMinute(today.hours(p))
            if m > minuteOfDay { return Next(prayer: p, minutesUntil: m - minuteOfDay, isTomorrow: false) }
        }
        let m = displayMinute(tomorrow.fajr)
        return Next(prayer: .fajr, minutesUntil: 1440 - minuteOfDay + m, isTomorrow: true)
    }
}
