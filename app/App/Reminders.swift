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
                                 body: "حان وقت أذكار الصباح", date: at(hours: t.fajr + azkarOffsetMinutes / 60)))
                out.append(.init(id: "\(prefix)azkar.evening.\(key)", title: "أذكار المساء",
                                 body: "حان وقت أذكار المساء", date: at(hours: t.asr + azkarOffsetMinutes / 60)))
            }
            if dailyAyah {
                let pick = AyahOfTheDay.pick(for: day.addingTimeInterval(12 * 3600))
                let ref = AyahOfTheDay.reference(pick)
                let body = ayahText(pick).map { "\($0)\n\(ref)" } ?? ref
                out.append(.init(id: "\(prefix)ayah.\(key)", title: "آية اليوم", body: body,
                                 date: at(hours: Double(ayahHour))))
            }
            if let k = khatma {
                let d = k.day(on: day.addingTimeInterval(12 * 3600), calendar: cal)
                if !k.completedDays.contains(d), let r = k.range(day: d) {
                    out.append(.init(id: "\(prefix)khatma.\(key)", title: "ورد الختمة",
                                     body: "ورد اليوم: من صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound))",
                                     date: at(hours: Double(khatmaHour))))
                }
            }
        }
        return out.filter { $0.date > now }
    }

    /// Replaces every pending reminder of ours with a fresh plan from the saved settings.
    static func reschedule(defaults d: UserDefaults = .standard) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let azkar = d.bool(forKey: Prefs.notifyAzkar), ayah = d.bool(forKey: Prefs.notifyDailyAyah)
        let khatmaOn = d.bool(forKey: Prefs.notifyKhatma)
        guard azkar || ayah || khatmaOn else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let city = PrayerCity.named(d.string(forKey: "prayer.city") ?? "") ?? PrayerCity.all[0]
        let khatma = khatmaOn ? KhatmaStore.load(d.string(forKey: KhatmaStore.key) ?? "") : nil
        let store = ContentLibrary.shared.store
        let items = plan(now: Date(), azkar: azkar, dailyAyah: ayah, khatma: khatma, city: city) { p in
            (try? store?.ayat(surah: p.surah, from: p.from, to: p.from))?.first?.textUthmani
        }
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(identifier: item.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(request)
        }
    }
}
