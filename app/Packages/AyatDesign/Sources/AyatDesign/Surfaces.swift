import SwiftUI

// Design system v2: the layers that make screens read as one platform with ayattla.com —
// a geometric star pattern (the site's ornament), patterned emerald heroes, three card levels,
// icon tiles and a spacing scale. Every screen root and card should be built from these.

public extension Brand {
    /// Spacing scale (points). Screens use `l` side margins and `xl` between sections.
    enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    /// Radii: chips and tiles, cards, hero panels.
    enum Radius {
        public static let tile: CGFloat = 14
        public static let card: CGFloat = 20
        public static let hero: CGFloat = 28
    }

    /// Widest readable column on iPad and in landscape.
    static let readableWidth: CGFloat = 820
}

/// Eight-pointed star lattice (two squares at 45°) as on the site's ornaments and frames.
/// Drawn with Canvas, so it scales cleanly and costs one layer.
public struct IslamicPattern: View {
    var cell: CGFloat
    var lineWidth: CGFloat
    var color: Color

    public init(cell: CGFloat = 46, lineWidth: CGFloat = 0.8, color: Color = Brand.accent) {
        self.cell = cell; self.lineWidth = lineWidth; self.color = color
    }

    public var body: some View {
        Canvas { ctx, size in
            let r = cell * 0.34
            var path = Path()
            var y: CGFloat = 0
            var row = 0
            while y <= size.height + cell {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                while x <= size.width + cell {
                    for k in 0..<2 {
                        let a0 = CGFloat(k) * .pi / 4
                        var sq = Path()
                        for i in 0..<4 {
                            let a = a0 + CGFloat(i) * .pi / 2 + .pi / 4
                            let p = CGPoint(x: x + r * cos(a), y: y + r * sin(a))
                            if i == 0 { sq.move(to: p) } else { sq.addLine(to: p) }
                        }
                        sq.closeSubpath()
                        path.addPath(sq)
                    }
                    path.addEllipse(in: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4))
                    x += cell
                }
                y += cell * 0.5
                row += 1
            }
            ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Card levels. `raised` for primary cards, `flat` inside sections, `tinted` for supporting info.
public enum SurfaceLevel { case raised, flat, tinted, gold }

public extension View {
    func surface(_ level: SurfaceLevel = .raised, radius: CGFloat = Brand.Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fill: Color = switch level {
        case .raised, .flat: Brand.surface
        case .tinted: Brand.tint
        case .gold: Brand.goldSoft
        }
        return background(fill, in: shape)
            .overlay(shape.strokeBorder(level == .gold ? Brand.accent.opacity(0.35) : Brand.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x102D27).opacity(level == .raised ? 0.08 : 0), radius: 14, y: 6)
            .shadow(color: Color(hex: 0x102D27).opacity(level == .raised ? 0.04 : 0), radius: 2, y: 1)
    }

    /// Emerald hero surface: gradient, star lattice, soft light from the top and the gold frame.
    func heroSurface(radius: CGFloat = Brand.Radius.hero) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            ZStack {
                Brand.gradient
                IslamicPattern(color: Brand.accent.opacity(0.13))
                RadialGradient(colors: [Color.white.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 320)
            }
            .clipShape(shape)
        }
        .overlay(RoundedRectangle(cornerRadius: max(radius - 7, 4), style: .continuous)
            .strokeBorder(Brand.accent.opacity(0.40), lineWidth: 1).padding(7))
        .shadow(color: Color(hex: 0x0B211C).opacity(0.22), radius: 18, y: 10)
        .foregroundStyle(Brand.onPrimary)
    }

    /// Screen backdrop: ivory with a faint lattice fading out under the navigation bar.
    func patternedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background {
                ZStack(alignment: .top) {
                    Brand.background
                    IslamicPattern(color: Brand.accent.opacity(0.10))
                        .frame(height: 260)
                        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                }
                .ignoresSafeArea()
            }
    }
}

/// Square icon tile used by every card that leads with an icon.
public struct IconTile: View {
    public enum Style { case gold, emerald, soft }
    let symbol: String
    let style: Style
    let size: CGFloat

    public init(_ symbol: String, style: Style = .gold, size: CGFloat = 44) {
        self.symbol = symbol; self.style = style; self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(style == .emerald ? Brand.onDeepAccent : style == .gold ? Brand.goldInk : Brand.primaryInk)
            .frame(width: size, height: size)
            .background {
                switch style {
                case .emerald: shape.fill(Brand.gradient)
                case .gold: shape.fill(Brand.goldSoft)
                case .soft: shape.fill(Brand.tint)
                }
            }
            .overlay(shape.strokeBorder(style == .emerald ? Brand.accent.opacity(0.35) : .clear, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Small rounded label: counts, "جديد", states.
public struct Badge: View {
    let text: String
    let gold: Bool
    public init(_ text: String, gold: Bool = false) { self.text = text; self.gold = gold }
    public var body: some View {
        Text(text).font(.ui(.caption2, .semibold))
            .foregroundStyle(gold ? Brand.goldInk : Brand.primaryInk)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(gold ? Brand.goldSoft : Brand.tint, in: Capsule())
    }
}

/// Gentle press feedback for cards and tiles (no motion when Reduce Motion is on).
public struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PressableStyle { static var pressable: PressableStyle { .init() } }

/// Patterned emerald header for a section's root screen: eyebrow, title, line, and actions.
public struct HeroHeader<Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let content: Content

    public init(eyebrow: String? = nil, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle; self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            if let eyebrow {
                HStack(spacing: 6) {
                    StarMark().frame(width: 14, height: 14)
                    Text(eyebrow).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.onDeepAccent)
                }
            }
            Text(title).font(.ui(.title2, .bold)).foregroundStyle(Brand.onPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.ui(.subheadline)).foregroundStyle(Brand.onPrimary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(Brand.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroSurface()
    }
}

public extension HeroHeader where Content == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Eight-pointed star mark in gold (the site's bullet ornament).
public struct StarMark: View {
    public init() {}
    public var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) / 2
            for k in 0..<2 {
                var p = Path()
                for i in 0..<4 {
                    let a = CGFloat(k) * .pi / 4 + CGFloat(i) * .pi / 2
                    let pt = CGPoint(x: c.x + r * 0.86 * cos(a), y: c.y + r * 0.86 * sin(a))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
                ctx.fill(p, with: .color(Brand.accent))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Lead card with an icon tile, title, line and an optional trailing badge; the building block
/// for service lists (master prompt: ToolCard, AppCard).
public struct ServiceCard: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let badge: String?
    let style: IconTile.Style

    public init(_ title: String, subtitle: String? = nil, symbol: String, badge: String? = nil, style: IconTile.Style = .gold) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.badge = badge; self.style = style
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Brand.Space.m) {
            IconTile(symbol, style: style)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge { Badge(badge, gold: true) }
                }
                if let subtitle {
                    Text(subtitle).font(.ui(.caption)).foregroundStyle(Brand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward").font(.ui(.caption, .semibold)).foregroundStyle(Brand.lineStrong)
                .accessibilityHidden(true)
        }
        .padding(Brand.Space.m + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.raised)
        .accessibilityElement(children: .combine)
    }
}

/// Square launcher tile for grids of tools (icon over a short title).
public struct LauncherTile: View {
    let title: String
    let symbol: String
    let style: IconTile.Style
    public init(_ title: String, symbol: String, style: IconTile.Style = .soft) {
        self.title = title; self.symbol = symbol; self.style = style
    }
    public var body: some View {
        VStack(spacing: Brand.Space.s) {
            IconTile(symbol, style: style, size: 46)
            Text(title).font(.ui(.footnote, .medium)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Brand.Space.m).padding(.horizontal, Brand.Space.xs)
        .frame(maxWidth: .infinity, minHeight: 104)
        .surface(.raised)
        .accessibilityElement(children: .combine)
    }
}

/// Outline pill for secondary actions on emerald heroes.
public struct GhostOnEmerald: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(.subheadline, .semibold))
            .foregroundStyle(Brand.onPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(Brand.onDeepAccent.opacity(0.55), lineWidth: 1))
    }
}
