import Foundation

/// Khatma plan as on /tools/khatma: the remaining mushaf pages (604-page Madani mushaf) spread
/// evenly over the days, and each day's wird spread over the five prayers.
public struct KhatmaPlan: Equatable, Sendable, Codable {
    public static let pages = 604

    public var days: Int
    public var startPage: Int
    public var startDate: Date
    public var completedDays: Set<Int>

    public init(days: Int, startPage: Int = 1, startDate: Date, completedDays: Set<Int> = []) {
        self.days = max(1, days)
        self.startPage = min(max(1, startPage), Self.pages)
        self.startDate = startDate
        self.completedDays = completedDays
    }

    public var totalPages: Int { Self.pages - startPage + 1 }

    /// Pages for day `d` (1-based), inclusive. Days beyond the pages get an empty range.
    public func range(day d: Int) -> ClosedRange<Int>? {
        guard (1...days).contains(d) else { return nil }
        let a = startPage + (d - 1) * totalPages / days
        let b = startPage + d * totalPages / days - 1
        return a <= b ? a...b : nil
    }

    /// Splits a day's pages over the five prayers (Fajr, Dhuhr, Asr, Maghrib, Isha); some may be empty.
    public static func splitOverPrayers(_ r: ClosedRange<Int>) -> [ClosedRange<Int>?] {
        let n = r.count
        return (0..<5).map { i in
            let a = r.lowerBound + i * n / 5
            let b = r.lowerBound + (i + 1) * n / 5 - 1
            return a <= b ? a...b : nil
        }
    }

    /// Day number for a date (1 on the start date), using the given calendar's day boundaries.
    public func day(on date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        let a = calendar.startOfDay(for: startDate), b = calendar.startOfDay(for: date)
        return (calendar.dateComponents([.day], from: a, to: b).day ?? 0) + 1
    }

    public func expectedEnd(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        calendar.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
    }

    public var pagesPerDay: Double { Double(totalPages) / Double(days) }
    public var isFinished: Bool { completedDays.count >= days }
}
