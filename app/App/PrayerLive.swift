import ActivityKit
import SwiftUI
import AyatDesign
import AyatCalc

/// Starts and renews «الصلاة القادمة على شاشة القفل». iOS keeps a Live Activity up to 8 hours, so it is
/// renewed every time the app opens; once a prayer comes in it shows that the time has come.
enum PrayerLive {
    static let key = "prayer.live"
    static var enabled: Bool { UserDefaults.standard.bool(forKey: key) }
    static var available: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    static func state(now: Date = Date()) -> PrayerAttributes.ContentState {
        let cityName = UserDefaults.standard.string(forKey: "prayer.city") ?? PrayerCity.all[0].name
        let city = PrayerCity.named(cityName) ?? PrayerCity.all[0]
        let place = PrayerTimesView.Place(name: city.name, lat: city.lat, lng: city.lng,
                                          zone: TimeZone(identifier: city.zone) ?? .current, method: city.method)
        let d = PrayerTimesView.Day(place: place, now: now)
        let minuteStart = Calendar.current.date(bySetting: .second, value: 0, of: now) ?? now
        let at = minuteStart.addingTimeInterval(Double(d.next.minutesUntil) * 60)
        let hours = d.next.isTomorrow ? d.tomorrow.fajr : d.today.hours(d.next.prayer)
        return .init(prayer: d.next.prayer.name, time: Num.time(hours), place: place.name, at: at)
    }

    static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: key)
        Task { if on { await refresh() } else { await endAll() } }
    }

    /// Replaces any running activity with one for the next prayer.
    static func refresh() async {
        guard enabled, available else { return }
        let s = state()
        let content = ActivityContent(state: s, staleDate: s.at.addingTimeInterval(60))
        if let a = Activity<PrayerAttributes>.activities.first {
            await a.update(content)
            for extra in Activity<PrayerAttributes>.activities.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else {
            _ = try? Activity.request(attributes: PrayerAttributes(), content: content)
        }
    }

    static func endAll() async {
        for a in Activity<PrayerAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
