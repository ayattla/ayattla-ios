import SwiftUI
import AyatDesign
import AyatCalc

/// Qibla direction, per design/Qibla.dc.html. Uses the device location, or the city chosen
/// in prayer times when location is unavailable.
struct QiblaView: View {
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name
    @State private var location = LocationService()

    var body: some View {
        let city = PrayerCity.named(cityName) ?? PrayerCity.all[0]
        let coord = location.coordinate
        let name = coord == nil ? city.name : "موقعي"
        let lat = coord?.latitude ?? city.lat, lng = coord?.longitude ?? city.lng
        let bearing = Qibla.bearing(lat: lat, lng: lng)
        let km = Qibla.distanceKm(lat: lat, lng: lng)
        let heading = location.heading
        let aligned = heading.map { Self.angleDiff(bearing, $0) < 5 } ?? false

        ScrollView {
            VStack(spacing: 16) {
                Text("\(name) · \(Num.int(Int(km.rounded()))) كم إلى مكة")
                    .font(.ui(.subheadline)).foregroundStyle(.secondary)
                Text("\(Num.decimal(bearing))°")
                    .font(.ui(size: 44, .semibold))
                    .foregroundStyle(Brand.primaryInk)
                    .accessibilityLabel("زاوية القبلة \(Num.decimal(bearing)) درجة من الشمال")
                QiblaCompass(dialRotation: -(heading ?? 0), bearing: bearing)
                    .frame(width: 300, height: 300)
                    .animation(.easeOut(duration: 0.2), value: heading)
                if aligned {
                    Text("أنت باتجاه القبلة")
                        .font(.ui(.headline)).foregroundStyle(.white)
                        .padding(.horizontal, 20).frame(minHeight: Brand.minTap)
                        .background(Brand.primary, in: Capsule())
                }
                Text(heading == nil
                     ? "البوصلة غير متاحة على هذا الجهاز. الزاوية مقيسة من الشمال باتجاه عقارب الساعة."
                     : "أبعد الهاتف عن المعادن والمغناطيس، وضعه مستويا.")
                    .font(.ui(.footnote)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Brand.background)
        .brandScreen()
        .navigationTitle("اتجاه القبلة")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { location.requestLocation(); location.startHeading() }
        .onDisappear { location.stopHeading() }
    }

    /// Smallest absolute difference between two bearings, 0...180.
    static func angleDiff(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return d > 180 ? 360 - d : d
    }
}

/// Dial with N/E/S/W rotated by `dialRotation` (minus the compass heading), and the needle at
/// `bearing` on the dial. Drawn left-to-right so east stays on the right in RTL.
struct QiblaCompass: View {
    let dialRotation: Double
    let bearing: Double

    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let r = side / 2
            ZStack {
                Circle().fill(Brand.surface)
                Circle().stroke(Brand.line, lineWidth: 2)
                Circle().inset(by: r * 0.2).stroke(Brand.tint, lineWidth: 14)
                ForEach(Self.cardinals, id: \.0) { label, deg in
                    Text(label)
                        .font(.system(size: 16, weight: deg == 0 ? .semibold : .regular))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(-dialRotation))
                        .offset(x: r * 0.8 * sin(deg * .pi / 180), y: -r * 0.8 * cos(deg * .pi / 180))
                }
                ZStack {
                    Needle(tip: 0.70).fill(Brand.primary)
                    Needle(tip: -0.70).fill(Color(hex: 0xCFE2D3))
                    VStack(spacing: 0) {
                        Rectangle().fill(Color(hex: 0x1C2B20)).frame(height: 6)
                        Rectangle().fill(Color(hex: 0xC8A84E)).frame(height: 3)
                        Rectangle().fill(Color(hex: 0x1C2B20)).frame(height: 13)
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(y: -r * 0.77)
                }
                .rotationEffect(.degrees(bearing))
                Circle().fill(Brand.surface).frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Brand.primary, lineWidth: 3))
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(dialRotation))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("بوصلة تشير إلى القبلة")
    }

    static let cardinals: [(String, Double)] = [("ش", 0), ("ق", 90), ("ج", 180), ("غ", 270)]
}

/// Kite-shaped half needle from the centre; `tip` is a fraction of the radius (negative points down).
struct Needle: Shape {
    let tip: Double
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2
        let w = r * 0.11, back = tip > 0 ? r * 0.07 : -r * 0.07
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r * tip))
        p.addLine(to: CGPoint(x: c.x + w, y: c.y))
        p.addLine(to: CGPoint(x: c.x, y: c.y - back))
        p.addLine(to: CGPoint(x: c.x - w, y: c.y))
        p.closeSubpath()
        return p
    }
}
