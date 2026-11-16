import Foundation
import UserNotifications
import AyatCalc

// MARK: - Prayer calculation settings (used everywhere times are shown)

/// The user's calculation choices: method ("auto" = the site's choice per city), Hanafi Asr and
/// minutes per prayer. Read by the prayer screen, the home card and the notifications.
enum PrayerCalc {
    static let methodKey = "prayer.method", hanafiKey = "prayer.asrHanafi"
    static func adjustKey(_ p: Prayer) -> String { "prayer.adjust.\(p.rawValue)" }

    static func method(default m: PrayerTimes.Method, _ d: UserDefaults = .standard) -> PrayerTimes.Method {
        PrayerTimes.Method.byID(d.string(forKey: methodKey) ?? "auto") ?? m
    }
    static func asrFactor(_ d: UserDefaults = .standard) -> Double { d.bool(forKey: hanafiKey) ? 2 : 1 }
    static func adjust(_ d: UserDefaults = .standard) -> [Prayer: Int] {
        var out: [Prayer: Int] = [:]
        for p in Prayer.allCases { let v = d.integer(forKey: adjustKey(p)); if v != 0 { out[p] = v } }
        return out
    }

    /// One day's times for a place with the user's settings.
    static func times(on day: Date, lat: Double, lng: Double, zone: TimeZone, method: PrayerTimes.Method,
                      _ d: UserDefaults = .standard) -> PrayerTimes {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return PrayerTimes.compute(year: c.year!, month: c.month!, day: c.day!, lat: lat, lng: lng,
                                   tzHours: PrayerTimes.tzHours(zone, at: day), method: self.method(default: method, d),
                                   ramadan: Hijri.isRamadan(day), asrFactor: asrFactor(d)).adjusted(adjust(d))
    }
}

// MARK: - Settings

struct PrayerAlertSetting: Codable, Equatable {
    var on = false
    var silent = false
    var before = 0
    var iqama = 0
}

struct PersonalReminder: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var minute: Int
    var days: Set<Int>   // Calendar weekday: 1 = Sunday … 7 = Saturday
}

/// The notification center's settings, the same rules as the Android app.
struct NotifyConfig: Codable, Equatable {
    var prayers: [String: PrayerAlertSetting] = [:]   // keyed by Prayer.rawValue
    var afterPrayer = false, afterPrayerDelay = 10
    var morning = false, morningOffset = 30
    var evening = false, eveningOffset = 30
    var sleep = false, sleepAt = 22 * 60 + 30
    var wake = false
    var istighfar = false, istighfarAt = 16 * 60 + 30
    var ayah = false, ayahAt = 9 * 60
    var khatma = false, khatmaAt = 20 * 60
    var hifz = false, hifzAt = 19 * 60
    var friday = false, fridayAt = 10 * 60
    var fasting = false, fastingAt = 21 * 60
    var whiteDays = false
    var personal: [PersonalReminder] = []
    var quiet = false, quietFrom = 23 * 60, quietTo = 5 * 60
    var snooze = 10

    static let fivePrayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    func alert(_ p: Prayer) -> PrayerAlertSetting { prayers["\(p.rawValue)"] ?? .init() }
    mutating func setAlert(_ p: Prayer, _ a: PrayerAlertSetting) { prayers["\(p.rawValue)"] = a }

    var anyOn: Bool {
        prayers.values.contains { $0.on } || afterPrayer || morning || evening || sleep || wake || istighfar || ayah ||
            khatma || hifz || friday || fasting || whiteDays || !personal.isEmpty
    }

    init() {}

    // Fields added later decode with their defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NotifyConfig()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        prayers = v(.prayers, d.prayers)
        afterPrayer = v(.afterPrayer, d.afterPrayer); afterPrayerDelay = v(.afterPrayerDelay, d.afterPrayerDelay)
        morning = v(.morning, d.morning); morningOffset = v(.morningOffset, d.morningOffset)
        evening = v(.evening, d.evening); eveningOffset = v(.eveningOffset, d.eveningOffset)
        sleep = v(.sleep, d.sleep); sleepAt = v(.sleepAt, d.sleepAt); wake = v(.wake, d.wake)
        istighfar = v(.istighfar, d.istighfar); istighfarAt = v(.istighfarAt, d.istighfarAt)
        ayah = v(.ayah, d.ayah); ayahAt = v(.ayahAt, d.ayahAt)
        khatma = v(.khatma, d.khatma); khatmaAt = v(.khatmaAt, d.khatmaAt)
        hifz = v(.hifz, d.hifz); hifzAt = v(.hifzAt, d.hifzAt)
        friday = v(.friday, d.friday); fridayAt = v(.fridayAt, d.fridayAt)
        fasting = v(.fasting, d.fasting); fastingAt = v(.fastingAt, d.fastingAt); whiteDays = v(.whiteDays, d.whiteDays)
        personal = v(.personal, d.personal)
        quiet = v(.quiet, d.quiet); quietFrom = v(.quietFrom, d.quietFrom); quietTo = v(.quietTo, d.quietTo)
        snooze = v(.snooze, d.snooze)
    }

    static let key = "notify.config"

    /// Saved settings, or (first run) the old three switches of Settings carried over.
    static func load(_ d: UserDefaults = .standard) -> NotifyConfig {
        if let s = d.string(forKey: key), let c = try? JSONDecoder().decode(NotifyConfig.self, from: Data(s.utf8)) { return c }
        var c = NotifyConfig()
        c.morning = d.bool(forKey: "notify.azkar"); c.evening = c.morning
        c.ayah = d.bool(forKey: "notify.dailyAyah"); c.khatma = d.bool(forKey: "notify.khatma")
        return c
    }

    func save(_ d: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { d.set(String(decoding: data, as: UTF8.self), forKey: Self.key) }
    }
}

// MARK: - Planning (pure, unit tested)

enum NotifyPlanner {
    struct Alert: Equatable {
        let id: String
        let date: Date
        let title: String
        let body: String
        let link: String?
        let silent: Bool
        let isPrayer: Bool
    }

    struct Inputs {
        var place: String
        var zone: TimeZone
        var times: (Date) -> PrayerTimes
        var ayahText: (Date) -> String? = { _ in nil }
        var khatmaWird: (Date) -> String? = { _ in nil }
        var hifzToday: (Date) -> String? = { _ in nil }
        var hijriDay: (Date) -> Int? = { _ in nil }
    }

    static func inQuiet(minute m: Int, from: Int, to: Int) -> Bool {
        from <= to ? (m >= from && m < to) : (m >= from || m < to)
    }

    static func plan(_ c: NotifyConfig, now: Date, days: Int, _ inp: Inputs) -> [Alert] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = inp.zone
        var out: [Alert] = []
        let prayerLink = "\(Route.scheme)://tools/prayer-times"
        for offset in 0..<days {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            let noon = day.addingTimeInterval(12 * 3600)
            let t = inp.times(noon)
            let comps = cal.dateComponents([.year, .month, .day, .weekday], from: noon)
            let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)"
            func at(_ minute: Int) -> Date { cal.date(byAdding: .minute, value: minute, to: day) ?? day }
            func add(_ id: String, _ minute: Int, _ title: String, _ body: String, _ link: String?, silent: Bool = false, prayer: Bool = false) {
                out.append(.init(id: "ayat.\(id).\(key)", date: at(minute), title: title, body: body, link: link, silent: silent, isPrayer: prayer))
            }
            func timeText(_ h: Double) -> String { Num.time(h) }

            for p in NotifyConfig.fivePrayers {
                let a = c.alert(p)
                let m = PrayerTimes.minute(t.hours(p))
                if a.on {
                    add("prayer.\(p.rawValue)", m, "حان وقت صلاة \(p.name)", "\(inp.place) · \(timeText(t.hours(p)))", prayerLink, silent: a.silent, prayer: true)
                    if a.before > 0 { add("pre.\(p.rawValue)", m - a.before, "صلاة \(p.name) بعد \(a.before) دقيقة", "\(inp.place) · \(timeText(t.hours(p)))", prayerLink, prayer: true) }
                    if a.iqama > 0 { add("iqama.\(p.rawValue)", m + a.iqama, "إقامة صلاة \(p.name)", "حان موعد الإقامة الذي حددته (\(a.iqama) دقيقة بعد الأذان)", prayerLink, prayer: true) }
                }
                if c.afterPrayer {
                    add("after.\(p.rawValue)", m + c.afterPrayerDelay + max(0, a.iqama), "الأذكار بعد الصلاة", "أذكار ما بعد السلام من صلاة \(p.name)",
                        Route.azkarLink("الأذكار بعد السلام من الصلاة"))
                }
            }
            if c.wake { add("wake", PrayerTimes.minute(t.fajr) - 20, "أذكار الاستيقاظ", "اقترب الفجر: أذكار الاستيقاظ من النوم", Route.azkarLink("أذكار الاستيقاظ من النوم")) }
            if c.morning { add("morning", PrayerTimes.minute(t.fajr) + c.morningOffset, "أذكار الصباح", "حان وقت أذكار الصباح", Route.azkarLink("أذكار الصباح")) }
            if c.evening { add("evening", PrayerTimes.minute(t.asr) + c.eveningOffset, "أذكار المساء", "حان وقت أذكار المساء", Route.azkarLink("أذكار المساء")) }
            if c.sleep { add("sleep", c.sleepAt, "أذكار النوم", "قبل أن تنام: أذكار النوم", Route.azkarLink("أذكار النوم")) }
            if c.istighfar { add("istighfar", c.istighfarAt, "الاستغفار والتسبيح", "دقيقة للاستغفار والتسبيح", "\(Route.scheme)://tools/tasbih") }
            if c.ayah { add("ayah", c.ayahAt, "آية اليوم", inp.ayahText(noon) ?? "آية اليوم مع تفسيرها", "\(Route.scheme)://tools/ayah-of-the-day") }
            if c.khatma, let w = inp.khatmaWird(noon) { add("khatma", c.khatmaAt, "ورد الختمة", w, "\(Route.scheme)://khatma") }
            if c.hifz, let h = inp.hifzToday(noon) { add("hifz", c.hifzAt, "الحفظ والمراجعة", h, "\(Route.scheme)://tools/hifz-plan") }
            if c.friday, comps.weekday == 6 { add("friday", c.fridayAt, "يوم الجمعة", "قراءة سورة الكهف", Route.ayahLink(18, 1)) }
            if c.fasting, let tw = cal.dateComponents([.weekday], from: noon.addingTimeInterval(86_400)).weekday, tw == 2 || tw == 5 {
                add("fast", c.fastingAt, "تذكير بالصيام", "غدا \(tw == 2 ? "الاثنين" : "الخميس")", "\(Route.scheme)://tools/sawm-tracker")
            }
            if c.whiteDays, let h = inp.hijriDay(noon.addingTimeInterval(86_400)), (13...15).contains(h) {
                add("white", c.fastingAt, "الأيام البيض", "غدا اليوم \(h) من الشهر الهجري", "\(Route.scheme)://tools/sawm-tracker")
            }
            for r in c.personal where r.days.contains(comps.weekday!) {
                add("personal.\(r.id)", r.minute, r.title, "تذكيرك الشخصي", nil)
            }
        }
        var seen = Set<String>()
        return out
            .filter { $0.date > now }
            .filter { a in
                guard c.quiet, !a.isPrayer else { return true }
                let hm = cal.dateComponents([.hour, .minute], from: a.date)
                return !inQuiet(minute: hm.hour! * 60 + hm.minute!, from: c.quietFrom, to: c.quietTo)
            }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Log of delivered notifications

enum NotifyLog {
    static let key = "notify.log"
    struct Entry: Codable, Equatable { let id: String; let date: Date; let title: String }

    static func all(_ d: UserDefaults = .standard) -> [Entry] {
        guard let s = d.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: s)) ?? []
    }

    /// Adds what iOS reports as delivered (newest first, last 50).
    static func collect() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        var list = all()
        let known = Set(list.map(\.id))
        for n in delivered where n.request.identifier.hasPrefix(Reminders.prefix) && !known.contains(n.request.identifier) {
            list.append(.init(id: n.request.identifier, date: n.date, title: n.request.content.title))
        }
        list.sort { $0.date > $1.date }
        if let data = try? JSONEncoder().encode(Array(list.prefix(50))) { UserDefaults.standard.set(data, forKey: key) }
    }
}
