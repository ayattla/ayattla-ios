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
            "qada-salah": "قضاء الصلوات", "sawm-tracker": "متتبع الصيام", "nearby-mosques": "المساجد القريبة",
            "azkar": "الأذكار", "hisn-almuslim": "حصن المسلم",
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
            SiteSectionHead(eyebrow: "الأدوات", "كل الأدوات في مكان واحد",
                            subtitle: "\(Num.int(SiteTool.all.count)) أداة مجانية، اضغط أي أداة لتفتحها")
            ForEach(SiteTool.Group.allCases) { g in
                let tools = SiteTool.all.filter { $0.group == g && !Self.featured.contains($0.id) }
                if !tools.isEmpty { section(g, tools) }
            }
        }
    }

    private func section(_ g: SiteTool.Group, _ tools: [SiteTool]) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            HStack(spacing: 8) {
                Capsule().fill(Brand.siteGradient).frame(width: 4, height: 18)
                Text(g.title).font(.ui(.headline)).foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
                Text(Num.int(tools.count)).font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(Brand.tint, in: Capsule())
                Spacer()
                NavigationLink { ToolsView(filter: .group(g)) } label: {
                    HStack(spacing: 2) {
                        Text("عرض الكل")
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    }
                    .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                    .frame(minHeight: Brand.minTap)
                }
            }
            LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                ForEach(tools) { t in
                    NavigationLink {
                        t.destination
                            .onAppear { ToolUsage.record(t.id) }
                            .navigationTransition(.zoom(sourceID: t.id, in: zoom))
                    } label: { tile(t).matchedTransitionSource(id: t.id, in: zoom) }
                        .buttonStyle(.pressable)
                }
            }
        }
        .padding(Brand.Space.l)
        .surface(.raised)
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
                HomeSources()
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
