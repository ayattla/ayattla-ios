import SwiftUI

/// Brand tokens from ayattla.com (styles/tokens.css and the home page theme): deep emerald, gold
/// and ivory, IBM Plex Sans Arabic for the interface and Amiri Quran for the Quran text.
public enum Brand {
    // Emerald
    public static let g0 = Color(light: 0x17392F, dark: 0x143128)            // gradient start (--gradient-brand)
    public static let primary = Color(light: 0x102D27, dark: 0x1B4238)       // fills with ivory text
    public static let primaryInk = Color(light: 0x14463A, dark: 0xD9C28E)    // links, small accent text (AA in both modes)
    public static let deep = Color(light: 0x0B211C, dark: 0x0A1814)          // gradient end
    // Gold
    public static let accent = Color(light: 0xC3A66B, dark: 0xD9C28E)
    public static let goldInk = Color(light: 0x7A5F28, dark: 0xD9C28E)
    public static let goldSoft = Color(light: 0xF1E8D3, dark: 0x2A3A2C)
    public static let onDeepAccent = Color(hex: 0xD9C28E)                   // gold text on emerald
    // Ivory and surfaces
    public static let background = Color(light: 0xF6F2E9, dark: 0x0C1C18)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x11261F)
    public static let surface2 = Color(light: 0xEFE9DC, dark: 0x173129)
    public static let ink = Color(light: 0x202823, dark: 0xF1ECE1)
    public static let onPrimary = Color(hex: 0xF6F2E9)
    public static let tint = Color(light: 0xE4ECE6, dark: 0x1E3A30)          // --c-primary-soft
    public static let line = Color(light: 0xE3EBE5, dark: 0x22392F)
    public static let lineStrong = Color(light: 0xCFDCD3, dark: 0x2E4A3E)
    public static let muted = Color(light: 0x5C625D, dark: 0xB9B3A5)
    public static let dotOff = Color(light: 0xCFDCD3, dark: 0x2E4A3E)
    // Shape
    public static let radiusCard: CGFloat = 20                               // --r-card
    public static let radiusSmall: CGFloat = 12                              // --r-sm
    public static let minTap: CGFloat = 44

    /// --gradient-brand: emerald, top-leading to bottom-trailing.
    public static var gradient: LinearGradient {
        LinearGradient(colors: [g0, primary, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
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
