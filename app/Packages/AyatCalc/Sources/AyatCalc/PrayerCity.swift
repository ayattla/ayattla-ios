import Foundation

/// A city from the city menu of ayattla.com/tools/prayer-times, with the calculation
/// settings the site uses for it. Read from the live site on 2026-11-02 (tools/golden/cities.txt).
public struct PrayerCity: Hashable, Sendable, Identifiable {
    public let name: String
    public let lat: Double
    public let lng: Double
    public let zone: String
    public let method: PrayerTimes.Method
    public var id: String { name }

    public static func named(_ name: String) -> PrayerCity? { all.first { $0.name == name } }

    public static let all: [PrayerCity] = [
        .init(name: "الرياض", lat: 24.7136, lng: 46.6753, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "مكة المكرمة", lat: 21.4225, lng: 39.8262, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "المدينة المنورة", lat: 24.4672, lng: 39.6111, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "جدة", lat: 21.5433, lng: 39.1728, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "الدمام", lat: 26.4207, lng: 50.0888, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "الخبر", lat: 26.2794, lng: 50.2083, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "الطائف", lat: 21.2703, lng: 40.4158, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "تبوك", lat: 28.3838, lng: 36.555, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "بريدة", lat: 26.3592, lng: 43.9818, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "أبها", lat: 18.2164, lng: 42.5053, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "حائل", lat: 27.5114, lng: 41.7208, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "جازان", lat: 16.8892, lng: 42.5511, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "نجران", lat: 17.4924, lng: 44.1277, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "الأحساء", lat: 25.3833, lng: 49.5833, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "ينبع", lat: 24.089, lng: 38.0618, zone: "Asia/Riyadh", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "دبي", lat: 25.2048, lng: 55.2708, zone: "Asia/Dubai", method: .init(fajrAngle: 18.2, isha: 18.2)),
        .init(name: "أبوظبي", lat: 24.4539, lng: 54.3773, zone: "Asia/Dubai", method: .init(fajrAngle: 18.2, isha: 18.2)),
        .init(name: "الكويت", lat: 29.3759, lng: 47.9774, zone: "Asia/Kuwait", method: .init(fajrAngle: 18, isha: 17.5)),
        .init(name: "الدوحة", lat: 25.2854, lng: 51.531, zone: "Asia/Qatar", method: .init(fajrAngle: 18, isha: 90)),
        .init(name: "المنامة", lat: 26.2285, lng: 50.586, zone: "Asia/Bahrain", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "مسقط", lat: 23.588, lng: 58.3829, zone: "Asia/Muscat", method: .init(fajrAngle: 18, isha: 18)),
        .init(name: "القاهرة", lat: 30.0444, lng: 31.2357, zone: "Africa/Cairo", method: .init(fajrAngle: 19.5, isha: 17.5)),
        .init(name: "الإسكندرية", lat: 31.2001, lng: 29.9187, zone: "Africa/Cairo", method: .init(fajrAngle: 19.5, isha: 17.5)),
        .init(name: "عمان", lat: 31.9539, lng: 35.9106, zone: "Asia/Amman", method: .init(fajrAngle: 18, isha: 18)),
        .init(name: "بغداد", lat: 33.3152, lng: 44.3661, zone: "Asia/Baghdad", method: .init(fajrAngle: 18, isha: 17)),
        .init(name: "بيروت", lat: 33.8938, lng: 35.5018, zone: "Asia/Beirut", method: .init(fajrAngle: 18, isha: 17)),
        .init(name: "دمشق", lat: 33.5138, lng: 36.2765, zone: "Asia/Damascus", method: .init(fajrAngle: 18, isha: 17)),
        .init(name: "القدس", lat: 31.7683, lng: 35.2137, zone: "Asia/Jerusalem", method: .init(fajrAngle: 18, isha: 17)),
        .init(name: "صنعاء", lat: 15.3694, lng: 44.191, zone: "Asia/Aden", method: .init(fajrAngle: 18.5, isha: 90)),
        .init(name: "الخرطوم", lat: 15.5007, lng: 32.5599, zone: "Africa/Khartoum", method: .init(fajrAngle: 19.5, isha: 17.5)),
        .init(name: "الدار البيضاء", lat: 33.5731, lng: -7.5898, zone: "Africa/Casablanca", method: .init(fajrAngle: 19, isha: 17)),
        .init(name: "الرباط", lat: 34.0209, lng: -6.8416, zone: "Africa/Casablanca", method: .init(fajrAngle: 19, isha: 17)),
        .init(name: "الجزائر", lat: 36.7538, lng: 3.0588, zone: "Africa/Algiers", method: .init(fajrAngle: 18, isha: 17)),
        .init(name: "تونس", lat: 36.8065, lng: 10.1815, zone: "Africa/Tunis", method: .init(fajrAngle: 18, isha: 18)),
        .init(name: "طرابلس", lat: 32.8872, lng: 13.1913, zone: "Africa/Tripoli", method: .init(fajrAngle: 18, isha: 17)),
        .init(name: "نواكشوط", lat: 18.0735, lng: -15.9582, zone: "Africa/Nouakchott", method: .init(fajrAngle: 18, isha: 17)),
    ]
}
