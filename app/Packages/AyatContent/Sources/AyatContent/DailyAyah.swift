import Foundation

/// Ayah of the day: one of the site's common-ayat shortcuts (clip maker and card tool: Al-Fatiha,
/// Ayat al-Kursi, end of Al-Baqarah, Ash-Sharh 5–6, Al-Ikhlas, Al-Mulk, Ar-Ra'd 28), rotating by
/// day. Shared by the app's home and the widget so both show the same ayah. Text comes from the pack.
public enum DailyAyah {
    public struct Pick: Equatable, Sendable {
        public let surah: Int
        public let from: Int
        public let to: Int
        public init(surah: Int, from: Int, to: Int) { self.surah = surah; self.from = from; self.to = to }
    }

    public static let picks: [Pick] = [
        .init(surah: 1, from: 1, to: 7), .init(surah: 2, from: 255, to: 255), .init(surah: 2, from: 285, to: 286),
        .init(surah: 94, from: 5, to: 6), .init(surah: 112, from: 1, to: 4), .init(surah: 67, from: 1, to: 1),
        .init(surah: 13, from: 28, to: 28),
    ]

    public static func pick(for date: Date = Date()) -> Pick {
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .era, for: date) ?? 0
        return picks[day % picks.count]
    }
}
