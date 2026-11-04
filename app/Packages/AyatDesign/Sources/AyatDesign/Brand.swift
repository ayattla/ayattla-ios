import SwiftUI

/// Brand tokens taken from ayattla.com's live stylesheet (November 2026): the page layer `--s-*`
/// (white and mint surfaces, green #2E9145, green→teal gradient, card shadow) over the base layer
/// `--c-*` (deep emerald #102D27, gold #C3A66B). Light and dark values are the site's own
/// (`[data-theme=dark]`). IBM Plex Sans Arabic for the interface, Amiri Quran for the Quran.
public enum Brand {
    // Green (--s-green, --s-green-d) and the deep emerald of the base layer (--c-primary).
    public static let green = Color(light: 0x2E9145, dark: 0x4CBF63)
    public static let greenDeep = Color(light: 0x23753A, dark: 0x6BD07F)
    public static let teal = Color(hex: 0x0F7E86)
    public static let g0 = Color(light: 0x17392F, dark: 0x143128)            // --gradient-brand start
    public static let primary = Color(light: 0x102D27, dark: 0x1B4238)       // dark buttons, emerald cards
    public static let primaryInk = Color(light: 0x23753A, dark: 0x6BD07F)    // links and selected text (--s-green-d)
    public static let deep = Color(light: 0x0B211C, dark: 0x0A1814)          // --gradient-brand end
    // Gold (--c-accent, --c-accent-ink, --c-accent-soft) and the site's "جديد" badge colours.
    public static let accent = Color(light: 0xC3A66B, dark: 0xD9C28E)
    public static let goldInk = Color(light: 0x7A5F28, dark: 0xD9C28E)
    public static let goldSoft = Color(light: 0xF1E8D3, dark: 0x2A2A1C)
    public static let newInk = Color(light: 0x8A5A0F, dark: 0xE2B04A)
    public static let newFill = Color(light: 0xF9EED8, dark: 0x2B2414)       // rgba(226,176,74,.18) on white
    public static let onDeepAccent = Color(hex: 0xD9C28E)                   // gold text on emerald
    // Surfaces (--s-bg, --s-soft, --s-card, --s-line) and text (--s-ink, --s-muted).
    public static let background = Color(light: 0xF4F8F5, dark: 0x0B120E)
    public static let page = Color(light: 0xFFFFFF, dark: 0x0B120E)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x121D16)
    public static let surface2 = Color(light: 0xF4F8F5, dark: 0x111B15)
    public static let ink = Color(light: 0x0F1F17, dark: 0xEAF2EC)
    public static let onPrimary = Color(hex: 0xFFFFFF)
    public static let tint = Color(light: 0xE6F2E9, dark: 0x16271C)          // rgba(46,145,69,.12) on white
    public static let line = Color(light: 0xE3EBE5, dark: 0x223429)
    public static let lineStrong = Color(light: 0xCFDCD3, dark: 0x2E4536)
    public static let muted = Color(light: 0x5A6B61, dark: 0xA3B5A9)
    public static let dotOff = Color(light: 0xCFDCD3, dark: 0x2E4536)
    // Shape (--rad-s, --rad-m, --rad-l)
    public static let radiusCard: CGFloat = 18
    public static let radiusSmall: CGFloat = 12
    public static let minTap: CGFloat = 44

    /// --gradient-brand: deep emerald, for Quran cards and dark panels.
    public static var gradient: LinearGradient {
        LinearGradient(colors: [g0, primary, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// --s-grad: the site's main green→teal gradient (primary buttons, selected states, stats).
    public static var siteGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x2E9145), Color(hex: 0x1F8A62), Color(hex: 0x0F7E86)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// .btn.gold: the gold gradient of the site's "create" buttons.
    public static var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xB7791F), Color(hex: 0xE2B04A)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Icon tile gradients in the site's order (`.tools a:nth-child(5n+k) .ico`).
    public static let tileGradients: [[UInt32]] = [
        [0x2E9145, 0x0F7E86],   // 5n+1  --s-grad
        [0x0F7E86, 0x3BB3B0],   // 5n+2  teal
        [0xB7791F, 0xE2B04A],   // 5n+3  gold
        [0x1D5D8C, 0x4F9BD1],   // 5n+4  blue
        [0x1FA855, 0x8AD16A],   // 5n    fresh green
    ]

    public static func tileGradient(_ index: Int) -> LinearGradient {
        let c = tileGradients[((index % 5) + 5) % 5]
        return LinearGradient(colors: c.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Interface font family (registered at launch from the bundled OFL files).
    public static let uiFamily = "IBM Plex Sans Arabic"
}

public extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    /// A color that switches with light and dark mode.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
        #else
        self.init(hex: light)
        #endif
    }

    /// Card surface (--c-surface): white on ivory in light mode, deep emerald in dark mode.
    static var cardSurface: Color { Brand.surface }
}

public extension Font {
    /// IBM Plex Sans Arabic at the size of a system text style; follows Dynamic Type.
    static func ui(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
        let (size, defaultWeight): (CGFloat, Font.Weight) = {
            switch style {
            case .largeTitle: (34, .semibold)
            case .title: (28, .semibold)
            case .title2: (22, .semibold)
            case .title3: (20, .medium)
            case .headline: (17, .semibold)
            case .callout: (16, .regular)
            case .subheadline: (15, .regular)
            case .footnote: (13, .regular)
            case .caption: (12, .regular)
            case .caption2: (11, .regular)
            default: (17, .regular)
            }
        }()
        return .custom(face(weight ?? defaultWeight), size: size, relativeTo: style)
    }

    /// Fixed-size interface font (for drawn cards and video frames).
    static func ui(size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(face(weight), size: size)
    }

    private static func face(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black: "IBMPlexSansArabic-Bold"
        case .semibold: "IBMPlexSansArabic-SemiBold"
        case .medium: "IBMPlexSansArabic-Medium"
        default: "IBMPlexSansArabic-Regular"
        }
    }
}

public extension View {
    /// Card per the site: --c-surface, 1px --c-line border, radius 20, soft layered shadow (v2 raised).
    func card() -> some View {
        clipShape(RoundedRectangle(cornerRadius: Brand.radiusCard, style: .continuous))
            .surface(.raised)
    }

    /// The site's emerald panel with the gold frame line (--frame), for hero cards. Now drawn by
    /// the v2 hero surface (gradient, star lattice, light and frame).
    func emeraldPanel(radius: CGFloat = 24) -> some View {
        heroSurface(radius: radius)
    }

    /// Screen background: ivory (dark: deep emerald) behind lists, forms and scroll views, with
    /// the faint star lattice under the navigation bar (v2), so every screen shares the backdrop.
    func brandScreen() -> some View {
        patternedScreen()
    }
}
