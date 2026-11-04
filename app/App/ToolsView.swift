import SwiftUI
import AyatDesign
import AyatCalc

/// Every tool of the Tools tab (docs/APP_ARCHITECTURE.md §1). Tools that depend on the content
/// pack or on behaviour not yet confirmed on the site show a placeholder until they are built.
enum ToolItem: String, CaseIterable, Identifiable {
    case azkar, tasbih, duas, prayer, qibla, hijri, occasions, zakat, qada, sawm, mosques, hadith, hadithChecker, prayerGuide, kids
    var id: String { rawValue }

    var title: String {
        switch self {
        case .azkar: "الأذكار"
        case .tasbih: "المسبحة"
        case .duas: "الأدعية"
        case .prayer: "مواقيت الصلاة"
        case .qibla: "القبلة"
        case .hijri: "الهجري"
        case .occasions: "المناسبات"
        case .zakat: "الزكاة"
        case .qada: "قضاء الصلوات"
        case .sawm: "الصيام"
        case .mosques: "المساجد"
        case .hadith: "الأحاديث"
        case .hadithChecker: "التحقق من حديث"
        case .prayerGuide: "صفة الوضوء والصلاة"
        case .kids: "تحفيظ الأطفال جزء عم"
        }
    }

    var symbol: String {
        switch self {
        case .azkar: "sun.max"
        case .tasbih: "circle.circle"
        case .duas: "hands.sparkles"
        case .prayer: "clock"
        case .qibla: "location.north.line"
        case .hijri: "calendar"
        case .occasions: "star"
        case .zakat: "percent"
        case .qada: "checklist"
        case .sawm: "moon"
        case .mosques: "mappin.and.ellipse"
        case .hadith: "text.book.closed"
        case .hadithChecker: "checkmark.seal"
        case .prayerGuide: "drop"
        case .kids: "star.circle"
        }
    }

    var isReady: Bool { true }

    @ViewBuilder var destination: some View {
        switch self {
        case .prayer: PrayerTimesView()
        case .qibla: QiblaView()
        case .hijri: HijriView()
        case .occasions: OccasionsView()
        case .zakat: ZakatView()
        case .mosques: MosquesView()
        case .azkar: AzkarView()
        case .tasbih: TasbihView()
        case .qada: QadaView()
        case .duas: DuasView()
        case .hadith: HadithView()
        case .hadithChecker: HadithCheckerView()
        case .prayerGuide: PrayerGuideView()
        case .kids: KidsJuzAmmaView()
        case .sawm: SawmView()
        default: PlaceholderScreen(title: title)
        }
    }

    static let today: [ToolItem] = [.azkar, .tasbih, .duas]
    static let worship: [ToolItem] = [.hijri, .zakat, .qada, .sawm, .mosques, .hadith]
}

/// «المزيد» tab: the site's /tools/ page — page head, search, group filter chips, then every tool
/// as a coloured card in a grid. A short "today" strip (next prayer, library, settings) leads it.
struct ToolsView: View {
    enum Filter: Hashable { case all, group(SiteTool.Group), new }

    @State private var query = ""
    @State private var filter = Filter.all
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var size

    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.xl) {
                HeroHeader(eyebrow: "الأدوات", title: "أدوات تكمل يومك مع القرآن",
                           subtitle: "\(Num.int(SiteTool.all.count)) أداة مجانية تعمل على جهازك: بطاقات الآيات، المصحف المسموع للتحفيظ، البحث في القرآن، الأذكار، الإذاعات، مواقيت الصلاة، القبلة، خطة الختمة، الزكاة، والمناسبات.") {
                    searchField.padding(.top, Brand.Space.s)
                }

                CategorySelector(filters, selection: $filter)
                    .padding(.horizontal, -Brand.Space.l)

                if query.isEmpty && filter == .all { todayStrip }

                if results.isEmpty {
                    EmptyState("لا توجد أداة بهذا الاسم", symbol: "magnifyingglass", message: "جرب كلمة أخرى مثل الأذكار أو القبلة")
                } else {
                    LazyVGrid(columns: columns, spacing: Brand.Space.m) {
                        ForEach(results) { t in
                            NavigationLink { t.destination } label: { SiteToolCard(tool: t) }
                                .buttonStyle(.pressable)
                        }
                    }
                }

                Label("كل الأدوات مجانية وبدون تسجيل، وما تحفظه (مثل عداد التسبيح وتقدم الختمة) يبقى على جهازك فقط.",
                      systemImage: "lock.shield")
                    .font(.ui(.footnote)).foregroundStyle(Brand.goldInk)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.goldSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .trailing) { Capsule().fill(Brand.accent).frame(width: 3).padding(.vertical, 8) }
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("المزيد")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var columns: [GridItem] {
        let n = typeSize.isAccessibilitySize ? 1 : (size == .regular ? 3 : 2)
        return Array(repeating: GridItem(.flexible(), spacing: Brand.Space.m, alignment: .top), count: n)
    }

    private var filters: [(id: Filter, title: String)] {
        [(.all, "الكل")] + SiteTool.Group.allCases.map { (.group($0), $0.title) } + [(.new, "جديد")]
    }

    private var results: [SiteTool] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return SiteTool.all.filter { t in
            switch filter {
            case .all: true
            case .group(let g): t.group == g
            case .new: t.isNew
            }
        }
        .filter { q.isEmpty || $0.title.localizedStandardContains(q) || $0.subtitle.localizedStandardContains(q) }
    }

    /// Site-style search box («ابحث في الأدوات: مثلا الأذكار أو القبلة»).
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Brand.muted)
            TextField("ابحث في الأدوات: مثلا الأذكار أو القبلة", text: $query)
                .font(.ui(.subheadline))
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.lineStrong) }
                    .accessibilityLabel("مسح البحث")
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
    }

    /// Next prayer as a wide card, then the library and settings side by side (bento row).
    private var todayStrip: some View {
        VStack(spacing: Brand.Space.m) {
            NextPrayerCard()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.Space.m), count: typeSize.isAccessibilitySize ? 1 : 2),
                      spacing: Brand.Space.m) {
                NavigationLink { LibraryView() } label: {
                    ServiceCard("مكتبتي", subtitle: "المشاريع والمفضلة والتنزيلات", symbol: "square.stack.3d.up", style: .emerald, layout: .row)
                }
                NavigationLink { SettingsView() } label: {
                    ServiceCard("الإعدادات", subtitle: "القارئ والخط والتنبيهات", symbol: "gearshape", style: .soft, layout: .row)
                }
            }
            .buttonStyle(.pressable)
        }
    }
}

struct ToolTile: View {
    let item: ToolItem
    var body: some View {
        LauncherTile(item.title, symbol: item.symbol)
    }
}

struct ToolRow: View {
    let item: ToolItem
    var body: some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if !item.isReady { Text("قيد البناء").font(.ui(.caption)).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: item.symbol).foregroundStyle(Brand.primary)
        }
        .frame(minHeight: Brand.minTap)
    }
}

struct AllToolsView: View {
    var body: some View {
        List(ToolItem.allCases) { item in
Group {
            NavigationLink { item.destination } label: { ToolRow(item: item) }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("كل الأدوات")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "Next prayer" as the site's gradient feature band (white text on --s-grad), with the qibla.
struct NextPrayerCard: View {
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name

    var body: some View {
        let city = PrayerCity.named(cityName) ?? PrayerCity.all[0]
        let place = PrayerTimesView.Place(name: city.name, lat: city.lat, lng: city.lng,
                                          zone: TimeZone(identifier: city.zone) ?? .current, method: city.method)
        TimelineView(.everyMinute) { ctx in
            let d = PrayerTimesView.Day(place: place, now: ctx.date)
            let t = d.next.isTomorrow ? d.tomorrow.fajr : d.today.hours(d.next.prayer)
            HStack(spacing: 12) {
                NavigationLink { PrayerTimesView() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("الصلاة القادمة").font(.ui(.footnote, .medium)).opacity(0.85)
                        Text("\(d.next.prayer.name) · \(Num.time(t))").font(.ui(.title2, .bold))
                        Text("\(place.name) · بعد \(Num.duration(minutes: d.next.minutesUntil))")
                            .font(.ui(.footnote)).opacity(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                NavigationLink { QiblaView() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "location.north.line.fill").font(.ui(.title3))
                        Text("القبلة").font(.ui(.caption2, .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                }
                .accessibilityLabel("القبلة")
            }
            .padding(18)
            .featureSurface(radius: Brand.Radius.hero)
        }
    }
}
