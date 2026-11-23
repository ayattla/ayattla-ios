import Foundation

/// «يومي»: the day split by the five prayers, one short step after each. The step on show follows
/// the real prayer times of the user's city, so it moves with the seasons and never needs setting.
/// Same slots and order as the Android app.
public enum TodaySlot: String, CaseIterable, Sendable, Identifiable {
    case morning, wird, evening, hadith, night
    public var id: String { rawValue }

    public var after: Prayer {
        switch self {
        case .morning: .fajr
        case .wird: .dhuhr
        case .evening: .asr
        case .hadith: .maghrib
        case .night: .isha
        }
    }

    public var title: String {
        switch self {
        case .morning: "أذكار الصباح"
        case .wird: "وردك من القرآن"
        case .evening: "أذكار المساء"
        case .hadith: "حديث اليوم"
        case .night: "سورة الملك وأذكار النوم"
        }
    }

    public var line: String {
        switch self {
        case .morning: "من الفجر حتى الشروق"
        case .wird: "صفحات اليوم من هدفك"
        case .evening: "من العصر حتى المغرب"
        case .hadith: "حديث صحيح أو حسن مع مصدره وحكمه"
        case .night: "قبل أن تنام"
        }
    }

    /// The slot after this one, for «التالي».
    public var next: TodaySlot { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count] }
}

public enum TodayPlan {
    /// The step for this minute of the day: the slot of the last prayer whose time has come
    /// (before Fajr: last night's).
    public static func slot(minute: Int, times t: PrayerTimes) -> TodaySlot {
        TodaySlot.allCases.last { minute >= PrayerTimes.displayMinute(t.hours($0.after)) } ?? .night
    }

    /// After midnight and before Fajr, the night still belongs to yesterday (days back from today).
    public static func daysBack(minute: Int, times t: PrayerTimes) -> Int {
        minute < PrayerTimes.displayMinute(t.fajr) ? 1 : 0
    }

    /// Same item all day, a new one each day.
    public static func pick<T>(_ items: [T], dayNumber: Int) -> T? {
        guard !items.isEmpty else { return nil }
        let i = ((dayNumber % items.count) + items.count) % items.count
        return items[i]
    }
}
