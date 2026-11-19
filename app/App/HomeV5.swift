import SwiftUI
import AyatDesign
import AyatCalc
import AyatContent

// MARK: - Layout («تخصيص الرئيسية»)

/// Home sections the user can order and hide. New sections from updates join at the end, shown.
enum HomeSectionID: String, CaseIterable, Identifiable {
    case prayer, head, wird, quiz, create, today, tools, ayah, gallery, presets, recent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prayer: "الصلاة القادمة"
        case .head: "الترحيب والبحث"
        case .wird: "الورد والختمة"
        case .quiz: "مسابقة اليوم"
        case .create: "صناعة المحتوى"
        case .today: "الأدوات اليومية"
        case .tools: "كل الأدوات"
        case .ayah: "آية اليوم"
        case .gallery: "معرض الخلفيات"
        case .presets: "القوالب الجاهزة"
        case .recent: "مشاريعي الأخيرة"
        }
    }
}

struct HomeLayoutItem: Equatable { var id: HomeSectionID; var shown: Bool }

enum HomeLayoutStore {
    static let key = "home.layout.v5"
    static func decode(_ raw: String) -> [HomeLayoutItem] {
        var out: [HomeLayoutItem] = raw.split(separator: ",").compactMap { e in
            let p = e.split(separator: ":")
            guard let n = p.first, let s = HomeSectionID(rawValue: String(n)) else { return nil }
            return HomeLayoutItem(id: s, shown: p.count < 2 || p[1] != "0")
        }
        for s in HomeSectionID.allCases where !out.contains(where: { $0.id == s }) { out.append(.init(id: s, shown: true)) }
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
                HStack(spacing: 16) {
                    let frac = plan.map { Double($0.completedDays.count) / Double(max(1, $0.days)) } ?? 0
                    ZStack {
                        Circle().stroke(Brand.tint, lineWidth: 7)
                        Circle().trim(from: 0, to: frac).stroke(Brand.green, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text(plan == nil ? "—" : "\(Num.int(Int(frac * 100)))٪").font(.ui(.subheadline, .bold)).foregroundStyle(Brand.primaryInk)
                    }
                    .frame(width: 74, height: 74)
                    VStack(alignment: .leading, spacing: 4) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward").foregroundStyle(Brand.muted)
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

/// Small deterministic generator so the day's question is the same all day.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A centred section title with a gold mark on each side.
struct CenteredHead: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1).fill(Brand.accent).frame(width: 6, height: 6)
            Text(title).font(.ui(.title3, .bold)).foregroundStyle(Brand.ink)
            RoundedRectangle(cornerRadius: 1).fill(Brand.accent).frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
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

/// «البحث الشامل»: tools, surahs and the Quran text from one field, all on the device.
struct UnifiedSearchView: View {
    @State private var q = ""
    @State private var ayat: [Ayah] = []
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
        List {
            if k.isEmpty {
                Section("اقتراحات") {
                    FlowLayout(spacing: 8) {
                        ForEach(["الكهف", "الأذكار", "القبلة", "الصبر", "الرحمة", "الملك"], id: \.self) { s in
                            Button(s) { q = s }.buttonStyle(.bordered).tint(Brand.primary)
                        }
                    }
                }
            } else if tools.isEmpty && surahs.isEmpty && ayat.isEmpty && k.count >= 2 {
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
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن أداة أو سورة أو آية")
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
