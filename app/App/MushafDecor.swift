import SwiftUI
import AyatDesign
import AyatContent

/// The reading backgrounds of the Quran pages: calm, flat tones (no patterns), like the reading themes
/// of the leading mushaf apps. Night follows dark mode. Same four as Android.
enum MushafTheme: String, CaseIterable, Identifiable {
    case paper, white, green
    var id: String { rawValue }
    static let key = "mushaf.theme"
    var label: String { switch self { case .paper: "ورقي"; case .white: "أبيض"; case .green: "أخضر هادئ" } }
    /// page, backdrop, gold, ink, band
    var colors: (UInt32, UInt32, UInt32, UInt32, UInt32) {
        switch self {
        case .paper: (0xFCF8EE, 0xF4EFE2, 0xB08A3E, 0x1B1A16, 0xF2EBDA)
        case .white: (0xFFFFFF, 0xF1F3F2, 0x9C8350, 0x1A1F1C, 0xF5F2EA)
        case .green: (0xF4F8F2, 0xE5EEE3, 0x427E45, 0x102D27, 0xE3EEE1)
        }
    }
    static var current: MushafTheme { MushafTheme(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .paper }
}

enum MushafStyle {
    static var gold: Color { Color(light: MushafTheme.current.colors.2, dark: 0xC9A75F) }
    static var paper: Color { Color(light: MushafTheme.current.colors.0, dark: 0x14211C) }
    static var backdrop: Color { Color(light: MushafTheme.current.colors.1, dark: 0x0D1713) }
    static var ink: Color { Color(light: MushafTheme.current.colors.3, dark: 0xECE8DC) }
    static var band: Color { Color(light: MushafTheme.current.colors.4, dark: 0x1C3A2E) }
}

/// Picks the page background; shown in the reader's toolbar.
struct MushafThemeMenu: View {
    @AppStorage(MushafTheme.key) private var theme = MushafTheme.paper.rawValue
    var body: some View {
        Menu {
            Picker("خلفية المصحف", selection: $theme) {
                ForEach(MushafTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
        } label: {
            Image(systemName: "paintpalette")
        }
        .accessibilityLabel("خلفية المصحف")
    }
}

/// Double gold rule with soft corner brackets, drawn behind a mushaf page.
struct MushafBorder: View {
    var body: some View {
        Canvas { ctx, size in
            let o: CGFloat = 6, i: CGFloat = 11
            ctx.stroke(Path(roundedRect: CGRect(x: o, y: o, width: size.width - 2 * o, height: size.height - 2 * o), cornerRadius: 12),
                       with: .color(MushafStyle.gold), lineWidth: 1.6)
            ctx.stroke(Path(roundedRect: CGRect(x: i, y: i, width: size.width - 2 * i, height: size.height - 2 * i), cornerRadius: 8),
                       with: .color(MushafStyle.gold.opacity(0.55)), lineWidth: 0.8)
            // Soft gold brackets at the corners (the modern replacement for corner stars).
            let c: CGFloat = 2, len: CGFloat = 22, w = size.width, h = size.height
            for (x, y, dx, dy) in [(c, c, 1.0, 1.0), (w - c, c, -1.0, 1.0), (c, h - c, 1.0, -1.0), (w - c, h - c, -1.0, -1.0)] {
                var p = Path()
                p.move(to: CGPoint(x: x, y: y + dy * len)); p.addLine(to: CGPoint(x: x, y: y + dy * len * 0.25))
                p.addQuadCurve(to: CGPoint(x: x + dx * len * 0.25, y: y), control: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + dx * len, y: y))
                ctx.stroke(p, with: .color(MushafStyle.gold), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The surah title in a soft framed capsule, with its place of revelation and ayah count.
struct SurahCartouche: View {
    let surah: Surah
    var scale: Double = 1

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Canvas { ctx, size in
                    // A soft capsule with a fine double gold rule and a dot at each end.
                    let h = size.height, w = size.width, r = h / 2, i: CGFloat = 5
                    let outer = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: r)
                    ctx.fill(outer, with: .color(MushafStyle.band))
                    ctx.stroke(outer, with: .color(MushafStyle.gold), lineWidth: 1.4)
                    ctx.stroke(Path(roundedRect: CGRect(x: i, y: i, width: w - 2 * i, height: h - 2 * i), cornerRadius: r - i),
                               with: .color(MushafStyle.gold.opacity(0.45)), lineWidth: 0.8)
                    for x in [r * 0.9, w - r * 0.9] {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: h / 2 - 3, width: 6, height: 6)), with: .color(MushafStyle.gold))
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

/// Page number in a small gold-ruled pill.
struct PageMedallion: View {
    let number: Int
    var body: some View {
        Text(Num.int(number)).font(.ui(.caption2, .bold)).foregroundStyle(MushafStyle.gold)
            .padding(.horizontal, 14).frame(minHeight: 26)
            .background(MushafStyle.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(MushafStyle.gold, lineWidth: 1))
            .accessibilityLabel("صفحة \(number)")
    }
}
