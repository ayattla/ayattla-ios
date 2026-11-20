import SwiftUI
import AyatDesign

/// «الافتتاحية» (about 2.6 s, once per launch): the launch screen hands over on the same deep green; a gold
/// geometric rosette is traced line by line (rings, the eight-point star, the inner star, sixteen rays) while a
/// warm light blooms at its centre; the gold book rises into that light and a sheen sweeps across it; the
/// calligraphic name and the tagline follow; then the scene eases forward and dissolves into the app.
/// A tap skips it; skipped with Reduce Motion or when turned off in Settings.
struct IntroView: View {
    static let key = "intro.enabled"
    /// CI screenshots: keep the final frame instead of fading out.
    var holdAtEnd = false
    var onDone: () -> Void
    @State private var ring: CGFloat = 0
    @State private var star: CGFloat = 0
    @State private var inner: CGFloat = 0
    @State private var rays: CGFloat = 0
    @State private var bloom: CGFloat = 0
    @State private var book: CGFloat = 0
    @State private var sheen: CGFloat = -0.4
    @State private var word: CGFloat = 0
    @State private var tag: CGFloat = 0
    @State private var spin = false
    @State private var exit = false
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gold = Color(hex: 0xE8C878)
    private let goldLight = Color(hex: 0xFFF1C2)
    private let goldDeep = Color(hex: 0xB8893F)
    private var goldGradient: LinearGradient {
        LinearGradient(colors: [goldLight, gold, goldDeep, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let r = min(w, h) * 0.40
            let cy = h * 0.42
            ZStack {
                RadialGradient(colors: [Color(hex: 0x2A8A57), Color(hex: 0x17623F), Color(hex: 0x0A2E22)],
                               center: .center, startRadius: 0, endRadius: max(w, h) * 0.85)
                // Light bloom.
                RadialGradient(colors: [Color(hex: 0xFFE7A6).opacity(0.5), Color(hex: 0xF2C96B).opacity(0.14), .clear],
                               center: .center, startRadius: 0, endRadius: r * 1.25)
                    .frame(width: r * 2.5, height: r * 2.5)
                    .position(x: w / 2, y: cy)
                    .opacity(Double(bloom))
                // Rosette.
                ZStack {
                    Circle().trim(from: 0, to: ring).stroke(goldGradient, lineWidth: 2).opacity(0.55)
                        .frame(width: r * 2.04, height: r * 2.04)
                    Circle().trim(from: 0, to: ring).stroke(goldGradient, lineWidth: 1).opacity(0.28)
                        .frame(width: r * 2.2, height: r * 2.2)
                    ForEach(0..<16, id: \.self) { i in
                        Circle().fill(gold).frame(width: i.isMultiple(of: 2) ? 6 : 3.6, height: i.isMultiple(of: 2) ? 6 : 3.6)
                            .offset(x: r * 1.02).rotationEffect(.degrees(Double(i) * 22.5))
                            .opacity(Double(ring) * 0.8)
                    }
                    ForEach(0..<16, id: \.self) { i in
                        Capsule().fill(gold.opacity(0.14)).frame(width: r * 0.66 * rays, height: 1)
                            .offset(x: r * 0.30 + r * 0.33 * rays).rotationEffect(.degrees(Double(i) * 22.5))
                    }
                    StarShape().fill(LinearGradient(colors: [Color(hex: 0x2C9862).opacity(0.45), Color(hex: 0x0E4A33).opacity(0.45)],
                                                    startPoint: .top, endPoint: .bottom))
                        .opacity(Double(star))
                        .frame(width: r * 1.96, height: r * 1.96)
                    StarShape().trim(from: 0, to: star)
                        .stroke(goldGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: r * 1.96, height: r * 1.96)
                    StarShape().trim(from: 0, to: inner)
                        .stroke(goldGradient, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)).opacity(0.5)
                        .frame(width: r * 1.6, height: r * 1.6)
                }
                .rotationEffect(.degrees(spin ? 10 : 0))
                .position(x: w / 2, y: cy)
                // Gold dust.
                TimelineView(.animation) { t in
                    Canvas { ctx, size in
                        let e = t.date.timeIntervalSince(start)
                        for i in 0..<22 {
                            let seed = Double(i * 73 % 100) / 100
                            let x = size.width * Double(i * 37 % 100) / 100
                            let y = size.height * (1.05 - (seed + e / 3.2 * (0.25 + seed * 0.3)).truncatingRemainder(dividingBy: 1.1))
                            let a = (0.15 + 0.45 * Double(i * 17 % 10) / 10) * Double(bloom)
                            let s = 2.4 + Double(i % 3) * 2
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(goldLight.opacity(a)))
                        }
                    }
                }
                .allowsHitTesting(false)
                // The gold book with a passing sheen.
                Image("IntroBook").resizable().scaledToFit()
                    .frame(width: r * 1.42)
                    .overlay {
                        GeometryReader { g in
                            LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.36)
                                .offset(x: g.size.width * sheen - g.size.width * 0.18)
                                .blendMode(.sourceAtop)
                        }
                    }
                    .compositingGroup()
                    .scaleEffect(0.92 + 0.08 * book)
                    .offset(y: (1 - book) * 26)
                    .opacity(Double(book))
                    .position(x: w / 2, y: cy + 10)
                // Name.
                Image("IntroWord").resizable().scaledToFit()
                    .frame(width: r * 1.42 * 0.82)
                    .offset(y: (1 - word) * 14)
                    .opacity(Double(word))
                    .position(x: w / 2, y: cy + r * 1.18 + r * 0.25)
                    .accessibilityHidden(true)
                // Tagline.
                VStack(spacing: 6) {
                    Spacer()
                    Capsule().fill(LinearGradient(colors: [.clear, gold, .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 72 * tag, height: 1.5)
                    Text("القرآن والأذكار وأدوات المسلم اليومية").font(.ui(.callout, .semibold)).foregroundStyle(.white.opacity(0.94))
                    Text("مجاني · بلا حساب · يعمل دون إنترنت").font(.ui(.footnote)).foregroundStyle(gold.opacity(0.9))
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 48)
                .opacity(Double(tag)).offset(y: (1 - tag) * 10)
            }
        }
        .ignoresSafeArea()
        .scaleEffect(exit ? 1.06 : 1)
        .opacity(exit ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("آيات تتلى")
        .task {
            if reduceMotion { onDone(); return }
            start = Date()
            let inOut = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 1)
            let out = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 1)
            withAnimation(.linear(duration: 3.2)) { spin = true }
            withAnimation(inOut.speed(1 / 0.7)) { ring = 1 }
            withAnimation(inOut.speed(1 / 0.9).delay(0.12)) { star = 1 }
            withAnimation(inOut.speed(1 / 0.8).delay(0.35)) { inner = 1 }
            withAnimation(out.speed(1 / 0.7).delay(0.42)) { rays = 1 }
            withAnimation(out.speed(1 / 1.1).delay(0.3)) { bloom = 1 }
            withAnimation(out.speed(1 / 0.8).delay(0.64)) { book = 1 }
            withAnimation(inOut.speed(1 / 0.75).delay(1.15)) { sheen = 1.4 }
            withAnimation(out.speed(1 / 0.65).delay(1.05)) { word = 1 }
            withAnimation(out.speed(1 / 0.5).delay(1.45)) { tag = 1 }
            try? await Task.sleep(nanoseconds: 2_370_000_000)
            if holdAtEnd { return }
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.42)) { exit = true }
            try? await Task.sleep(nanoseconds: 440_000_000)
            onDone()
        }
    }
}

/// Eight-point star (two overlapping squares' outline), the app icon's medallion.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * cos(.pi / 4) / cos(.pi / 8)
        var p = Path()
        for i in 0..<16 {
            let a = CGFloat.pi / 8 * CGFloat(i) - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
