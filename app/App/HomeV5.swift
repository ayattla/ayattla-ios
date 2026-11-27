import SwiftUI
import AyatDesign
import AyatCalc
import AyatContent

// MARK: - Layout («تخصيص الرئيسية»)

/// Home sections the user can order and hide. New sections from updates join at the end, shown.
enum HomeSectionID: String, CaseIterable, Identifiable {
    case prayer, daily, forYou, journey, create, tools, today, wird, tracker, dhikr, ayah, quiz, gallery, presets, recent, services, head, name, dua
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prayer: "الصلاة القادمة"
        case .daily: "يومي"
        case .forYou: "اختصاراتك"
        case .journey: "رحلتي مع القرآن"
        case .tracker: "صلواتي اليوم"
        case .services: "الوصول السريع"
        case .dhikr: "الذكر السريع"
        case .head: "الترحيب والبحث"
        case .wird: "الورد والختمة"
        case .quiz: "مسابقة اليوم"
        case .create: "صناعة المحتوى"
        case .today: "تابع من حيث توقفت"
        case .tools: "كل الأدوات"
        case .ayah: "آية اليوم"
        case .gallery: "معرض الخلفيات"
        case .presets: "القوالب الجاهزة"
        case .recent: "مشاريعي الأخيرة"
        case .name: "اسم الله اليوم"
        case .dua: "دعاء من القرآن"
        }
    }
}

struct HomeLayoutItem: Equatable { var id: HomeSectionID; var shown: Bool }

extension HomeSectionID {
    /// Off until turned on: the greeting and search repeat the prayer card and the toolbar search,
    /// and the full grid repeats «الوصول السريع».
    /// Home 6: every section in a studied order (same as Android) — the day, shortcuts, the Quran,
    /// remembrance, learning, then making content and every tool. Only true repeats start hidden.
    static let defaultOrder: [HomeSectionID] = [.prayer, .daily, .tracker, .forYou, .today, .journey, .wird, .ayah, .dhikr, .name, .dua, .quiz, .create, .gallery, .presets, .recent, .tools]
    static var hiddenByDefault: Set<HomeSectionID> { [.head, .services] }
}

enum HomeLayoutStore {
    static let key = "home.layout.v8"
    static func decode(_ raw: String) -> [HomeLayoutItem] {
        // Before any manual arrangement: the order follows the first-run interests (nothing hidden).
        if raw.isEmpty {
            return (HomeSectionID.defaultOrder + HomeSectionID.allCases.filter { !HomeSectionID.defaultOrder.contains($0) })
                .map { .init(id: $0, shown: !HomeSectionID.hiddenByDefault.contains($0)) }
        }
        var out: [HomeLayoutItem] = raw.split(separator: ",").compactMap { e in
            let p = e.split(separator: ":")
            guard let n = p.first, let s = HomeSectionID(rawValue: String(n)) else { return nil }
            return HomeLayoutItem(id: s, shown: p.count < 2 || p[1] != "0")
        }
        // «يومي» (2.6) joins right after the prayer card, even in an arrangement saved before it existed.
        if !out.contains(where: { $0.id == .daily }) {
            let i = out.firstIndex(where: { $0.id == .prayer }).map { $0 + 1 } ?? 0
            out.insert(.init(id: .daily, shown: true), at: i)
        }
        // «دعاء من القرآن» joins right after «اسم الله اليوم» for those who saved a layout before it.
        if !out.contains(where: { $0.id == .dua }), let i = out.firstIndex(where: { $0.id == .name }) {
            out.insert(.init(id: .dua, shown: true), at: i + 1)
        }
        for s in HomeSectionID.allCases where !out.contains(where: { $0.id == s }) { out.append(.init(id: s, shown: false)) }
        return out
    }
    static func encode(_ l: [HomeLayoutItem]) -> String { l.map { "\($0.id.rawValue):\($0.shown ? 1 : 0)" }.joined(separator: ",") }
}

// MARK: - Prayer hero

/// The next prayer with a live countdown, progress since the last one, the five times and quick actions.
struct PrayerHeroCard: View {
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name

    var body: some View {
        let city = PrayerCity.named(cityName) ?? PrayerCity.all[0]
        let place = PrayerTimesView.Place(name: city.name, lat: city.lat, lng: city.lng,
                                          zone: TimeZone(identifier: city.zone) ?? .current, method: city.method)
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let d = PrayerTimesView.Day(place: place, now: ctx.date)
            let info = Self.countdown(d, place: place, now: ctx.date)
            VStack(spacing: 8) {
                Text("\(HomeView.greeting(ctx.date)) · \(Num.hijri(ctx.date))")
                    .font(.ui(.footnote, .medium)).opacity(0.85)
                Text("صلاة \(d.next.prayer.name)").font(.ui(.title2, .bold))
                Text(info.text).font(.ui(size: 38, .semibold)).monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("بعد \(Num.duration(minutes: d.next.minutesUntil))")
                Text("\(place.name) · \(Num.time(d.next.isTomorrow ? d.tomorrow.fajr : d.today.hours(d.next.prayer)))")
                    .font(.ui(.footnote)).opacity(0.85)
                ProgressView(value: info.progress)
                    .tint(Color(hex: 0xE3CB8E))
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    ForEach(Prayer.allCases.filter(\.isPrayer)) { p in
                        let on = p == d.next.prayer
                        VStack(spacing: 2) {
                            Text(p.name).font(.ui(.caption2, on ? .bold : .medium)).lineLimit(1).minimumScaleFactor(0.7)
                            Text(Num.time(d.today.hours(p))).font(.ui(.caption, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.white.opacity(on ? 0.22 : 0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay { if on { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0xE3CB8E).opacity(0.7), lineWidth: 1) } }
                    }
                }
                .padding(.top, 6)
                HStack(spacing: 8) {
                    pill("القبلة", "location.north.line") { QiblaView() }
                    pill("المواقيت", "clock") { PrayerTimesView() }
                    pill("التنبيهات", "bell") { NotificationCenterView() }
                }
                .padding(.top, 4)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(20)
            .featureSurface(radius: Brand.Radius.hero)
        }
    }

    private func pill<D: View>(_ t: String, _ s: String, @ViewBuilder _ dest: @escaping () -> D) -> some View {
        NavigationLink { dest() } label: {
            Label(t, systemImage: s).font(.ui(.footnote, .semibold)).lineLimit(1)
                .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                .background(Color.white.opacity(0.14), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// "HH:MM:SS" until the next prayer and the fraction elapsed since the previous one.
    static func countdown(_ d: PrayerTimesView.Day, place: PrayerTimesView.Place, now: Date) -> (text: String, progress: Double) {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = place.zone
        let c = cal.dateComponents([.hour, .minute, .second], from: now)
        let nowSec = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        let left = max(0, (nowSec / 60 + d.next.minutesUntil) * 60 - nowSec)
        let five = Prayer.allCases.filter(\.isPrayer).map { PrayerTimes.displayMinute(d.today.hours($0)) * 60 }
        let prev = five.last(where: { $0 <= nowSec }) ?? (PrayerTimes.displayMinute(d.today.isha) * 60 - 86400)
        let span = max(1, nowSec + left - prev)
        let text = String(format: "%02d:%02d:%02d", left / 3600, (left % 3600) / 60, left % 60)
        return (text, min(1, max(0, Double(nowSec - prev) / Double(span))))
    }
}

// MARK: - Wird and khatma

struct HomeWirdCard: View {
    @AppStorage(KhatmaStore.key) private var raw = ""

    var body: some View {
        let plan = KhatmaStore.load(raw)
        VStack(spacing: Brand.Space.m) {
            CenteredHead("الورد والختمة")
            NavigationLink { KhatmaView() } label: {
                VStack(spacing: 12) {
                    let frac = plan.map { Double($0.completedDays.count) / Double(max(1, $0.days)) } ?? 0
                    ZStack {
                        Circle().stroke(Brand.tint, lineWidth: 7)
                        Circle().trim(from: 0, to: frac).stroke(Brand.green, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text(plan == nil ? "—" : "\(Num.int(Int(frac * 100)))٪").font(.ui(.subheadline, .bold)).foregroundStyle(Brand.primaryInk)
                    }
                    .frame(width: 74, height: 74)
                    VStack(spacing: 4) {
                        if let plan {
                            let day = min(max(1, plan.day(on: Date())), plan.days)
                            Text(plan.isFinished ? "أتممت الختمة" : "ورد اليوم\(plan.completedDays.contains(day) ? " ✓" : "")")
                                .font(.ui(.headline)).foregroundStyle(Brand.ink)
                            if let r = plan.range(day: day), !plan.isFinished {
                                Text("من صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound)) · اليوم \(Num.int(day)) من \(Num.int(plan.days))")
                                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)
                            }
                        } else {
                            Text("لا توجد خطة ختمة").font(.ui(.headline)).foregroundStyle(Brand.ink)
                            Text("حدد المدة ويقسمها التطبيق وردا يوميا").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .surface()
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Daily quiz

/// «مسابقة اليوم»: which surah is this ayah from? Built from the mushaf text only.
struct HomeDailyQuiz: View {
    @AppStorage("quiz.daily.score") private var score = 0
    @AppStorage("quiz.daily.total") private var total = 0
    @State private var extra = 0
    @State private var picked: Int?
    private let lib = ContentLibrary.shared

    struct Q { let ayah: Ayah; let options: [Int]; let answer: Int }

    static func make(seed: UInt64) -> Q? {
        var g = SeededRandom(seed: seed)
        let lib = ContentLibrary.shared
        for _ in 0..<20 {
            let s = Int.random(in: 1...114, using: &g)
            guard let sur = lib.surah(s), let list = try? lib.store?.ayat(surah: s, from: 1, to: sur.ayahCount), !list.isEmpty else { continue }
            let a = list[Int.random(in: 0..<list.count, using: &g)]
            if a.textUthmani.split(separator: " ").count < 6 { continue }
            var others = Array(1...114).filter { $0 != s }; others.shuffle(using: &g)
            var opts = Array(others.prefix(3)) + [s]; opts.shuffle(using: &g)
            return Q(ayah: a, options: opts, answer: opts.firstIndex(of: s) ?? 0)
        }
        return nil
    }

    var body: some View {
        let day = UInt64(Date().timeIntervalSince1970 / 86400)
        VStack(spacing: Brand.Space.m) {
            CenteredHead("مسابقة اليوم")
            if let q = Self.make(seed: day &* 7919 &+ UInt64(extra)) {
                VStack(spacing: 10) {
                    Label("من أي سورة هذه الآية؟", systemImage: "questionmark.circle").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.goldInk)
                    Text(q.ayah.textUthmani).font(.custom(ContentLibrary.mushafFont, size: 21, relativeTo: .title3))
                        .lineSpacing(10).multilineTextAlignment(.center).lineLimit(4).foregroundStyle(Brand.ink)
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, s in
                        let right = i == q.answer
                        Button {
                            guard picked == nil else { return }
                            picked = i; total += 1; if right { score += 1 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Text(lib.surah(s)?.namePlain ?? "").font(.ui(.body, .semibold))
                                if picked != nil && right { Image(systemName: "checkmark").foregroundStyle(Brand.green) }
                            }
                            .foregroundStyle(Brand.ink).frame(maxWidth: .infinity, minHeight: 46)
                            .background(picked == nil ? Brand.surface2 : right ? Brand.green.opacity(0.18) : i == picked ? Color.red.opacity(0.12) : Brand.surface2,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    if picked != nil {
                        Text("\(picked == q.answer ? "أحسنت! " : "الجواب: ")\(lib.surah(q.ayah.surah)?.shortName ?? "") · الآية \(Num.int(q.ayah.ayah))")
                            .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                        HStack(spacing: 16) {
                            Text("نتيجتك: \(Num.int(score)) من \(Num.int(total))").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                            Button("سؤال آخر") { extra += 1; picked = nil }.font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                        }
                    }
                }
                .padding(16).frame(maxWidth: .infinity).surface()
            }
        }
    }
}

/// A centred section title with a gold mark on each side.
/// The home's section header (Canva/SaaS style): a soft icon tile, a bold title with a short line
/// under it, and an optional action at the end. Same look and wording as Android's HomeHead.
struct HomeHead<Action: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    let action: Action
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, @ViewBuilder action: () -> Action) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol; self.action = action()
    }
    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(Brand.primaryInk)
                    .frame(width: 38, height: 38)
                    .background(Brand.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.ui(.headline, .bold)).foregroundStyle(Brand.ink).lineLimit(1)
                if let subtitle { Text(subtitle).font(.ui(.footnote)).foregroundStyle(Brand.muted).lineLimit(1) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            action
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension HomeHead where Action == EmptyView {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil) {
        self.init(title, subtitle: subtitle, symbol: symbol) { EmptyView() }
    }
}

/// A small «الكل» pill for a header's end.
struct HeadPill<Destination: View>: View {
    let label: String
    @ViewBuilder let destination: () -> Destination
    var body: some View {
        NavigationLink(destination: destination) {
            Text(label).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                .padding(.horizontal, 14).frame(minHeight: 36)
                .background(Brand.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Brand.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Every home section header goes through here, so all carry the same tile and a short line.
struct CenteredHead: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { HomeHead(title, subtitle: Self.subtitle(title), symbol: Self.symbol(title)) }

    static func symbol(_ t: String) -> String? {
        if t.hasPrefix("تابع") { return "clock.arrow.circlepath" }
        if t.hasPrefix("الورد") { return "book" }
        if t.hasPrefix("رحلتي") { return "point.topleft.down.to.point.bottomright.curvepath" }
        if t.hasPrefix("أذكار") { return "sun.haze" }
        if t.hasPrefix("مسابقة") { return "questionmark.bubble" }
        if t.hasPrefix("اختصاراتك") || t.hasPrefix("أدواتي") { return "square.grid.2x2" }
        if t.hasPrefix("المناسبات") { return "calendar" }
        if t.hasPrefix("صلواتي") { return "checkmark.circle" }
        if t.hasPrefix("الوصول") { return "bolt" }
        if t.hasPrefix("الذكر") { return "hand.tap" }
        if t.hasPrefix("صناعة") { return "sparkles" }
        if t.hasPrefix("كل الأدوات") || t.hasPrefix("أقسام") { return "square.grid.3x3" }
        if t.hasPrefix("اسم الله") { return "sparkles" }
        if t.hasPrefix("دعاء") { return "book" }
        return nil
    }
    static func subtitle(_ t: String) -> String? {
        if t.hasPrefix("تابع") { return "ارجع لآخر ما قرأت وسمعت" }
        if t.hasPrefix("صلواتي") { return "سجل صلواتك الخمس بلمسة" }
        if t.hasPrefix("المناسبات") { return "المواسم والأيام الفاضلة القادمة" }
        if t.hasPrefix("اختصاراتك") { return "أدواتك المفضلة في مكان واحد" }
        if t.hasPrefix("أذكار") { return "تقدمك في أذكار اليوم" }
        return nil
    }
}

// MARK: - Customize sheet

struct HomeCustomizeSheet: View {
    @AppStorage(HomeLayoutStore.key) private var raw = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let layout = HomeLayoutStore.decode(raw)
        NavigationStack {
            List {
                Section("الأقسام") {
                    ForEach(layout, id: \.id) { item in
                        Toggle(item.id.title, isOn: Binding(get: { item.shown }, set: { v in
                            var l = layout; if let i = l.firstIndex(where: { $0.id == item.id }) { l[i].shown = v }
                            raw = HomeLayoutStore.encode(l)
                        }))
                        .tint(Brand.green)
                    }
                    .onMove { from, to in var l = layout; l.move(fromOffsets: from, toOffset: to); raw = HomeLayoutStore.encode(l) }
                }
                Section {
                    Button("إعادة الترتيب الافتراضي", role: .destructive) { raw = "" }
                } footer: { Text("اسحب الأقسام لترتيبها") }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("تخصيص الرئيسية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
        }
    }
}

// MARK: - Unified search

/// «البحث الشامل»: tools, surahs, the Quran text, azkar and duas from one field, all on the device.
struct UnifiedSearchView: View {
    @State private var q = ""
    @State private var ayat: [Ayah] = []
    private static let azkarAll: [Zikr] = (try? ContentLibrary.shared.store?.allAzkar()) ?? []
    private static let duaItems: [(text: String, chapter: String, need: String)] =
        (ContentLibrary.shared.duas?.needs ?? []).flatMap { n in n.chapters.flatMap { c in c.items.map { ($0.text, c.name, n.need) } } }
    @FocusState private var focused: Bool
    private let lib = ContentLibrary.shared

    private func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "ar"))
            .replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(of: "إ", with: "ا").replacingOccurrences(of: "آ", with: "ا")
    }

    var body: some View {
        let k = norm(q.trimmingCharacters(in: .whitespaces))
        let tools = k.count < 2 ? [] : SiteTool.all.filter { norm($0.title).contains(k) || norm($0.subtitle).contains(k) }
        let surahs = k.isEmpty ? [] : lib.surahs.filter { norm($0.namePlain).contains(k) || "\($0.id)" == k }
        let cats = k.count < 2 ? [] : lib.azkarCategories.filter { norm($0.title).contains(k) }
        let zikrs = k.count < 3 ? [] : Array(Self.azkarAll.filter { norm($0.text).contains(k) }.prefix(30))
        let duas = k.count < 3 ? [] : Array(Self.duaItems.filter { norm($0.text).contains(k) || norm($0.chapter).contains(k) }.prefix(30))
        List {
            if k.isEmpty {
                Section("اقتراحات") {
                    FlowLayout(spacing: 8) {
                        ForEach(["الكهف", "أذكار الصباح", "القبلة", "الصبر", "الرحمة", "الملك"], id: \.self) { s in
                            Button(s) { q = s }.buttonStyle(.bordered).tint(Brand.primary)
                        }
                    }
                }
            } else if tools.isEmpty && surahs.isEmpty && ayat.isEmpty && cats.isEmpty && zikrs.isEmpty && duas.isEmpty && k.count >= 2 {
                ContentUnavailableView("لا نتائج", systemImage: "magnifyingglass", description: Text("جرب كلمة أخرى أو جزءا من الكلمة"))
            }
            if !tools.isEmpty {
                Section("الأدوات") {
                    ForEach(tools, id: \.id) { t in
                        NavigationLink { t.destination.onAppear { ToolUsage.record(t.id) } } label: {
                            Label { VStack(alignment: .leading) { Text(t.title); Text(t.subtitle).font(.ui(.caption)).foregroundStyle(Brand.muted) } } icon: { Image(systemName: t.symbol).foregroundStyle(Brand.primary) }
                        }
                    }
                }
            }
            if !surahs.isEmpty {
                Section("السور") {
                    ForEach(surahs.prefix(20)) { s in
                        NavigationLink { MushafReader(startPage: s.pageStart ?? 1, focus: RecitationPlayer.Position(surah: s.id, ayah: 1)) } label: {
                            Label("\(s.namePlain) · \(Num.int(s.ayahCount)) آية", systemImage: "book")
                        }
                    }
                }
            }
            if !cats.isEmpty || !zikrs.isEmpty {
                Section("الأذكار") {
                    ForEach(cats) { c in
                        NavigationLink { Route.azkar(c.title).destination } label: { Label(c.title, systemImage: "sun.haze") }
                    }
                    ForEach(zikrs) { z in
                        let cat = lib.azkarCategories.first { $0.id == z.category }?.title ?? ""
                        NavigationLink { Route.azkar(cat).destination } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(z.text).font(.ui(.body)).lineLimit(2)
                                Text([cat, z.reference ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(1)
                            }
                        }
                    }
                }
            }
            if !duas.isEmpty {
                Section("الأدعية") {
                    ForEach(Array(duas.enumerated()), id: \.offset) { _, d in
                        NavigationLink { DuasView() } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(d.text).font(.ui(.body)).lineLimit(2)
                                Text("\(d.need) · \(d.chapter)").font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(1)
                            }
                        }
                    }
                }
            }
            if !ayat.isEmpty {
                Section("الآيات") {
                    ForEach(ayat) { a in
                        NavigationLink { MushafReader(startPage: a.page ?? 1, focus: RecitationPlayer.Position(surah: a.surah, ayah: a.ayah)) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(a.textUthmani).font(.custom(ContentLibrary.mushafFont, size: 18, relativeTo: .body)).lineLimit(3)
                                Text("\(lib.surah(a.surah)?.namePlain ?? "") · الآية \(Num.int(a.ayah))").font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن آية أو ذكر أو دعاء أو أداة")
        .task(id: k) {
            ayat = []
            guard k.count >= 2 else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            ayat = (try? lib.store?.search(q, limit: 60)) ?? []
        }
        .navigationTitle("البحث الشامل")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Today's prayers tracker

/// «صلواتي اليوم»: tick each prayer once prayed, with a 7-day strip. On the device only.
struct HomePrayerTracker: View {
    @AppStorage("prayer.tracker") private var raw = ""   // "yyyy-MM-dd:fajr,dhuhr;…"

    private static func dayKey(_ d: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
    private func map() -> [String: Set<String>] {
        var m: [String: Set<String>] = [:]
        for e in raw.split(separator: ";") {
            let p = e.split(separator: ":", maxSplits: 1)
            guard let k = p.first else { continue }
            m[String(k)] = Set((p.count > 1 ? p[1] : "").split(separator: ",").map(String.init))
        }
        return m
    }
    private func save(_ m: [String: Set<String>]) {
        let keep = m.keys.sorted().suffix(30)
        raw = keep.map { "\($0):\(m[$0]!.sorted().joined(separator: ","))" }.joined(separator: ";")
    }

    var body: some View {
        let today = Self.dayKey(Date())
        let m = map()
        let done = m[today] ?? []
        VStack(spacing: Brand.Space.m) {
            CenteredHead("صلواتي اليوم")
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(Prayer.allCases.filter(\.isPrayer)) { p in
                        let key = "\(p.rawValue)"
                        let on = done.contains(key)
                        Button {
                            var mm = m; var d = done
                            if on { d.remove(key) } else { d.insert(key) }
                            mm[today] = d; save(mm)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark").font(.ui(.footnote, .bold))
                                Text(p.name).font(.ui(.caption, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(on ? .white : Brand.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(on ? Brand.green : Brand.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Brand.green : Brand.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(p.name) \(on ? "صليت" : "لم تسجل")")
                        .animation(.easeOut(duration: 0.2), value: on)
                    }
                }
                HStack {
                    Text("\(Num.int(done.count)) من \(Num.int(5)) اليوم").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                    Spacer()
                    ForEach((0..<7).reversed(), id: \.self) { i in
                        let n = (m[Self.dayKey(Date().addingTimeInterval(-86400 * Double(i)))] ?? []).count
                        Circle().fill(n >= 5 ? Brand.green : n > 0 ? Brand.green.opacity(0.35) : Brand.tint).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14).surface()
        }
    }
}

// MARK: - Muslim services

struct HomeServices: View {
    private let items: [(String, String, String)] = [
        ("المصحف", "book", "search"), ("أسماء الله", "sparkles", "asma-ul-husna"),
        ("المساجد", "mappin.and.ellipse", "nearby-mosques"), ("الإذاعات", "radio", "radio"),
        ("الأدعية", "hands.sparkles", "duas"), ("الرقية", "shield.lefthalf.filled", "ruqya"),
        ("الزكاة", "percent", "zakat"), ("الأطفال", "star.circle", "kids-juz-amma"),
    ]
    var body: some View {
        VStack(spacing: Brand.Space.m) {
            CenteredHead("الوصول السريع")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 14) {
                ForEach(items, id: \.2) { t in
                    if let tool = SiteTool.all.first(where: { $0.id == t.2 }) {
                        NavigationLink { tool.destination.onAppear { ToolUsage.record(tool.id) } } label: {
                            VStack(spacing: 6) {
                                Image(systemName: t.1).font(.ui(.title3, .semibold)).foregroundStyle(.white)
                                    .frame(width: 46, height: 46)
                                    .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text(t.0).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 8).surface()
        }
    }
}

// MARK: - Quick dhikr

/// A small tasbih on the home page; shares the count with «المسبحة».
struct HomeQuickDhikr: View {
    @AppStorage("tasbih.count") private var count = 0
    @AppStorage("tasbih.phrase") private var phrase = ""
    private let phrases = ["سبحان الله", "الحمد لله", "لا إله إلا الله", "الله أكبر"]

    var body: some View {
        let current = phrase.isEmpty ? phrases[0] : phrase
        VStack(spacing: Brand.Space.m) {
            CenteredHead("الذكر السريع")
            HStack(spacing: 14) {
                Button {
                    count += 1
                    UIImpactFeedbackGenerator(style: count % 33 == 0 ? .heavy : .light).impactOccurred()
                } label: {
                    Text(Num.int(count)).font(.ui(.title, .bold)).foregroundStyle(.white).monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(width: 96, height: 96)
                        .background(LinearGradient(colors: [Color(hex: 0x2E9145), Color(hex: 0x102D27)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("سبّح: \(current)، العدد \(count)")
                VStack(alignment: .leading, spacing: 8) {
                    Text(current).font(.ui(.title3, .semibold)).foregroundStyle(Brand.ink).lineLimit(1)
                    ProgressView(value: Double(count % 33), total: 33).tint(Brand.accent)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(phrases, id: \.self) { p in
                                Button(p) { phrase = p; count = 0 }
                                    .font(.ui(.caption, .semibold)).padding(.horizontal, 10).frame(minHeight: 32)
                                    .foregroundStyle(p == current ? .white : Brand.primaryInk)
                                    .background(p == current ? Brand.primary : Brand.tint, in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(14).surface()
        }
    }
}

/// «اسم الله اليوم»: one of the names listed in «الأسماء الحسنى», a new one each day, with a card to
/// share it. Only the name is shown (the list carries no explanations, and none is written here).
struct HomeNameOfTheDay: View {
    var body: some View {
        let names = ContentLibrary.shared.asma
        if !names.isEmpty {
            let day = Int(Date().timeIntervalSince1970 / 86400)
            let name = names[day % names.count].name
            VStack(alignment: .leading, spacing: Brand.Space.m) {
                HomeHead("اسم الله اليوم", symbol: "sparkles") { HeadPill(label: "كل الأسماء") { AsmaView() } }
                VStack(spacing: 10) {
                    Text("من أسماء الله الحسنى").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.goldInk)
                    Text(name).font(.custom(ContentLibrary.mushafFont, size: 34, relativeTo: .largeTitle)).foregroundStyle(Brand.ink)
                    NavigationLink {
                        TextCardView(title: "بطاقة اسم", text: name, reference: "من أسماء الله الحسنى", initialRatio: .square)
                    } label: {
                        Label("صمم بطاقة بالاسم", systemImage: "sparkles").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                            .padding(.horizontal, 18).frame(minHeight: 44)
                            .background(Brand.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Brand.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18).frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Brand.goldSoft, Brand.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Brand.accent.opacity(0.35), lineWidth: 1))
            }
        }
    }
}

/// «دعاء من القرآن»: one of the Quran duas listed in «الأدعية», a new one each day, shown with the
/// mushaf text and its surah and ayah, to listen to or turn into a card. Same as Android.
struct HomeQuranDua: View {
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var player = RecitationPlayer()
    private let lib = ContentLibrary.shared

    var body: some View {
        let refs = lib.duas?.quran ?? []
        if !refs.isEmpty {
            let r = refs[Int(Date().timeIntervalSince1970 / 86400) % refs.count]
            let text = ((try? lib.store?.ayat(surah: r.s, from: r.a, to: r.b)) ?? []).map(\.textUthmani).joined(separator: " ")
            let name = lib.surah(r.s)?.namePlain ?? ""
            VStack(alignment: .leading, spacing: Brand.Space.m) {
                HomeHead("دعاء من القرآن", subtitle: "دعاء جديد كل يوم بنص المصحف", symbol: "book") {
                    HeadPill(label: "كل الأدعية") { DuasView() }
                }
                VStack(spacing: 12) {
                    Text(text).font(.custom(ContentLibrary.mushafFont, size: 21, relativeTo: .title3)).lineSpacing(10)
                        .multilineTextAlignment(.center).foregroundStyle(Brand.ink)
                    Text("سورة \(name) · " + (r.a == r.b ? "الآية \(Num.int(r.a))" : "الآيات \(Num.int(r.a))-\(Num.int(r.b))"))
                        .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.goldInk)
                    HStack(spacing: 10) {
                        Button("استمع") { play(r) }.buttonStyle(.brandSecondary).frame(maxWidth: .infinity)
                        NavigationLink { AyahCardView(surah: r.s, from: r.a, to: r.b) } label: {
                            Text("صمم بطاقة").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.brandPrimary).frame(maxWidth: .infinity)
                    }
                }
                .padding(18).frame(maxWidth: .infinity)
                .surface(.raised, radius: 20)
            }
        }
    }

    private func play(_ r: DuasData.QuranRef) {
        player.folder = lib.reciterFolders[reciter]
        player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
        player.repeatEach = 1
        player.stopAt = RecitationPlayer.Position(surah: r.s, ayah: r.b)
        player.play(from: RecitationPlayer.Position(surah: r.s, ayah: r.a))
    }
}
