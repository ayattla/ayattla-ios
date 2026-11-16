import Foundation
import UserNotifications
import AyatCalc
import AyatDesign

/// Local reminders from Settings → التنبيهات. Scheduled on the device for the next 7 days and
/// refreshed whenever the app becomes active or a setting changes.
///  - Azkar: morning 30 min after Fajr, evening 30 min after Asr, for the city chosen in prayer times.
///  - Ayah of the day: 9:00.
///  - Khatma wird: 20:00, while a plan is running and that day is not marked done.
enum Reminders {
    static let prefix = "ayat."
    static let daysAhead = 7
    static let azkarOffsetMinutes = 30.0
    static let ayahHour = 9
    static let khatmaHour = 20

    struct Item: Equatable {
        let id: String
        let title: String
        let body: String
        let date: Date
        var link: String? = nil
    }

    /// Pure planning, so it can be tested without the notification center.
    static func plan(now: Date, azkar: Bool, dailyAyah: Bool, khatma: KhatmaPlan?, city: PrayerCity,
                     ayahText: (AyahOfTheDay.Pick) -> String?) -> [Item] {
        var cal = Calendar(identifier: .gregorian)
        let zone = TimeZone(identifier: city.zone) ?? .current
        cal.timeZone = zone
        var out: [Item] = []
        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: day)
            let key = "\(c.year!)-\(c.month!)-\(c.day!)"
            func at(hours: Double) -> Date { day.addingTimeInterval(hours * 3600) }
            if azkar {
                let t = PrayerTimes.compute(year: c.year!, month: c.month!, day: c.day!, lat: city.lat, lng: city.lng,
                                            tzHours: PrayerTimes.tzHours(zone, at: day), method: city.method,
                                            ramadan: Hijri.isRamadan(day))
                out.append(.init(id: "\(prefix)azkar.morning.\(key)", title: "أذكار الصباح",
                                 body: "حان وقت أذكار الصباح", date: at(hours: t.fajr + azkarOffsetMinutes / 60),
                                 link: Route.azkarLink("أذكار الصباح")))
                out.append(.init(id: "\(prefix)azkar.evening.\(key)", title: "أذكار المساء",
                                 body: "حان وقت أذكار المساء", date: at(hours: t.asr + azkarOffsetMinutes / 60),
                                 link: Route.azkarLink("أذكار المساء")))
            }
            if dailyAyah {
                let pick = AyahOfTheDay.pick(for: day.addingTimeInterval(12 * 3600))
                let ref = AyahOfTheDay.reference(pick)
                let body = ayahText(pick).map { "\($0)\n\(ref)" } ?? ref
                out.append(.init(id: "\(prefix)ayah.\(key)", title: "آية اليوم", body: body,
                                 date: at(hours: Double(ayahHour)), link: Route.ayahLink(pick.surah, pick.from)))
            }
            if let k = khatma {
                let d = k.day(on: day.addingTimeInterval(12 * 3600), calendar: cal)
                if !k.completedDays.contains(d), let r = k.range(day: d) {
                    out.append(.init(id: "\(prefix)khatma.\(key)", title: "ورد الختمة",
                                     body: "ورد اليوم: من صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound))",
                                     date: at(hours: Double(khatmaHour)), link: "\(Route.scheme)://khatma"))
                }
            }
        }
        return out.filter { $0.date > now }
    }

    /// iOS keeps at most 64 pending notifications per app: the earliest 60 are set, and the plan is
    /// renewed every time the app becomes active, a setting changes or a notification is tapped.
    static let maxPending = 60
    static let category = "ayat.alert"

    /// What the notification center will schedule (also shown in its «المجدولة القادمة»).
    static func upcoming(defaults d: UserDefaults = .standard, now: Date = Date()) -> [NotifyPlanner.Alert] {
        let config = NotifyConfig.load(d)
        guard config.anyOn else { return [] }
        let city = PrayerCity.named(d.string(forKey: "prayer.city") ?? "") ?? PrayerCity.all[0]
        let zone = TimeZone(identifier: city.zone) ?? .current
        let khatma = KhatmaStore.load(d.string(forKey: KhatmaStore.key) ?? "")
        let hifz = HifzPlan.decode(d.string(forKey: "hifz.plan") ?? "")
        let store = ContentLibrary.shared.store
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let inputs = NotifyPlanner.Inputs(
            place: city.name, zone: zone,
            times: { day in PrayerCalc.times(on: day, lat: city.lat, lng: city.lng, zone: zone, method: city.method, d) },
            ayahText: { day in
                let p = AyahOfTheDay.pick(for: day)
                let ref = AyahOfTheDay.reference(p)
                return ((try? store?.ayat(surah: p.surah, from: p.from, to: p.from))?.first?.textUthmani).map { "\($0)\n\(ref)" } ?? ref
            },
            khatmaWird: { day in
                guard let k = khatma else { return nil }
                let n = k.day(on: day, calendar: cal)
                guard !k.completedDays.contains(n), let r = k.range(day: n) else { return nil }
                return "ورد اليوم: من صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound))"
            },
            hifzToday: { _ in hifz == nil ? nil : "مقطع اليوم ومراجعاتك في خطة الحفظ" },
            hijriDay: { day in Hijri.fromGregorian(day).day }
        )
        return Array(NotifyPlanner.plan(config, now: now, days: 7, inputs).prefix(maxPending))
    }

    /// Replaces every pending notification of ours with a fresh plan from the saved settings.
    static func reschedule(defaults d: UserDefaults = .standard) async {
        let center = UNUserNotificationCenter.current()
        await NotifyLog.collect()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let snooze = NotifyConfig.load(d).snooze
        center.setNotificationCategories([UNNotificationCategory(
            identifier: category,
            actions: [UNNotificationAction(identifier: "snooze", title: "أجّل \(Num.int(snooze)) دقائق")],
            intentIdentifiers: [])])
        for item in upcoming(defaults: d) { try? await add(item, at: item.date) }
    }

    static func add(_ item: NotifyPlanner.Alert, at date: Date, idSuffix: String = "") async throws {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = item.silent ? nil : .default
        content.categoryIdentifier = category
        content.threadIdentifier = item.isPrayer ? "prayer" : "other"
        var info: [String: Any] = ["title": item.title, "body": item.body, "silent": item.silent, "prayer": item.isPrayer]
        if let link = item.link { info["link"] = link }
        content.userInfo = info
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: item.id + idSuffix, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    /// «أجّل» on a notification: the same notification again after the chosen minutes.
    static func snooze(_ request: UNNotificationRequest) async {
        let info = request.content.userInfo
        let mins = NotifyConfig.load().snooze
        let item = NotifyPlanner.Alert(id: request.identifier, date: Date().addingTimeInterval(Double(mins) * 60),
                                       title: info["title"] as? String ?? request.content.title, body: info["body"] as? String ?? request.content.body,
                                       link: info["link"] as? String, silent: info["silent"] as? Bool ?? false, isPrayer: info["prayer"] as? Bool ?? false)
        try? await add(item, at: item.date, idSuffix: ".snooze")
    }

    /// «تنبيه تجريبي»: arrives in five seconds.
    static func test() async {
        let content = UNMutableNotificationContent()
        content.title = "تنبيه تجريبي"
        content.body = "هكذا تصلك تنبيهات آيات تتلى."
        content.sound = .default
        content.categoryIdentifier = category
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "\(prefix)test.\(Int(Date().timeIntervalSince1970))", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
