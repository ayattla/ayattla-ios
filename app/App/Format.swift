import Foundation
import AyatCalc

/// Arabic-Indic digits everywhere in the UI (design/System.dc.html).
enum Num {
    static let locale = Locale(identifier: "ar@numbers=arab")

    static func digits(_ s: String) -> String {
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

    static func int(_ n: Int) -> String { n.formatted(.number.grouping(.never).locale(locale)) }

    static func decimal(_ x: Double, digits: Int = 1) -> String {
        x.formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(locale))
    }

    /// "HH:mm" as the site shows it, with Arabic-Indic digits.
    static func time(_ hours: Double) -> String { self.digits(PrayerTimes.hhmm(hours)) }

    /// "3 ساعات و12 دقيقة" with correct Arabic plural forms.
    static func duration(minutes: Int) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        f.unitsStyle = .full
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        f.calendar = cal
        return f.string(from: TimeInterval(minutes * 60)) ?? int(minutes)
    }

    static func hijri(_ date: Date) -> String {
        let h = Hijri.fromGregorian(date)
        return "\(int(h.day)) \(Hijri.months[h.month - 1]) \(int(h.year)) هـ"
    }
}
