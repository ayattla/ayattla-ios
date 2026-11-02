import Foundation

/// Hijri dates on the Umm al-Qura calendar, as the site does with Intl `islamic-umalqura`.
public enum Hijri {
    public struct Date: Equatable, Sendable { public let year, month, day: Int }

    /// Month names, same order and spelling as the site (UI text, no tashkeel).
    public static let months = ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
                                "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]

    static var calendar: Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    public static func fromGregorian(_ date: Foundation.Date) -> Date {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return Date(year: c.year!, month: c.month!, day: c.day!)
    }

    public static func toGregorian(_ h: Date) -> Foundation.Date? {
        calendar.date(from: DateComponents(year: h.year, month: h.month, day: h.day, hour: 12))
    }

    public static func isRamadan(_ date: Foundation.Date) -> Bool { fromGregorian(date).month == 9 }
}
