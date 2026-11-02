import Foundation

/// Qibla bearing and distance, same formulas and Kaaba point as ayattla.com/tools/qibla.
public enum Qibla {
    public static let kaaba = (lat: 21.4225, lng: 39.8262)

    /// Degrees clockwise from true north, 0..<360.
    public static func bearing(lat: Double, lng: Double) -> Double {
        let r = Double.pi / 180
        let p1 = lat * r, p2 = kaaba.lat * r, dl = (kaaba.lng - lng) * r
        let b = atan2(sin(dl), cos(p1) * tan(p2) - sin(p1) * cos(dl)) / r
        return (b + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Great-circle distance in km (haversine, R = 6371).
    public static func distanceKm(lat: Double, lng: Double) -> Double {
        let r = Double.pi / 180
        let p1 = lat * r, p2 = kaaba.lat * r, dp = p2 - p1, dl = (kaaba.lng - lng) * r
        let a = pow(sin(dp / 2), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2), 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
