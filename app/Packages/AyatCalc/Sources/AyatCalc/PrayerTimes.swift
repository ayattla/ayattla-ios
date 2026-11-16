import Foundation

/// Prayer-time calculation, a line-by-line port of ayattla.com/tools/prayer-times.
/// Asr uses the majority (Shafii) shadow factor, as on the site.
public struct PrayerTimes: Equatable, Sendable {
    public let fajr, sunrise, dhuhr, asr, maghrib, isha: Double   // local hours, may exceed 0..<24 before formatting

    public init(fajr: Double, sunrise: Double, dhuhr: Double, asr: Double, maghrib: Double, isha: Double) {
        self.fajr = fajr; self.sunrise = sunrise; self.dhuhr = dhuhr; self.asr = asr; self.maghrib = maghrib; self.isha = isha
    }

    /// Calculation settings of one city on the site: Fajr angle, and Isha angle
    /// or (if > 30) minutes after Maghrib. `90` becomes `120` in Ramadan, as on the site.
    public struct Method: Hashable, Sendable {
        public let fajrAngle: Double
        public let isha: Double
        public init(fajrAngle: Double, isha: Double) { self.fajrAngle = fajrAngle; self.isha = isha }
        /// Umm al-Qura, used on the site for Saudi cities and for a location inside Saudi Arabia.
        public static let ummAlQura = Method(fajrAngle: 18.5, isha: 90)
        /// Used on the site for "my location" outside Saudi Arabia.
        public static let defaultGeo = Method(fajrAngle: 18, isha: 17)

        /// Methods the user can choose (id, name). "auto" keeps the site's choice per city.
        public static let choices: [(id: String, name: String, method: Method)] = [
            ("umm-al-qura", "أم القرى (مكة المكرمة)", Method(fajrAngle: 18.5, isha: 90)),
            ("mwl", "رابطة العالم الإسلامي", Method(fajrAngle: 18, isha: 17)),
            ("egypt", "الهيئة المصرية العامة للمساحة", Method(fajrAngle: 19.5, isha: 17.5)),
            ("karachi", "جامعة العلوم الإسلامية بكراتشي", Method(fajrAngle: 18, isha: 18)),
            ("isna", "أمريكا الشمالية (ISNA)", Method(fajrAngle: 15, isha: 15)),
            ("dubai", "دبي", Method(fajrAngle: 18.2, isha: 18.2)),
            ("kuwait", "الكويت", Method(fajrAngle: 18, isha: 17.5)),
            ("qatar", "قطر", Method(fajrAngle: 18, isha: 90)),
        ]
        public static func byID(_ id: String) -> Method? { choices.first { $0.id == id }?.method }

        /// Same rule as the site's "موقعي" button.
        public static func forLocation(lat: Double, lng: Double) -> Method {
            let ksa = lat > 16 && lat < 32.5 && lng > 34.5 && lng < 55.7
            return ksa ? .ummAlQura : .defaultGeo
        }
    }

    /// - Parameters:
    ///   - year, month, day: the local civil date.
    ///   - tzHours: UTC offset of the zone on that date, in hours.
    ///   - ramadan: true during Ramadan (affects isha == 90 only).
    public static func compute(year: Int, month: Int, day: Int, lat: Double, lng: Double,
                               tzHours: Double, method: Method, ramadan: Bool = false, asrFactor: Double = 1) -> PrayerTimes {
        let jd = Astro.julian(year, month, day) - lng / (15 * 24)
        func mid(_ t: Double) -> Double { Astro.fix(12 - Astro.sunPos(jd + t).eqt, 24) }
        func ang(_ a: Double, _ t: Double, ccw: Bool = false) -> Double {
            let d = Astro.sunPos(jd + t).decl
            let T = Astro.darccos((-Astro.dsin(a) - Astro.dsin(d) * Astro.dsin(lat)) / (Astro.dcos(d) * Astro.dcos(lat))) / 15
            return mid(t) + (ccw ? -T : T)
        }
        func asr(_ t: Double) -> Double {
            let d = Astro.sunPos(jd + t).decl
            return ang(-Astro.darccot(asrFactor + Astro.dtan(abs(lat - d))), t)
        }
        func adj(_ t: Double) -> Double { t + tzHours - lng / 15 }

        let fajr = adj(ang(method.fajrAngle, 5.0 / 24, ccw: true))
        let sunrise = adj(ang(0.833, 6.0 / 24, ccw: true))
        let dhuhr = adj(mid(0.5))
        let asrT = adj(asr(13.0 / 24))
        let maghrib = adj(ang(0.833, 18.0 / 24))
        let isha: Double
        if method.isha > 30 {
            let minutes = (method.isha == 90 && ramadan) ? 120 : method.isha
            isha = maghrib + minutes / 60
        } else {
            isha = adj(ang(method.isha, 18.0 / 24))
        }
        return PrayerTimes(fajr: fajr, sunrise: sunrise, dhuhr: dhuhr, asr: asrT, maghrib: maghrib, isha: isha)
    }

    /// Each prayer moved by the user's minutes (the "manual adjustment" setting).
    public func adjusted(_ m: [Prayer: Int]) -> PrayerTimes {
        if m.isEmpty { return self }
        func a(_ p: Prayer, _ v: Double) -> Double { v + Double(m[p] ?? 0) / 60 }
        return PrayerTimes(fajr: a(.fajr, fajr), sunrise: a(.sunrise, sunrise), dhuhr: a(.dhuhr, dhuhr),
                           asr: a(.asr, asr), maghrib: a(.maghrib, maghrib), isha: a(.isha, isha))
    }

    /// Minute of the day as shown (half a minute rounding, as `hhmm`).
    public static func minute(_ hours: Double) -> Int {
        let h = Astro.fix(hours + 0.5 / 60, 24)
        let H = Int(h.rounded(.down))
        return H * 60 + Int(((h - Double(H)) * 60).rounded(.down))
    }

    /// "HH:mm" (24h), rounded the same way as the site's `fmt` (half a minute, then floor).
    public static func hhmm(_ hours: Double) -> String {
        let h = Astro.fix(hours + 0.5 / 60, 24)
        let H = Int(h.rounded(.down))
        let M = Int(((h - Double(H)) * 60).rounded(.down))
        return String(format: "%02d:%02d", H, M)
    }

    /// UTC offset in hours for `zone` at `date`.
    public static func tzHours(_ zone: TimeZone, at date: Date) -> Double {
        Double(zone.secondsFromGMT(for: date)) / 3600
    }
}

enum Astro {
    static let rad = Double.pi / 180
    static func dsin(_ d: Double) -> Double { sin(d * rad) }
    static func dcos(_ d: Double) -> Double { cos(d * rad) }
    static func dtan(_ d: Double) -> Double { tan(d * rad) }
    static func darcsin(_ x: Double) -> Double { asin(x) / rad }
    static func darccos(_ x: Double) -> Double { acos(max(-1, min(1, x))) / rad }
    static func darctan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) / rad }
    static func darccot(_ x: Double) -> Double { atan(1 / x) / rad }
    static func fix(_ a: Double, _ b: Double) -> Double {
        let r = a - b * (a / b).rounded(.down)
        return r < 0 ? r + b : r
    }

    static func sunPos(_ jd: Double) -> (decl: Double, eqt: Double) {
        let D = jd - 2451545
        let g = fix(357.529 + 0.98560028 * D, 360)
        let q = fix(280.459 + 0.98564736 * D, 360)
        let L = fix(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g), 360)
        let e = 23.439 - 0.00000036 * D
        let RA = darctan2(dcos(e) * dsin(L), dcos(L)) / 15
        return (darcsin(dsin(e) * dsin(L)), q / 15 - fix(RA, 24))
    }

    static func julian(_ year: Int, _ month: Int, _ day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let A = (y / 100).rounded(.down)
        let B = 2 - A + (A / 4).rounded(.down)
        return (365.25 * (y + 4716)).rounded(.down) + (30.6001 * (m + 1)).rounded(.down) + Double(day) + B - 1524.5
    }
}
