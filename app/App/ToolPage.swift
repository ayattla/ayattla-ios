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
        "hifz-plan": ["hifz-test", "mushaf", "listen"], "kids-quiz": ["kids-juz-amma", "hifz-test", "listen"],
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

    /// Kept short (clean tool pages): the title is already in the navigation bar, so the head only
    /// carries the related tools, as one row of shortcuts. `subtitle` is accepted and not shown.
    @ViewBuilder private func content(_ t: SiteTool) -> some View {
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
