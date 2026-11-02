import SwiftUI

/// Brand tokens from styles/tokens.css on the site (see design/System.dc.html).
public enum Brand {
    public static let g0 = Color(hex: 0x2F6B3B)
    public static let primary = Color(hex: 0x427E45)      // buttons, large headings, fills
    public static let primaryInk = Color(hex: 0x2C5E37)   // links and small green text (AA)
    public static let accent = Color(hex: 0x2E9145)
    public static let tint = Color(hex: 0xEEF5EF)
    public static let line = Color(hex: 0xE3EBE5)
    public static let dotOff = Color(hex: 0xCFE2D3)       // inactive page dot (design/Onboarding.dc.html)
    public static let muted = Color(hex: 0x56665B)        // secondary text on light backgrounds
    public static let radiusCard: CGFloat = 16
    public static let minTap: CGFloat = 44
}

public extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    /// Card surface: white on the grouped background in light mode, raised gray in dark mode.
    static var cardSurface: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

public extension View {
    /// Card per design/System.dc.html: radius 16, 1px #E3EBE5 border, no shadow.
    func card() -> some View {
        background(Color.cardSurface, in: RoundedRectangle(cornerRadius: Brand.radiusCard))
            .clipShape(RoundedRectangle(cornerRadius: Brand.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: Brand.radiusCard).stroke(Brand.line, lineWidth: 1))
    }
}
