import SwiftUI

/// Brand tokens from styles/tokens.css on the site (see design/System.dc.html).
enum Brand {
    static let g0 = Color(hex: 0x2F6B3B)
    static let primary = Color(hex: 0x427E45)      // buttons, large headings, fills
    static let primaryInk = Color(hex: 0x2C5E37)   // links and small green text (AA)
    static let accent = Color(hex: 0x2E9145)
    static let tint = Color(hex: 0xEEF5EF)
    static let line = Color(hex: 0xE3EBE5)
    static let radiusCard: CGFloat = 16
    static let minTap: CGFloat = 44
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
