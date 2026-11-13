import SwiftUI
import AyatDesign

/// «خدمات المسلم» (owner, 13 Nov): the daily religious services as decorative round icons, each
/// in its tool colour with a soft ring and glow, centred under a small ornament, each opening its tool.
/// Only names and icons here: no religious text.
struct HomeServices: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var zoom
    @State private var glow = false

    static let ids = [
        "prayer-times", "qibla", "nearby-mosques", "azkar",
        "hisn-almuslim", "duas", "tasbih", "asma-ul-husna",
        "ruqya", "hijri", "occasions", "zakat",
    ]

    private var tools: [SiteTool] { Self.ids.compactMap(SiteTool.tool) }

    var body: some View {
        VStack(spacing: Brand.Space.l) {
            SiteSectionHead(eyebrow: "خدمات", "خدمات المسلم اليومية", subtitle: "الصلاة والذكر والدعاء والتقويم، بلمسة واحدة")
            LazyVGrid(columns: columns, alignment: .center, spacing: 20) {
                ForEach(tools) { t in
                    NavigationLink {
                        t.destination
                            .onAppear { ToolUsage.record(t.id) }
                            .navigationTransition(.zoom(sourceID: "s" + t.id, in: zoom))
                    } label: {
                        badge(t).matchedTransitionSource(id: "s" + t.id, in: zoom)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.vertical, Brand.Space.xl).padding(.horizontal, Brand.Space.s)
            .frame(maxWidth: .infinity)
            .background { backdrop }
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.hero, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.Radius.hero, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func badge(_ t: SiteTool) -> some View {
        let a = t.accent
        return VStack(spacing: 8) {
            ZStack {
                // Soft halo, then a thin ring, then the solid icon disc.
                Circle().fill(a.opacity(glow ? 0.20 : 0.10)).frame(width: 70, height: 70)
                    .blur(radius: 6)
                Circle().strokeBorder(
                    AngularGradient(colors: [a.opacity(0.9), a.opacity(0.25), a.opacity(0.9)], center: .center),
                    lineWidth: 1.5
                )
                .frame(width: 64, height: 64)
                Circle()
                    .fill(LinearGradient(colors: [a, a.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 52, height: 52)
                    .shadow(color: a.opacity(0.35), radius: 8, y: 4)
                Image(systemName: t.symbol)
                    .font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            Text(t.shortTitle).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.title)
        .accessibilityHint(t.subtitle)
    }

    /// The card's backdrop: the page tint with two faint ornamental stars in opposite corners.
    private var backdrop: some View {
        ZStack {
            Brand.surface2
            RadialGradient(colors: [Brand.green.opacity(0.12), .clear], center: .top, startRadius: 0, endRadius: 260)
            ornament.frame(width: 120, height: 120).offset(x: -150, y: -130)
            ornament.frame(width: 90, height: 90).offset(x: 160, y: 150)
        }
        .accessibilityHidden(true)
    }

    private var ornament: some View {
        // An eight-pointed star from two squares, as in Islamic geometric patterns.
        ZStack {
            RoundedRectangle(cornerRadius: 6).strokeBorder(Brand.green.opacity(0.14), lineWidth: 1.5)
            RoundedRectangle(cornerRadius: 6).strokeBorder(Brand.green.opacity(0.14), lineWidth: 1.5).rotationEffect(.degrees(45))
            Circle().strokeBorder(Brand.green.opacity(0.10), lineWidth: 1).padding(22)
        }
    }

    private var columns: [GridItem] {
        let n = typeSize.isAccessibilitySize ? 2 : (typeSize >= .xxLarge ? 3 : 4)
        return Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: n)
    }
}
