import Foundation
import AyatCalc

/// Arabic-Indic digits everywhere in the UI (design/System.dc.html).
public enum Num {
    public static let locale = Locale(identifier: "ar@numbers=arab")

    public static func digits(_ s: String) -> String {
        var out = ""
        for c in s {
            if c.isASCII, let d = c.wholeNumberValue {
                out.unicodeScalars.append(Unicode.Scalar(UInt32(0x0660 + d))!)
            } else {
                out.append(c)
            }
        }
        return out
    }

    public static func int(_ n: Int) -> String { n.formatted(.number.grouping(.never).locale(locale)) }

    public static func decimal(_ x: Double, digits: Int = 1) -> String {
        x.formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(locale))
    }

    /// "HH:mm" as the site shows it, with Arabic-Indic digits.
    public static func time(_ hours: Double) -> String { self.digits(PrayerTimes.hhmm(hours)) }

    /// "3 ساعات و12 دقيقة" with correct Arabic plural forms.
    public static func duration(minutes: Int) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        f.unitsStyle = .full
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        f.calendar = cal
        return f.string(from: TimeInterval(minutes * 60)) ?? int(minutes)
    }

    /// Distance as the site shows it: metres under 1 km ("٣٥٠ م"), otherwise km with one decimal ("١٫٢ كم").
    public static func distance(meters: Double) -> String {
        if meters < 1000 {
            let m = Int((meters / 10).rounded()) * 10
            return "\(int(m)) م"
        }
        return "\(decimal(meters / 1000)) كم"
    }

    public static func hijri(_ date: Date) -> String {
        let h = Hijri.fromGregorian(date)
        return "\(int(h.day)) \(Hijri.months[h.month - 1]) \(int(h.year)) هـ"
    }
}
