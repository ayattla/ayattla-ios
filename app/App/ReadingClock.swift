import Foundation

/// When the person usually reads (on the device only), same as Android: the minute of day of recent
/// reading sittings, so the wird reminders can come a little before that time.
enum ReadingClock {
    private static let d = UserDefaults.standard
    private static let max = 14

    /// One sample per sitting: turning several pages in a row counts once.
    static func record(now: Date = Date()) {
        let last = d.double(forKey: "reading.clock.last")
        guard now.timeIntervalSince1970 - last >= 45 * 60 else { return }
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let list = Array(samples.suffix(max - 1)) + [(c.hour ?? 0) * 60 + (c.minute ?? 0)]
        d.set(now.timeIntervalSince1970, forKey: "reading.clock.last")
        d.set(list, forKey: "reading.clock.m")
    }

    static var samples: [Int] { (d.array(forKey: "reading.clock.m") as? [Int]) ?? [] }

    /// 15 minutes before the usual reading time, once there are at least 3 sittings.
    static var reminderMinute: Int? { usual(samples).map { ($0 - 15 + 1440) % 1440 } }

    static func usual(_ s: [Int]) -> Int? { s.count < 3 ? nil : s.sorted()[s.count / 2] }
}
