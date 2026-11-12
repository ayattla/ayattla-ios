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

/// How often each tool is opened, on this device only, for «الأكثر استخداما».
enum ToolUsage {
    static let key = "tools.usage"
    static var counts: [String: Int] {
        get { (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func record(_ id: String) { var c = counts; c[id, default: 0] += 1; counts = c }

    /// Most used first; the site's own leading tools fill the row until there is history.
    static func top(_ n: Int) -> [SiteTool] {
        let c = counts
        let used = SiteTool.all.filter { (c[$0.id] ?? 0) > 0 }.sorted { (c[$0.id] ?? 0) > (c[$1.id] ?? 0) }
        let defaults = ["listen", "prayer-times", "azkar", "qibla", "tasbih", "search", "hadith-card", "khatma"]
            .compactMap { id in SiteTool.all.first { $0.id == id } }
        var out: [SiteTool] = []
        for t in used + defaults where !out.contains(where: { $0.id == t.id }) { out.append(t) }
        return Array(out.prefix(n))
    }
}

/// «المزيد» tab: the site's /tools/ page — a compact head with quick search, group chips, the most
/// used tools within one tap, the three content makers as large cards, then each group under its
/// own heading as tidy rows (no tall half-empty cards).
struct ToolsView: View {
    enum Filter: Hashable { case all, group(SiteTool.Group), new }

    @State private var query = ""
    @State private var filter: Filter
    private let autoFocus: Bool
    @State private var usageTick = 0
    @FocusState private var searching: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var zoom
    @Environment(\.horizontalSizeClass) private var size

    /// `filter` opens one group (from the home's «عرض الكل»); `autoFocus` puts the cursor in the search box.
    init(filter: Filter = .all, autoFocus: Bool = false) {
        _filter = State(initialValue: filter)
        self.autoFocus = autoFocus
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                head
                CategorySelector(filters, selection: $filter)
                    .padding(.horizontal, -Brand.Space.l)

                if browsing {
                    frequent
                    featured
                    NextPrayerCard()
                    ForEach(SiteTool.Group.allCases) { g in group(g) }
                    quickLinks
                } else if results.isEmpty {
                    EmptyState("لا توجد أداة بهذا الاسم", symbol: "magnifyingglass", message: "جرب كلمة أخرى مثل الأذكار أو القبلة")
                        .frame(minHeight: 240)
                } else {
                    if !query.isEmpty {
                        Text("\(Num.int(results.count)) نتيجة").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.muted)
                    }
                    rows(results)
                }

                Label("كل الأدوات مجانية وبدون تسجيل، وما تحفظه (مثل عداد التسبيح وتقدم الختمة) يبقى على جهازك فقط.",
                      systemImage: "lock.shield")
                    .font(.ui(.footnote)).foregroundStyle(Brand.goldInk)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.goldSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .trailing) { Capsule().fill(Brand.accent).frame(width: 3).padding(.vertical, 8) }
            }
            .padding(.horizontal, Brand.Space.l).padding(.top, Brand.Space.s).padding(.bottom, Brand.Space.xl)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .brandScreen()
        .navigationTitle("المزيد")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { usageTick += 1 }
        .task { if autoFocus { try? await Task.sleep(for: .milliseconds(450)); searching = true } }
    }

    private var browsing: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty && filter == .all }

    /// Title, count and the search box in one short white band.
    private var head: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("أدوات تكمل يومك مع القرآن").font(.ui(.title2, .bold)).foregroundStyle(Brand.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(Num.int(SiteTool.all.count)) أداة مجانية تعمل على جهازك").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                }
                Spacer(minLength: 0)
            }
            searchField
        }
        .padding(Brand.Space.l)
        .pageHeadSurface()
    }

    /// «الأكثر استخداما»: one-tap row of the tools opened most on this device.
    private var frequent: some View {
        let _ = usageTick
        let hasHistory = !ToolUsage.counts.isEmpty
        return VStack(alignment: .leading, spacing: Brand.Space.s) {
            Text(hasHistory ? "الأكثر استخداما" : "وصول سريع").font(.ui(.headline)).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ToolUsage.top(8)) { t in
                        NavigationLink { open(t, "f") } label: {
                            VStack(spacing: 6) {
                                IconTile(t.symbol, style: .solid(t.accent), size: 50)
                                Text(t.title).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                                    .frame(width: 84)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 88)
                            .matchedTransitionSource(id: "f" + t.id, in: zoom)
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Brand.Space.l).padding(.vertical, 2)
            }
            .padding(.horizontal, -Brand.Space.l)
        }
    }

    /// The three content makers, larger than the rest (clip full width, card and status halves).
    private var featured: some View {
        let ids = ["clip", "ayah-card", "status"]
        let tools = ids.compactMap { id in SiteTool.all.first { $0.id == id } }
        return VStack(spacing: Brand.Space.m) {
            if let clip = tools.first {
                NavigationLink { open(clip, "c") } label: {
                    HStack(spacing: Brand.Space.m) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(clip.title).font(.ui(.title3, .bold)).foregroundStyle(.white)
                                if clip.isNew { Badge("جديد", gold: true) }
                            }
                            Text(clip.subtitle).font(.ui(.footnote)).foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: clip.symbol).font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(20)
                    .featureSurface()
                    .matchedTransitionSource(id: "c" + clip.id, in: zoom)
                }
                .buttonStyle(.pressable)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.Space.m, alignment: .top),
                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: Brand.Space.m) {
                ForEach(tools.dropFirst()) { t in
                    NavigationLink { open(t, "x") } label: { SiteToolCard(tool: t).matchedTransitionSource(id: "x" + t.id, in: zoom) }
                        .buttonStyle(.pressable)
                }
            }
        }
    }

    /// One group: title with the count, then tidy rows.
    private func group(_ g: SiteTool.Group) -> some View {
        let featuredIDs: Set<String> = ["clip", "ayah-card", "status"]
        let tools = SiteTool.all.filter { $0.group == g && !featuredIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: Brand.Space.s) {
            HStack(spacing: 8) {
                Capsule().fill(Brand.siteGradient).frame(width: 4, height: 20)
                Text(g.title).font(.ui(.headline)).foregroundStyle(Brand.ink).accessibilityAddTraits(.isHeader)
                Text(Num.int(tools.count)).font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(Brand.tint, in: Capsule())
                Spacer()
                Button { withAnimation(.snappy) { filter = .group(g) } } label: {
                    Text("عرض الكل").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk).frame(minHeight: Brand.minTap)
                }
            }
            rows(tools)
        }
    }

    private func rows(_ tools: [SiteTool]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(tools) { t in
                NavigationLink { open(t, "r") } label: {
                    ServiceCard(t.title, subtitle: t.subtitle, symbol: t.symbol, badge: t.isNew ? "جديد" : nil,
                                style: .accent(t.accent), layout: .row)
                        .matchedTransitionSource(id: "r" + t.id, in: zoom)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var quickLinks: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.Space.m), count: typeSize.isAccessibilitySize ? 1 : 2),
                  spacing: Brand.Space.m) {
            NavigationLink { LibraryView() } label: {
                ServiceCard("مكتبتي", subtitle: "المشاريع والمفضلة والتنزيلات", symbol: "square.stack.3d.up", style: .emerald, layout: .row)
            }
            NavigationLink { SettingsView() } label: {
                ServiceCard("الإعدادات", subtitle: "القارئ والخط والتنبيهات", symbol: "gearshape", style: .soft, layout: .row)
            }
            NavigationLink { AboutAppView() } label: {
                ServiceCard("عن آيات تتلى", subtitle: "طريقة العمل والمزايا والمصادر", symbol: "info.circle", style: .soft, layout: .row)
            }
            NavigationLink { FAQView() } label: {
                ServiceCard("الأسئلة الشائعة", subtitle: "إجابات مختصرة عن الأدوات", symbol: "questionmark.circle", style: .soft, layout: .row)
            }
        }
        .buttonStyle(.pressable)
    }

    /// The tool's screen; opening it counts for «الأكثر استخداما».
    private func open(_ t: SiteTool, _ from: String) -> some View {
        // The tool grows out of the card that was tapped (iOS 18 zoom transition).
        t.destination
            .onAppear { ToolUsage.record(t.id) }
            .navigationTransition(.zoom(sourceID: from + t.id, in: zoom))
    }

    private var columns: [GridItem] {
        let n = typeSize.isAccessibilitySize ? 1 : (size == .regular ? 2 : 1)
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: n)
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

    /// Site-style search box («ابحث في الأدوات: مثلا الأذكار أو القبلة»); filters as you type.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Brand.muted)
            TextField("ابحث في الأدوات: مثلا الأذكار أو القبلة", text: $query)
                .font(.ui(.subheadline))
                .submitLabel(.search)
                .focused($searching)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.muted) }
                    .accessibilityLabel("مسح البحث")
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(searching ? Brand.green : Brand.line, lineWidth: searching ? 1.5 : 1))
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
