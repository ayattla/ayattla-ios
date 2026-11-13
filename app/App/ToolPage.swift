import SwiftUI
import AyatDesign

// Tool pages v4 (owner, 12 Nov): the site's new tool page head, made native. Every tool on
// ayattla.com/tools/* now opens with the same card: a soft wash of the tool's own colour, the
// «الرئيسية / الأدوات / …» crumbs pill, the tool icon on its colour next to the title, the
// one-line description, and here also the site's «أدوات ذات صلة» as chips to jump between tools.

/// The site's per-family tool colours (`--tacc`, light and dark), from its stylesheet.
enum ToolAccent {
    struct Pair { let light: UInt32; let dark: UInt32 }

    static let worship = Pair(light: 0x9A6516, dark: 0xD9A441)   // azkar, duas, tasbih, hisn
    static let prayer = Pair(light: 0x1D6670, dark: 0x5FB3BC)    // prayer times, qibla, mosques, guide
    static let calendar = Pair(light: 0x2E4380, dark: 0x93A6E0)  // hijri, occasions, fasting
    static let money = Pair(light: 0x7A5F28, dark: 0xCBB06E)     // zakat, missed prayers
    static let hadith = Pair(light: 0x7A4E2D, dark: 0xC9935E)    // hadith, checker, hadith card
    static let quran = Pair(light: 0x2E9145, dark: 0x4FBF6A)     // the site green for the rest

    static func pair(_ id: String) -> Pair {
        switch id {
        case "azkar", "duas", "tasbih", "hisn-almuslim", "ruqya": worship
        case "prayer-times", "qibla", "nearby-mosques", "prayer-guide": prayer
        case "hijri", "occasions", "sawm-tracker": calendar
        case "zakat", "qada-salah": money
        case "hadith", "hadith-checker", "hadith-card": hadith
        default: quran
        }
    }

    static func color(_ id: String) -> Color {
        let p = pair(id)
        return Color(light: p.light, dark: p.dark)
    }
}

extension SiteTool {
    var accent: Color { ToolAccent.color(id) }

    /// The site's «أدوات ذات صلة» for each tool page (read from ayattla.com, 12 Nov 2026).
    static let related: [String: [String]] = [
        "asma-ul-husna": ["mushaf", "listen", "tajweed"], "ayah-card": ["hadith-card", "favorites", "listen"],
        "ayah-of-the-day": ["mushaf", "listen", "tajweed"], "azkar": ["duas", "prayer-times", "qibla"],
        "duas": ["azkar", "prayer-times", "qibla"], "favorites": ["ayah-card", "hadith-card", "listen"],
        "group-khatma": ["mushaf", "listen", "tajweed"], "hadith-card": ["ayah-card", "favorites", "listen"],
        "hadith-checker": ["hadith", "prayer-guide", "kids-juz-amma"], "hadith": ["hadith-checker", "prayer-guide", "kids-juz-amma"],
        "hifz-test": ["mushaf", "listen", "tajweed"], "hijri": ["azkar", "duas", "prayer-times"],
        "khatma": ["mushaf", "listen", "tajweed"], "kids-juz-amma": ["hadith", "hadith-checker", "prayer-guide"],
        "listen": ["mushaf", "tajweed", "word-by-word"], "mushaf": ["listen", "tajweed", "word-by-word"],
        "nearby-mosques": ["azkar", "duas", "prayer-times"], "occasions": ["azkar", "duas", "prayer-times"],
        "prayer-guide": ["hadith", "hadith-checker", "kids-juz-amma"], "prayer-times": ["azkar", "duas", "qibla"],
        "qada-salah": ["azkar", "duas", "prayer-times"], "qibla": ["azkar", "duas", "prayer-times"],
        "radio": ["mushaf", "listen", "tajweed"], "ruqya": ["mushaf", "listen", "tajweed"],
        "sawm-tracker": ["azkar", "duas", "prayer-times"], "search": ["mushaf", "listen", "tajweed"],
        "tajweed": ["mushaf", "listen", "word-by-word"], "tasbih": ["azkar", "duas", "prayer-times"],
        "word-by-word": ["mushaf", "listen", "tajweed"], "zakat": ["qada-salah", "sawm-tracker", "prayer-times"],
        "hisn-almuslim": ["azkar", "duas", "ruqya"], "topics": ["search", "favorites", "ayah-card"],
        // Not listed on the site (its clip maker is the home page): the app's own choice.
        "clip": ["ayah-card", "status", "listen"], "status": ["ayah-card", "clip", "hadith-card"],
    ]

    var relatedTools: [SiteTool] { (Self.related[id] ?? []).compactMap(SiteTool.tool) }
}

/// The site's tool page head (`.page-head` on /tools/*), for the tool with `id`.
struct ToolPageHead: View {
    let id: String
    var subtitle: String?

    var body: some View {
        if let t = SiteTool.tool(id) {
            content(t)
        }
    }

    private func content(_ t: SiteTool) -> some View {
        let a = t.accent
        return VStack(spacing: 12) {
            // «الرئيسية / الأدوات / …»
            HStack(spacing: 6) {
                Text("الرئيسية").foregroundStyle(a)
                Text("/").foregroundStyle(Brand.muted)
                Text("الأدوات").foregroundStyle(a)
                Text("/").foregroundStyle(Brand.muted)
                Text(t.shortTitle).foregroundStyle(Brand.ink).lineLimit(1)
            }
            .font(.ui(.caption, .semibold))
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(a.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(a.opacity(0.18), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("الأدوات، \(t.title)")

            HStack(spacing: 12) {
                Image(systemName: t.symbol)
                    .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(a, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(color: a.opacity(0.45), radius: 10, y: 6)
                    .accessibilityHidden(true)
                Text(t.title).font(.ui(.title2, .bold)).foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(subtitle ?? t.subtitle).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            let rel = t.relatedTools
            if !rel.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rel) { r in
                            NavigationLink { r.destination.onAppear { ToolUsage.record(r.id) } } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: r.symbol).font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(r.accent)
                                    Text(r.shortTitle).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                                }
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(Brand.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(Brand.line, lineWidth: 1))
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("أداة ذات صلة: \(r.title)")
                        }
                    }
                    .padding(.horizontal, 2).padding(.vertical, 1)
                }
                .scrollClipDisabled()
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [a.opacity(0.14), Brand.surface.opacity(0)], startPoint: .top, endPoint: .init(x: 0.5, y: 0.85)))
                .background(Brand.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(a.opacity(0.22), lineWidth: 1))
        .shadow(color: Color(hex: 0x0F1F17).opacity(0.06), radius: 14, y: 6)
    }
}

/// The head as the first row of a `List` or `Form` tool screen.
struct ToolHeadSection: View {
    let id: String
    var subtitle: String?

    var body: some View {
        Section {
            ToolPageHead(id: id, subtitle: subtitle)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }
}
