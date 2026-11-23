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

/// A season the day belongs to (Friday, Ramadan, the ten of Dhul-Hijjah, voluntary fasts).
/// Same keys, wording and rules as the Android app; `route` is a shared key the app maps to a screen.
public struct SeasonNote: Equatable, Sendable, Identifiable {
    public let key: String
    public let title: String
    public let line: String
    public let route: String
    public var id: String { key }
    public init(_ key: String, _ title: String, _ line: String, _ route: String) {
        self.key = key; self.title = title; self.line = line; self.route = route
    }
}

public enum Seasons {
    /// - Parameter weekday: ISO weekday, 1 = Monday … 7 = Sunday.
    public static func notes(weekday: Int, hijriMonth: Int, hijriDay: Int, slot: TodaySlot,
                             maghrib: String, fajrTomorrow: String) -> [SeasonNote] {
        var out: [SeasonNote] = []
        let beforeMaghrib = slot == .morning || slot == .wird || slot == .evening
        if weekday == 5 && beforeMaghrib {
            out.append(SeasonNote("kahf", "سورة الكهف", "من سنن يوم الجمعة", "reader/18/1"))
            out.append(SeasonNote("salawat", "الصلاة على النبي", "أكثروا منها يوم الجمعة", "tasbih"))
        }
        if hijriMonth == 9 {
            if beforeMaghrib { out.append(SeasonNote("iftar", "الإفطار \(maghrib)", "موعد أذان المغرب اليوم", "prayer")) }
            if slot == .hadith { out.append(SeasonNote("tarawih", "صلاة التراويح", "بعد صلاة العشاء", "prayer")) }
            if slot == .night { out.append(SeasonNote("suhoor", "السحور قبل \(fajrTomorrow)", "موعد أذان الفجر", "prayer")) }
            out.append(SeasonNote("khatma", "ختمة رمضان", "وزع المصحف على أيام الشهر", "khatma"))
        }
        if hijriMonth == 12 && (1...9).contains(hijriDay) { out.append(SeasonNote("takbir", "التكبير في العشر", "الله أكبر ولله الحمد", "tasbih")) }
        if hijriMonth == 12 && hijriDay == 8 && !beforeMaghrib { out.append(SeasonNote("arafah-eve", "غدا يوم عرفة", "صيامه يكفر سنتين", "sawm")) }
        if hijriMonth == 12 && hijriDay == 9 { out.append(SeasonNote("arafah", "يوم عرفة", "صيامه يكفر سنتين، وأكثر من الدعاء", "duas")) }
        if hijriMonth == 12 && hijriDay == 10 { out.append(SeasonNote("eid", "عيد الأضحى", "تقبل الله منا ومنكم", "occasions")) }
        if slot == .night && hijriMonth != 9 {
            let tomorrow = weekday % 7 + 1
            if tomorrow == 1 { out.append(SeasonNote("fast-mon", "صيام الاثنين غدا", "من صيام التطوع", "sawm")) }
            if tomorrow == 4 { out.append(SeasonNote("fast-thu", "صيام الخميس غدا", "من صيام التطوع", "sawm")) }
            if (12...14).contains(hijriDay) { out.append(SeasonNote("white", "الأيام البيض", "غدا اليوم \(hijriDay + 1) من الشهر", "sawm")) }
        }
        return out
    }

    /// ISO weekday (1 = Monday … 7 = Sunday) of a date in a calendar.
    public static func isoWeekday(_ date: Foundation.Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}
