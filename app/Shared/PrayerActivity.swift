import ActivityKit
import Foundation

/// Live Activity «الصلاة القادمة»: the next prayer with a live countdown on the Lock Screen and in the
/// Dynamic Island. Started by the app (PrayerLive) and drawn by the widget.
struct PrayerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var prayer: String
        var time: String
        var place: String
        var at: Date
    }
}
