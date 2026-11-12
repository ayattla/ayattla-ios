import SwiftUI

// Design system v3, rebuilt from ayattla.com's live stylesheet (see docs/DESIGN_SYSTEM.md):
//  • page        white / mint (--s-bg, --s-soft) with the page-head glow (green top-right, teal bottom-left)
//  • card        white, 1px --s-line, radius 18, shadow --s-sh (0 1 2 .06 + 0 18 40 -22 .28)
//  • icon tiles  52pt, radius 16, gradients in the site's 5-colour cycle (Brand.tileGradients)
//  • eyebrow     pill with --s-grad-soft, green-deep text and a gradient dot
//  • buttons     --s-grad primary, deep-emerald dark, gold gradient for "create"
//  • emerald     --gradient-brand panels for Quran content (ayah of the day, previews)

public extension Brand {
    /// Spacing scale (--s-1 … --s-7).
    enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    /// Radii (--rad-s, --rad-m, --rad-l, stats 28).
    enum Radius {
        public static let tile: CGFloat = 16
        public static let card: CGFloat = 18
        public static let hero: CGFloat = 24
        public static let feature: CGFloat = 28
    }

    /// Widest readable column on iPad and in landscape (--container-tool 960, with margins).
    static let readableWidth: CGFloat = 860
}

/// Eight-pointed star lattice (the site's --star ornament). Used sparingly: on emerald Quran panels.
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

/// Card levels. `raised` = the site's card; `flat` = card without the deep shadow; `tinted` = mint
/// panel (--s-soft); `gold` = selected/featured (--c-accent-soft).
public enum SurfaceLevel { case raised, flat, tinted, gold }

public extension View {
    func surface(_ level: SurfaceLevel = .raised, radius: CGFloat = Brand.Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fill: Color = switch level {
        case .raised, .flat: Brand.surface
        case .tinted: Brand.surface2
        case .gold: Brand.goldSoft
        }
        return background(fill, in: shape)
            .overlay(shape.strokeBorder(level == .gold ? Brand.accent.opacity(0.45) : Brand.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x0F1F17).opacity(level == .raised ? 0.06 : 0), radius: 1, y: 1)
            .shadow(color: Color(hex: 0x0F1F17).opacity(level == .raised ? 0.14 : 0), radius: 20, y: 14)
    }

    /// Deep emerald panel (--gradient-brand) with the gold frame line (--frame): Quran content.
    func heroSurface(radius: CGFloat = Brand.Radius.hero) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            ZStack {
                Brand.gradient
                IslamicPattern(color: Brand.accent.opacity(0.10))
                RadialGradient(colors: [Color.white.opacity(0.08), .clear], center: .topTrailing, startRadius: 0, endRadius: 320)
            }
            .clipShape(shape)
        }
        .overlay(RoundedRectangle(cornerRadius: max(radius - 7, 4), style: .continuous)
            .strokeBorder(Brand.accent.opacity(0.40), lineWidth: 1).padding(7))
        .shadow(color: Color(hex: 0x0B211C).opacity(0.25), radius: 20, y: 12)
        .foregroundStyle(Color(hex: 0xF6F2E9))
    }

    /// Green→teal feature panel (the site's stats band and closing call): white text.
    func featureSurface(radius: CGFloat = Brand.Radius.feature) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(Brand.siteGradient, in: shape)
            .overlay(alignment: .topTrailing) {
                Circle().fill(Color.white.opacity(0.10)).frame(width: 180, height: 180).offset(x: 60, y: -70)
                    .clipShape(shape).allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: Color(hex: 0x1F8A62).opacity(0.45), radius: 24, y: 16)
            .foregroundStyle(.white)
    }

    /// The site's .page-head: soft card with a green glow top-right and a teal glow bottom-left.
    func pageHeadSurface(radius: CGFloat = Brand.Radius.hero) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            ZStack {
                Brand.surface
                RadialGradient(colors: [Brand.green.opacity(0.16), .clear], center: UnitPoint(x: 0.15, y: 0), startRadius: 0, endRadius: 260)
                RadialGradient(colors: [Brand.teal.opacity(0.13), .clear], center: UnitPoint(x: 0.9, y: 1), startRadius: 0, endRadius: 240)
            }
            .clipShape(shape)
        }
        .overlay(shape.strokeBorder(Brand.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x0F1F17).opacity(0.10), radius: 18, y: 12)
    }

    /// Screen backdrop: mint page with the faint page-head glow under the navigation bar.
    func patternedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background {
                ZStack(alignment: .top) {
                    Brand.background
                    ZStack {
                        RadialGradient(colors: [Brand.green.opacity(0.10), .clear], center: UnitPoint(x: 0.1, y: 0), startRadius: 0, endRadius: 320)
                        RadialGradient(colors: [Brand.teal.opacity(0.08), .clear], center: UnitPoint(x: 0.95, y: 0.2), startRadius: 0, endRadius: 280)
                    }
                    .frame(height: 360)
                }
                .ignoresSafeArea()
            }
    }
}

/// Icon tile. `.gradient(n)` follows the site's tile colours by position; `.gold`, `.soft` and
/// `.emerald` are the quieter tiles of secondary lists.
public struct IconTile: View {
    /// `accent`: the site's tools grid (soft wash of the tool colour, glyph in that colour, thin
    /// border); `solid`: the tool page head (tool colour, white glyph).
    public enum Style { case gradient(Int), gold, emerald, soft, accent(Color), solid(Color) }
    let symbol: String
    let style: Style
    let size: CGFloat

    public init(_ symbol: String, style: Style = .gradient(0), size: CGFloat = 52) {
        self.symbol = symbol; self.style = style; self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background {
                switch style {
                case .gradient(let i): shape.fill(Brand.tileGradient(i))
                case .emerald: shape.fill(Brand.gradient)
                case .gold: shape.fill(Brand.goldSoft)
                case .soft: shape.fill(Brand.tint)
                case .accent(let c):
                    shape.fill(c.opacity(0.11)).overlay(shape.strokeBorder(c.opacity(0.2), lineWidth: 1))
                case .solid(let c): shape.fill(c)
                }
            }
            .shadow(color: shadow, radius: 8, y: 6)
            .accessibilityHidden(true)
    }

    private var foreground: Color {
        switch style {
        case .gradient: .white
        case .emerald: Brand.onDeepAccent
        case .gold: Brand.goldInk
        case .soft: Brand.primaryInk
        case .accent(let c): c
        case .solid: .white
        }
    }

    private var shadow: Color {
        if case .gradient(let i) = style { return Color(hex: Brand.tileGradients[((i % 5) + 5) % 5][0]).opacity(0.35) }
        if case .solid(let c) = style { return c.opacity(0.35) }
        return .clear
    }
}

/// Small rounded label. `gold: true` is the site's «جديد» badge.
public struct Badge: View {
    let text: String
    let gold: Bool
    public init(_ text: String, gold: Bool = false) { self.text = text; self.gold = gold }
    public var body: some View {
        Text(text).font(.ui(.caption2, .semibold))
            .foregroundStyle(gold ? Brand.newInk : Brand.primaryInk)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(gold ? Brand.newFill : Brand.tint, in: Capsule())
    }
}

/// The site's .eyebrow: pill with the soft gradient, a gradient dot and green-deep text.
public struct Eyebrow: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Brand.siteGradient).frame(width: 8, height: 8)
            Text(text).font(.ui(.footnote, .bold)).foregroundStyle(Brand.greenDeep)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(LinearGradient(colors: [Brand.green.opacity(0.10), Brand.teal.opacity(0.10)],
                                   startPoint: .leading, endPoint: .trailing), in: Capsule())
        .overlay(Capsule().strokeBorder(Brand.green.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Section heading as on the site: eyebrow pill, title with the soft green underline, and a line.
public struct SiteSectionHead: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    public init(eyebrow: String? = nil, _ title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle
    }
    public var body: some View {
        VStack(spacing: Brand.Space.s) {
            Capsule().fill(Brand.siteGradient).frame(width: 44, height: 4)
            if let eyebrow { Eyebrow(eyebrow) }
            Text(title).font(.ui(.title2, .bold)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .background(alignment: .bottom) {
                    Brand.green.opacity(0.14).frame(height: 10).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Gentle press feedback (--ease, translateY on hover on the site); none with Reduce Motion.
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

/// Section root header in the site's .page-head style: breadcrumb/eyebrow, large title, lead text.
public struct HeroHeader<Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let content: Content

    public init(eyebrow: String? = nil, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle; self.content = content()
    }

    public var body: some View {
        VStack(spacing: Brand.Space.m) {
            if let eyebrow { Eyebrow(eyebrow) }
            Text(title).font(.ui(.title, .bold)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(.horizontal, Brand.Space.xl).padding(.vertical, Brand.Space.xl + 4)
        .frame(maxWidth: .infinity)
        .pageHeadSurface()
    }
}

public extension HeroHeader where Content == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Eight-pointed star mark in gold (the site's --star bullet).
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

/// The site's tool card (`.tools a` on phones): centred gradient tile, title with an optional
/// «جديد» badge, and the one-line description. `row` is the compact horizontal variant.
public struct ServiceCard: View {
    public enum Layout { case centered, row }
    let title: String
    let subtitle: String?
    let symbol: String
    let badge: String?
    let style: IconTile.Style
    let layout: Layout

    public init(_ title: String, subtitle: String? = nil, symbol: String, badge: String? = nil,
                style: IconTile.Style = .gradient(0), layout: Layout = .centered) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.badge = badge
        self.style = style; self.layout = layout
    }

    public var body: some View {
        Group {
            switch layout {
            case .centered:
                VStack(spacing: 10) {
                    IconTile(symbol, style: style)
                    HStack(spacing: 6) {
                        Text(title).font(.ui(.headline)).foregroundStyle(Brand.ink)
                            .multilineTextAlignment(.center)
                        if let badge { Badge(badge, gold: true) }
                    }
                    if let subtitle {
                        Text(subtitle).font(.ui(.footnote)).foregroundStyle(Brand.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 20).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
            case .row:
                HStack(spacing: Brand.Space.m) {
                    IconTile(symbol, style: style, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
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
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .surface(.raised)
        .accessibilityElement(children: .combine)
    }
}

/// Compact launcher (icon over a short title) for dense grids.
public struct LauncherTile: View {
    let title: String
    let symbol: String
    let style: IconTile.Style
    public init(_ title: String, symbol: String, style: IconTile.Style = .gradient(0)) {
        self.title = title; self.symbol = symbol; self.style = style
    }
    public var body: some View {
        VStack(spacing: Brand.Space.s) {
            IconTile(symbol, style: style, size: 46)
            Text(title).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Brand.Space.m + 2).padding(.horizontal, Brand.Space.xs)
        .frame(maxWidth: .infinity, minHeight: 112)
        .surface(.raised)
        .accessibilityElement(children: .combine)
    }
}

/// Outline pill for secondary actions in page heads (the site's light .btn variant).
public struct GhostOnEmerald: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(.subheadline, .semibold))
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x0F1F17).opacity(0.08), radius: 10, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The site's segmented choice (.seg): mint track, the chosen option filled with the gradient.
public struct SiteSegmented<ID: Hashable>: View {
    let items: [(id: ID, title: String, detail: String?)]
    @Binding var selection: ID
    public init(_ items: [(id: ID, title: String, detail: String?)], selection: Binding<ID>) {
        self.items = items; self._selection = selection
    }
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                let on = it.id == selection
                Button { selection = it.id } label: {
                    VStack(spacing: 1) {
                        Text(it.title).font(.ui(.subheadline, on ? .semibold : .medium))
                        if let d = it.detail { Text(d).font(.ui(.caption2)).opacity(0.85) }
                    }
                    .foregroundStyle(on ? Color.white : Brand.muted)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.vertical, 4)
                    .background {
                        if on { RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Brand.siteGradient) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

/// Numbered step header used by the editors (the site's ① النص، ② …): emerald number disc and title.
public struct StepHeader: View {
    let number: Int
    let title: String
    let detail: String?
    public init(_ number: Int, _ title: String, detail: String? = nil) {
        self.number = number; self.title = title; self.detail = detail
    }
    public var body: some View {
        HStack(spacing: 10) {
            Text(Num.int(number)).font(.ui(.subheadline, .bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(Brand.primary, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.ui(.headline)).foregroundStyle(Brand.ink)
                if let detail { Text(detail).font(.ui(.caption)).foregroundStyle(Brand.muted) }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
