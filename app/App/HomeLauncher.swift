import SwiftUI
import AyatDesign

// Home v3.2 (owner, 5 Nov): the home is for using the tools. The site's marketing sections
// (how it works, features, sources, numbers, questions) moved to «عن آيات تتلى» and «الأسئلة الشائعة».

extension SiteTool {
    /// Short names for the launcher grid (the full titles stay everywhere else).
    var shortTitle: String {
        [
            "clip": "صانع المقاطع", "ayah-card": "بطاقة آية", "status": "حالات واتساب",
            "listen": "المصحف المسموع", "search": "البحث", "topics": "بالموضوع", "favorites": "المحفوظة",
            "ayah-of-the-day": "آية اليوم", "radio": "الإذاعات", "prayer-times": "المواقيت", "qibla": "القبلة",
            "khatma": "خطة الختم", "hijri": "الهجري", "occasions": "المناسبات", "zakat": "الزكاة",
            "tasbih": "المسبحة", "hadith-card": "بطاقة حديث", "tajweed": "التجويد", "word-by-word": "معاني الكلمات",
            "hifz-test": "اختبار الحفظ", "duas": "الأدعية", "mushaf": "المصحف", "ruqya": "الرقية",
            "asma-ul-husna": "الأسماء الحسنى", "hadith": "الأحاديث", "hadith-checker": "تحقق من حديث",
            "prayer-guide": "الوضوء والصلاة", "kids-juz-amma": "تحفيظ الأطفال", "group-khatma": "الختمة الجماعية",
            "qada-salah": "قضاء الصلوات", "sawm-tracker": "متتبع الصيام", "nearby-mosques": "المساجد القريبة", "kaffarah": "الكفارات", "crypto-zakat": "زكاة الرقمية",
            "azkar": "الأذكار", "hisn-almuslim": "حصن المسلم", "offline": "بدون إنترنت", "journey": "رحلتي", "tasmee": "التسميع", "voice-search": "بحث بالصوت",
        ][id] ?? title
    }
}

/// The search box at the top of the home: opens «المزيد» with the keyboard up.
struct HomeToolSearch: View {
    var body: some View {
        NavigationLink { ToolsView(autoFocus: true) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Brand.primaryInk)
                Text("ابحث عن أداة: الأذكار، القبلة، الزكاة…").font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x0F1F17).opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("ابحث في الأدوات")
    }
}

/// Every tool by group as an app-style launcher: gradient icon and a short name, four or five to a
/// row, the group's count and «عرض الكل» opening the group in «المزيد». The three content makers
/// are left out (they lead the home as large cards).
struct HomeToolLauncher: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var zoom
    private static let featured: Set<String> = ["clip", "ayah-card", "status"]

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.l) {
            HomeHead("كل الأدوات", subtitle: "\(Num.int(SiteTool.all.count)) أداة مجانية في \(Num.int(SiteTool.Group.allCases.count)) أقسام", symbol: "square.grid.3x3")
            // Four calm section tiles (2×2) in the brand colours; the full lists stay in «المزيد».
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SiteTool.Group.allCases.filter { g in SiteTool.all.contains { $0.group == g } }) { g in
                    NavigationLink { ToolsView(filter: .group(g)) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: look(g).symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(Brand.primaryInk)
                                .frame(width: 42, height: 42)
                                .background(Brand.tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            Text(g.title).font(.ui(.subheadline, .bold)).foregroundStyle(Brand.ink).lineLimit(1)
                            Text("\(Num.int(SiteTool.all.filter { $0.group == g }.count)) أداة").font(.ui(.caption)).foregroundStyle(Brand.muted)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .surface(.tinted, radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Section colours, symbol and band.
    private func look(_ g: SiteTool.Group) -> (symbol: String, top: UInt32, bottom: UInt32) {
        switch g {
        case .content: ("play.rectangle.fill", 0x1F7A4E, 0x0E3B2C)
        case .quran: ("book.fill", 0x2A5C8A, 0x13304D)
        case .daily: ("sun.max.fill", 0xB0832F, 0x6B4A12)
        case .hadith: ("graduationcap.fill", 0x6B3F8E, 0x3A1F55)
        }
    }

    private func section(_ g: SiteTool.Group, _ tools: [SiteTool]) -> some View {
        let l = look(g)
        let makers = g == .content ? tools.filter { Self.featured.contains($0.id) } : []
        let rest = tools.filter { !makers.contains($0) }
        return VStack(spacing: 0) {
            NavigationLink { ToolsView(filter: .group(g)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: l.symbol).font(.ui(.title3, .semibold)).foregroundStyle(Color(hex: 0xF3DFA2))
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color(hex: 0xE3CB8E).opacity(0.55), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.title).font(.ui(.headline, .bold)).foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                        Text("\(Num.int(tools.count)) أداة").font(.ui(.caption, .semibold)).foregroundStyle(Color(hex: 0xF3DFA2))
                    }
                    .multilineTextAlignment(.leading)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("عرض الكل")
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    }
                    .font(.ui(.footnote, .semibold)).foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(LinearGradient(colors: [Color(hex: l.top), Color(hex: l.bottom)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .buttonStyle(.plain)
            if !makers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(makers.enumerated()), id: \.element.id) { i, t in
                        NavigationLink { t.destination.onAppear { ToolUsage.record(t.id) } } label: {
                            VStack(spacing: 8) {
                                Image(systemName: t.symbol).font(.ui(.title2, .semibold)).foregroundStyle(Color(hex: 0xF3DFA2))
                                Text(t.shortTitle).font(.ui(.footnote, .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient(colors: [Color(hex: [0x1F7A4E, 0x2A5C8A, 0xB0832F][i % 3]), Color(hex: 0x0E2A20)],
                                                       startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding([.horizontal, .top], 12)
            }
            LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                ForEach(rest) { t in
                    NavigationLink {
                        t.destination
                            .onAppear { ToolUsage.record(t.id) }
                            .navigationTransition(.zoom(sourceID: t.id, in: zoom))
                    } label: { tile(t).matchedTransitionSource(id: t.id, in: zoom) }
                        .buttonStyle(.pressable)
                }
            }
            .padding(12)
        }
        .surface(.raised)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    private func tile(_ t: SiteTool) -> some View {
        VStack(spacing: 7) {
            IconTile(t.symbol, style: .accent(t.accent), size: 54)
                .overlay(alignment: .topTrailing) {
                    if t.isNew {
                        Circle().fill(Brand.accent).frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(Brand.surface, lineWidth: 2))
                            .offset(x: 3, y: -3)
                            .accessibilityHidden(true)
                    }
                }
            Text(t.shortTitle).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .offlineDim(t)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.isNew ? "\(t.title)، جديد" : t.title)
        .accessibilityHint(t.subtitle)
    }

    private var columns: [GridItem] {
        let n = typeSize.isAccessibilitySize ? 2 : (typeSize >= .xxLarge ? 3 : 4)
        return Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: n)
    }
}

/// «عن آيات تتلى»: the site's how it works, features, sources, numbers and closing call.
struct AboutAppView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.xxl) {
                VStack(spacing: 8) {
                    Image("LogoFull").resizable().scaledToFit().frame(width: 76, height: 76)
                        .accessibilityHidden(true)
                    Text("آيات تتلى كلمة كلمة في مقطع جاهز للنشر").font(.ui(.title3, .bold)).foregroundStyle(Brand.ink)
                        .multilineTextAlignment(.center)
                    Text("مجاني بالكامل، بدون تسجيل، بدون علامة مائية").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                }
                .frame(maxWidth: .infinity)
                HomeSteps()
                HomeFeatures()
                HomeStats()
                HomeClosing()
                Text("© آيات تتلى — ayattla.com").font(.ui(.caption2)).foregroundStyle(Brand.muted)
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("عن آيات تتلى")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// «الأسئلة الشائعة» on its own page.
struct FAQView: View {
    var body: some View {
        ScrollView {
            HomeFAQ()
                .padding(Brand.Space.l)
                .frame(maxWidth: Brand.readableWidth)
                .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("الأسئلة الشائعة")
        .navigationBarTitleDisplayMode(.inline)
    }
}
