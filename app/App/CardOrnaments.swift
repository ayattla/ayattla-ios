import SwiftUI
import AyatDesign

/// Decorations for cards, statuses and clips: pure geometry drawn in the card's accent colour.
enum CardOrnament: String, CaseIterable, Identifiable, Codable {
    case none, classic, arch, corners, medallion, bands, lantern
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none: "بدون"
        case .classic: "إطار ذهبي"
        case .arch: "محراب"
        case .corners: "زوايا مزخرفة"
        case .medallion: "نجمة خلفية"
        case .bands: "شريط زخرفي"
        case .lantern: "قناديل"
        }
    }
}

private func star(_ c: CGPoint, _ outer: CGFloat, rot: CGFloat = -.pi / 2) -> Path {
    let inner = outer * cos(.pi / 4) / cos(.pi / 8)
    var p = Path()
    for i in 0..<16 {
        let a = CGFloat.pi / 8 * CGFloat(i) + rot
        let r = i.isMultiple(of: 2) ? outer : inner
        let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

/// Draws an ornament over a card of any size (`k` = width / 1080).
struct OrnamentLayer: View {
    let kind: CardOrnament
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, k = w / 1080
            func stroke(_ p: Path, _ a: Double, _ lw: CGFloat) { ctx.stroke(p, with: .color(accent.opacity(a)), style: StrokeStyle(lineWidth: lw * k, lineCap: .round, lineJoin: .round)) }
            func fill(_ p: Path, _ a: Double) { ctx.fill(p, with: .color(accent.opacity(a))) }
            switch kind {
            case .none: break
            case .classic:
                stroke(Path(roundedRect: CGRect(x: 36 * k, y: 36 * k, width: w - 72 * k, height: h - 72 * k), cornerRadius: 40 * k), 0.6, 3)
                stroke(Path(roundedRect: CGRect(x: 52 * k, y: 52 * k, width: w - 104 * k, height: h - 104 * k), cornerRadius: 30 * k), 0.32, 1.5)
            case .arch:
                func arch(_ inset: CGFloat) -> Path {
                    let l = inset, r = w - inset, b = h - inset, spring = h * 0.30, top = inset + 10 * k
                    var p = Path()
                    p.move(to: CGPoint(x: l, y: b)); p.addLine(to: CGPoint(x: l, y: spring))
                    p.addCurve(to: CGPoint(x: w / 2, y: top), control1: CGPoint(x: l, y: spring - (spring - top) * 0.62),
                               control2: CGPoint(x: w / 2 - (w / 2 - l) * 0.28, y: top + (spring - top) * 0.18))
                    p.addCurve(to: CGPoint(x: r, y: spring), control1: CGPoint(x: w / 2 + (r - w / 2) * 0.28, y: top + (spring - top) * 0.18),
                               control2: CGPoint(x: r, y: spring - (spring - top) * 0.62))
                    p.addLine(to: CGPoint(x: r, y: b)); p.closeSubpath()
                    return p
                }
                stroke(arch(44 * k), 0.67, 3.5); stroke(arch(64 * k), 0.35, 1.5)
                fill(star(CGPoint(x: w / 2, y: 80 * k), 16 * k), 0.8)
            case .corners:
                stroke(Path(roundedRect: CGRect(x: 48 * k, y: 48 * k, width: w - 96 * k, height: h - 96 * k), cornerRadius: 24 * k), 0.43, 2)
                for pt in [CGPoint(x: 48 * k, y: 48 * k), CGPoint(x: w - 48 * k, y: 48 * k), CGPoint(x: 48 * k, y: h - 48 * k), CGPoint(x: w - 48 * k, y: h - 48 * k)] {
                    fill(star(pt, 28 * k), 0.9); stroke(star(pt, 46 * k), 0.63, 2)
                }
                fill(star(CGPoint(x: w / 2, y: 48 * k), 12 * k), 0.8); fill(star(CGPoint(x: w / 2, y: h - 48 * k), 12 * k), 0.8)
            case .medallion:
                let r = min(w, h) * 0.46, c = CGPoint(x: w / 2, y: h / 2)
                stroke(star(c, r), 0.24, 2.5); stroke(star(c, r * 0.78), 0.16, 2.5)
                stroke(Path(ellipseIn: CGRect(x: c.x - r * 1.05, y: c.y - r * 1.05, width: r * 2.1, height: r * 2.1)), 0.18, 1.5)
                for i in 0..<16 {
                    let a = CGFloat.pi / 8 * CGFloat(i)
                    var l = Path(); l.move(to: CGPoint(x: c.x + cos(a) * r * 0.35, y: c.y + sin(a) * r * 0.35))
                    l.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.98, y: c.y + sin(a) * r * 0.98)); stroke(l, 0.09, 1.2)
                }
                stroke(Path(roundedRect: CGRect(x: 40 * k, y: 40 * k, width: w - 80 * k, height: h - 80 * k), cornerRadius: 34 * k), 0.43, 2)
            case .bands:
                for y in [96 * k, h - 96 * k] {
                    var a = Path(); a.move(to: CGPoint(x: 60 * k, y: y - 26 * k)); a.addLine(to: CGPoint(x: w - 60 * k, y: y - 26 * k))
                    var b = Path(); b.move(to: CGPoint(x: 60 * k, y: y + 26 * k)); b.addLine(to: CGPoint(x: w - 60 * k, y: y + 26 * k))
                    stroke(a, 0.6, 2); stroke(b, 0.6, 2)
                    let n = 11, step = (w - 160 * k) / CGFloat(n - 1)
                    for i in 0..<n {
                        let pt = CGPoint(x: 80 * k + CGFloat(i) * step, y: y)
                        if i.isMultiple(of: 2) { fill(star(pt, 13 * k), 0.82) } else { stroke(star(pt, 11 * k, rot: 0), 0.55, 2) }
                    }
                }
            case .lantern:
                for (fx, fy) in [(0.22, 0.085), (0.5, 0.12), (0.78, 0.07)] as [(CGFloat, CGFloat)] {
                    let x = w * fx, y = h * fy
                    var cord = Path(); cord.move(to: CGPoint(x: x, y: 0)); cord.addLine(to: CGPoint(x: x, y: y - 34 * k)); stroke(cord, 0.6, 2)
                    var body = Path()
                    body.move(to: CGPoint(x: x, y: y - 34 * k)); body.addLine(to: CGPoint(x: x + 20 * k, y: y - 14 * k))
                    body.addLine(to: CGPoint(x: x + 20 * k, y: y + 22 * k)); body.addLine(to: CGPoint(x: x, y: y + 40 * k))
                    body.addLine(to: CGPoint(x: x - 20 * k, y: y + 22 * k)); body.addLine(to: CGPoint(x: x - 20 * k, y: y - 14 * k)); body.closeSubpath()
                    fill(body, 0.27); stroke(body, 0.82, 2)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 7 * k, y: y - 3 * k, width: 14 * k, height: 14 * k)), with: .color(Color(hex: 0xFFECAA).opacity(0.8)))
                    fill(star(CGPoint(x: x, y: y + 52 * k), 6 * k), 0.86)
                }
                stroke(Path(roundedRect: CGRect(x: 40 * k, y: 40 * k, width: w - 80 * k, height: h - 80 * k), cornerRadius: 30 * k), 0.35, 1.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Ornaments as small live previews in the selected background.
struct OrnamentSwatches: View {
    let selected: CardOrnament
    let background: CardOptions.Background
    let pick: (CardOrnament) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.s) {
                ForEach(CardOrnament.allCases) { o in
                    let on = o == selected
                    Button { pick(o) } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(background.gradient)
                                .frame(width: 54, height: 72)
                                .overlay { OrnamentLayer(kind: o, accent: background.accentColor).padding(0) }
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Brand.accent : Brand.line, lineWidth: on ? 3 : 1))
                            Text(o.name).font(.ui(.caption2)).foregroundStyle(on ? Brand.primaryInk : Brand.muted).lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("زخرفة \(o.name)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}
