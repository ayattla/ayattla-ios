import SwiftUI
import AyatDesign

/// «الافتتاحية»: picks up where the launch screen ends (same deep green), draws the gold
/// eight-point star, rings out, then the full logo rises in with the tagline and fades into the app.
/// About 2.2 s; a tap skips; skipped with Reduce Motion or when turned off in Settings.
struct IntroView: View {
    static let key = "intro.enabled"
    var onDone: () -> Void
    @State private var draw: CGFloat = 0
    @State private var ring: CGFloat = 0
    @State private var logo: CGFloat = 0
    @State private var tag: CGFloat = 0
    @State private var spin = false
    @State private var out = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gold = Color(hex: 0xE3CB8E)

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x2E9145), Color(hex: 0x1F5A3C), Color(hex: 0x102D27)],
                           center: .center, startRadius: 0, endRadius: 620)
                .ignoresSafeArea()
            ZStack {
                ForEach(0..<2) { i in
                    Circle().stroke(gold.opacity(i == 0 ? 0.22 : 0.12), lineWidth: i == 0 ? 1.2 : 0.8)
                        .frame(width: 240 + 90 * ring + CGFloat(i) * 26, height: 240 + 90 * ring + CGFloat(i) * 26)
                        .opacity(Double(ring))
                }
                StarShape().fill(Color(hex: 0x102D27).opacity(0.45 * Double(draw)))
                    .frame(width: 215, height: 215)
                StarShape().trim(from: 0, to: draw)
                    .stroke(LinearGradient(colors: [gold, Color(hex: 0xC3A66B)], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 215, height: 215)
            }
            .rotationEffect(.degrees(spin ? 22 : 0))
            Image("LogoFull").resizable().scaledToFit().frame(width: 170, height: 170)
                .environment(\.colorScheme, .dark)
                .opacity(Double(logo)).scaleEffect(0.86 + 0.14 * logo).offset(y: (1 - logo) * 24)
            VStack(spacing: 6) {
                Spacer()
                Capsule().fill(LinearGradient(colors: [.clear, gold, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 60 * tag, height: 2)
                Text("القرآن والأذكار وأدوات المسلم اليومية").font(.ui(.callout, .semibold)).foregroundStyle(.white.opacity(0.92))
                Text("مجاني · بلا حساب · يعمل دون إنترنت").font(.ui(.footnote)).foregroundStyle(gold.opacity(0.9))
            }
            .padding(.bottom, 56)
            .opacity(Double(tag)).offset(y: (1 - tag) * 12)
        }
        .opacity(out ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("آيات تتلى")
        .task {
            if reduceMotion { onDone(); return }
            withAnimation(.linear(duration: 2.6)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9)) { draw = 1 }
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { ring = 1 }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.52)) { logo = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) { tag = 1 }
            try? await Task.sleep(nanoseconds: 2_150_000_000)
            withAnimation(.easeIn(duration: 0.38)) { out = true }
            try? await Task.sleep(nanoseconds: 400_000_000)
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
