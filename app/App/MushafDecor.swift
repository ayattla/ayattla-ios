import SwiftUI
import AyatDesign
import AyatContent

/// Mushaf gold and ink for light and dark reading.
enum MushafStyle {
    static let gold = Color(light: 0xB08A3E, dark: 0xC9A75F)
    static let paper = Color(light: 0xFCF8EE, dark: 0x14211C)
    static let ink = Color(light: 0x1B1A16, dark: 0xECE8DC)
    static let band = Color(light: 0xE8F1EA, dark: 0x1C3A2E)
}

/// Double gold rule with eight-point stars at the corners, drawn behind a mushaf page.
struct MushafBorder: View {
    var body: some View {
        Canvas { ctx, size in
            let o: CGFloat = 6, i: CGFloat = 11
            ctx.stroke(Path(roundedRect: CGRect(x: o, y: o, width: size.width - 2 * o, height: size.height - 2 * o), cornerRadius: 12),
                       with: .color(MushafStyle.gold), lineWidth: 1.6)
            ctx.stroke(Path(roundedRect: CGRect(x: i, y: i, width: size.width - 2 * i, height: size.height - 2 * i), cornerRadius: 8),
                       with: .color(MushafStyle.gold.opacity(0.55)), lineWidth: 0.8)
            for c in [CGPoint(x: o + 2, y: o + 2), CGPoint(x: size.width - o - 2, y: o + 2),
                      CGPoint(x: o + 2, y: size.height - o - 2), CGPoint(x: size.width - o - 2, y: size.height - o - 2)] {
                let s = StarShape().path(in: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14))
                ctx.fill(s, with: .color(MushafStyle.paper))
                ctx.stroke(s, with: .color(MushafStyle.gold), lineWidth: 1.2)
                ctx.fill(StarShape().path(in: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(MushafStyle.gold))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The surah title as a framed cartouche with star ends, with its place of revelation and ayah count.
struct SurahCartouche: View {
    let surah: Surah
    var scale: Double = 1

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Canvas { ctx, size in
                    let h = size.height, w = size.width, cut = h * 0.5
                    var band = Path()
                    band.move(to: CGPoint(x: cut, y: 0)); band.addLine(to: CGPoint(x: w - cut, y: 0)); band.addLine(to: CGPoint(x: w, y: h / 2))
                    band.addLine(to: CGPoint(x: w - cut, y: h)); band.addLine(to: CGPoint(x: cut, y: h)); band.addLine(to: CGPoint(x: 0, y: h / 2)); band.closeSubpath()
                    ctx.fill(band, with: .color(MushafStyle.band))
                    ctx.stroke(band, with: .color(MushafStyle.gold), lineWidth: 1.6)
                    let inset: CGFloat = 5
                    var inner = Path()
                    inner.move(to: CGPoint(x: cut + inset, y: inset)); inner.addLine(to: CGPoint(x: w - cut - inset, y: inset))
                    inner.addLine(to: CGPoint(x: w - inset * 1.6, y: h / 2)); inner.addLine(to: CGPoint(x: w - cut - inset, y: h - inset))
                    inner.addLine(to: CGPoint(x: cut + inset, y: h - inset)); inner.addLine(to: CGPoint(x: inset * 1.6, y: h / 2)); inner.closeSubpath()
                    ctx.stroke(inner, with: .color(MushafStyle.gold.opacity(0.5)), lineWidth: 0.8)
                    for x in [cut * 0.95, w - cut * 0.95] {
                        let r1 = h * 0.17, r2 = h * 0.27
                        ctx.fill(StarShape().path(in: CGRect(x: x - r1, y: h / 2 - r1, width: r1 * 2, height: r1 * 2)), with: .color(MushafStyle.gold))
                        ctx.stroke(StarShape().path(in: CGRect(x: x - r2, y: h / 2 - r2, width: r2 * 2, height: r2 * 2)), with: .color(MushafStyle.gold), lineWidth: 1)
                    }
                }
                Text(surah.namePlain)
                    .font(.custom(ContentLibrary.mushafFont, size: 22 * scale, relativeTo: .title3))
                    .foregroundStyle(MushafStyle.ink)
                    .padding(.horizontal, 70)
            }
            .frame(minHeight: 60)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text([surah.revelationAr, "آياتها \(Num.int(surah.ayahCount))"].compactMap { $0 }.joined(separator: " · "))
                .font(.ui(.caption, .medium)).foregroundStyle(MushafStyle.gold)
        }
        .padding(.vertical, 6)
    }
}

extension Surah {
    var revelationAr: String? {
        switch revelation?.lowercased() {
        case "meccan", "makkah", "mecca", "مكية": "مكية"
        case "medinan", "madinah", "medina", "مدنية": "مدنية"
        default: nil
        }
    }
}

/// Page number in a small eight-point medallion.
struct PageMedallion: View {
    let number: Int
    var body: some View {
        ZStack {
            StarShape().fill(MushafStyle.paper)
            StarShape().stroke(MushafStyle.gold, lineWidth: 1.2)
            Text(Num.int(number)).font(.ui(.caption2, .bold)).foregroundStyle(MushafStyle.gold)
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel("صفحة \(number)")
    }
}
