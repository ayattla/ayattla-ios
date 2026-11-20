import SwiftUI
import AyatDesign
import AyatCalc
import AyatContent

// MARK: - Data («حالات واتساب» by occasion, as ayattla.com/status/<slug>)

struct StatusOccasion: Codable, Hashable, Identifiable {
    struct Item: Codable, Hashable {
        let type: String
        let tag: String
        let text: String
        let ref: String
        let src: String
        var url: String? = nil
        var sharh: String? = nil
        var full: String? = nil
        var s: Int? = nil
        var a: Int? = nil
        var b: Int? = nil
    }
    let slug: String
    let title: String
    let intro: String
    let color: String
    let items: [Item]
    var id: String { slug }
}

extension ContentLibrary {
    var statusOccasions: [StatusOccasion] { json("status") ?? [] }

    /// Ayah text from the pack with end-of-ayah marks (the page's text is only a fallback).
    func statusText(_ item: StatusOccasion.Item) -> String {
        guard let s = item.s, let a = item.a else { return item.text }
        let ayat = (try? store?.ayat(surah: s, from: a, to: item.b ?? a)) ?? []
        let t = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        return t.isEmpty ? item.text : t
    }
}

/// How each occasion looks: group, symbol and the design its status card starts with.
enum StatusLook {
    struct Look { let group: String; let symbol: String; let background: String; let ornament: CardOrnament }
    static let groups = ["المناسبات", "التهنئة والدعاء", "اليومية", "محتوى جاهز", "المزيد"]
    static let map: [String: Look] = [
        "jumuah": .init(group: "المناسبات", symbol: "building.columns", background: "emerald", ornament: .arch),
        "ramadan": .init(group: "المناسبات", symbol: "moon.stars", background: "violet", ornament: .lantern),
        "laylat-al-qadr": .init(group: "المناسبات", symbol: "sparkles", background: "royal", ornament: .lantern),
        "eid-al-fitr": .init(group: "المناسبات", symbol: "party.popper", background: "teal", ornament: .bands),
        "eid-al-adha": .init(group: "المناسبات", symbol: "party.popper", background: "burgundy", ornament: .bands),
        "arafah": .init(group: "المناسبات", symbol: "mountain.2", background: "sand", ornament: .arch),
        "dhul-hijjah": .init(group: "المناسبات", symbol: "mountain.2", background: "sand", ornament: .medallion),
        "hajj": .init(group: "المناسبات", symbol: "building.columns", background: "ivory", ornament: .arch),
        "ashura": .init(group: "المناسبات", symbol: "leaf", background: "night", ornament: .classic),
        "marriage": .init(group: "التهنئة والدعاء", symbol: "heart", background: "blush", ornament: .corners),
        "newborn": .init(group: "التهنئة والدعاء", symbol: "figure.and.child.holdinghands", background: "sky", ornament: .corners),
        "success": .init(group: "التهنئة والدعاء", symbol: "trophy", background: "royal", ornament: .medallion),
        "healing": .init(group: "التهنئة والدعاء", symbol: "cross.case", background: "teal", ornament: .classic),
        "condolence": .init(group: "التهنئة والدعاء", symbol: "hands.sparkles", background: "ink", ornament: .classic),
        "sadaqah-jariyah": .init(group: "التهنئة والدعاء", symbol: "drop", background: "olive", ornament: .medallion),
        "morning": .init(group: "اليومية", symbol: "sun.max", background: "sand", ornament: .classic),
        "evening": .init(group: "اليومية", symbol: "sunset", background: "night", ornament: .medallion),
        "sleep": .init(group: "اليومية", symbol: "bed.double", background: "royal", ornament: .classic),
        "after-prayer": .init(group: "اليومية", symbol: "figure.mind.and.body", background: "emerald", ornament: .classic),
        "istighfar": .init(group: "اليومية", symbol: "leaf", background: "olive", ornament: .corners),
        "relief": .init(group: "اليومية", symbol: "heart.circle", background: "teal", ornament: .medallion),
        "travel": .init(group: "اليومية", symbol: "airplane", background: "sky", ornament: .classic),
        "rain": .init(group: "اليومية", symbol: "cloud.rain", background: "sky", ornament: .medallion),
        "hadith": .init(group: "محتوى جاهز", symbol: "text.book.closed", background: "emerald", ornament: .classic),
    ]
    static func look(_ slug: String) -> Look { map[slug] ?? .init(group: "المزيد", symbol: "cloud", background: "emerald", ornament: .classic) }
    static func background(_ slug: String) -> CardOptions.Background {
        CardOptions.backgrounds.first { $0.id == look(slug).background } ?? CardOptions.backgrounds[0]
    }

    /// The occasion that fits today (Friday, Ramadan, the ten days, Arafah, the Eids, Ashura).
    static func today(_ date: Date = Date()) -> String? {
        let h = Hijri.fromGregorian(date)
        switch (h.month, h.day) {
        case (10, 1...3): return "eid-al-fitr"
        case (12, 9): return "arafah"
        case (12, 10...13): return "eid-al-adha"
        case (12, 1...8): return "dhul-hijjah"
        case (9, 21...30): return "laylat-al-qadr"
        case (9, _): return "ramadan"
        case (1, 9...10): return "ashura"
        default: break
        }
        let wd = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return wd == 6 || wd == 5 ? "jumuah" : nil
    }
}

/// Opens the right card maker on a status text, sized for a status, with the occasion's design.
struct StatusCardDestination: View {
    let occasion: StatusOccasion
    let item: StatusOccasion.Item

    var body: some View {
        let look = StatusLook.look(occasion.slug)
        if let s = item.s, let a = item.a {
            AyahCardView(settings: .init(surah: s, from: a, to: item.b ?? a, ratio: "9:16", background: look.background,
                                         fontScale: 1, template: "", name: "", ornament: look.ornament.rawValue))
        } else {
            TextCardView(title: "حالة \(occasion.title)", text: item.text, reference: item.ref.isEmpty ? item.src : item.ref,
                         initialRatio: .story, backgroundID: look.background, ornament: look.ornament, header: occasion.title)
        }
    }
}

// MARK: - Index

/// «حالات واتساب»: today's status, the occasions by group, and starting from scratch.
struct StatusSourceView: View {
    private let lib = ContentLibrary.shared
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let all = lib.statusOccasions
        let todaySlug = StatusLook.today()
        ScrollView {
            VStack(spacing: Brand.Space.xl) {
                VStack(spacing: 6) {
                    Text("صمم حالتك بنص موثق").font(.ui(.title2, .bold)).foregroundStyle(Brand.ink)
                    Text("آيات وأحاديث صحيحة وأذكار لكل مناسبة، بمصادرها، بمقاس الحالة ٩:١٦")
                        .font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                if let occ = all.first(where: { $0.slug == todaySlug }), let item = occ.items.first {
                    todayCard(occ, item)
                }
                if all.isEmpty {
                    EmptyState("حالات المناسبات غير متاحة", symbol: "text.bubble", message: "لم تجهز حزمة المحتوى في هذه النسخة")
                }
                ForEach(StatusLook.groups, id: \.self) { g in
                    let list = all.filter { StatusLook.look($0.slug).group == g }
                    if !list.isEmpty {
                        VStack(spacing: Brand.Space.m) {
                            CenteredHead(g)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                                ForEach(list) { o in
                                    NavigationLink { StatusOccasionView(occasion: o) } label: { tile(o) }
                                        .buttonStyle(.pressable)
                                }
                            }
                        }
                    }
                }
                VStack(spacing: Brand.Space.m) {
                    CenteredHead("صمم من البداية")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        NavigationLink {
                            AyahCardView(settings: .init(surah: 2, from: 255, to: 255, ratio: "9:16", background: "emerald",
                                                         fontScale: 1, template: "", name: "", ornament: CardOrnament.classic.rawValue))
                        } label: { start("آية", "book") }
                        NavigationLink { ClipMakerView() } label: { start("مقطع متحرك", "play.rectangle") }
                        NavigationLink { AzkarView() } label: { start("ذكر", "sun.max") }
                        NavigationLink { HadithView() } label: { start("حديث", "text.book.closed") }
                    }
                    .buttonStyle(.pressable)
                }
                PresetStrip(title: "حالات جاهزة", subtitle: "اضغط على حالة لتعدلها وتشاركها", presets: StudioPreset.statuses)
                Text("لا ننشر دعاء أو عبارة دينية بلا مصدر. النصوص كما في الموقع.")
                    .font(.ui(.caption)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("حالات واتساب")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func todayCard(_ occ: StatusOccasion, _ item: StatusOccasion.Item) -> some View {
        let bg = StatusLook.background(occ.slug)
        let ink: Color = bg.light ? Color(hex: 0x2B2418) : .white
        return VStack(spacing: 10) {
            Text("حالة اليوم · \(occ.title)").font(.ui(.footnote, .semibold)).foregroundStyle(bg.accentColor)
            Text(lib.statusText(item))
                .font(.custom(item.s != nil ? ContentLibrary.mushafFont : "Amiri", size: 20, relativeTo: .title3))
                .lineSpacing(8).lineLimit(5).foregroundStyle(ink)
            Text(item.ref).font(.ui(.caption, .medium)).foregroundStyle(bg.accentColor).lineLimit(2)
            HStack(spacing: 8) {
                NavigationLink { StatusCardDestination(occasion: occ, item: item) } label: {
                    Label("صممها حالة", systemImage: "paintpalette").font(.ui(.subheadline, .semibold))
                        .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                        .foregroundStyle(Color(hex: bg.top)).background(bg.accentColor, in: Capsule())
                }
                NavigationLink { StatusOccasionView(occasion: occ) } label: {
                    Text("كل نصوص \(occ.title)").font(.ui(.subheadline, .semibold))
                        .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                        .foregroundStyle(ink).background(ink.opacity(0.14), in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(bg.gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { OrnamentLayer(kind: StatusLook.look(occ.slug).ornament, accent: bg.accentColor).clipShape(RoundedRectangle(cornerRadius: 26)).opacity(0.6) }
    }

    private func tile(_ o: StatusOccasion) -> some View {
        let bg = StatusLook.background(o.slug)
        return VStack(spacing: 8) {
            Image(systemName: StatusLook.look(o.slug).symbol).font(.ui(.title3, .semibold)).foregroundStyle(bg.accentColor)
                .frame(width: 48, height: 48).background(bg.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            Text(o.title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).lineLimit(1).minimumScaleFactor(0.8)
            Text("\(Num.int(o.items.count)) نصا جاهزا").font(.ui(.caption2)).foregroundStyle(Brand.primaryInk)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 120)
        .surface()
        .accessibilityElement(children: .combine)
    }

    private func start(_ t: String, _ symbol: String) -> some View {
        VStack(spacing: 8) {
            IconTile(symbol, style: .gradient(1), size: 42)
            Text(t).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .surface()
    }
}

// MARK: - One occasion

struct StatusOccasionView: View {
    let occasion: StatusOccasion
    @State private var filter = "الكل"
    @State private var openSharh: Set<Int> = []
    private let lib = ContentLibrary.shared

    var body: some View {
        let bg = StatusLook.background(occasion.slug)
        let kinds = ["الكل"] + occasion.items.map(\.tag).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        ScrollView {
            VStack(spacing: Brand.Space.m) {
                if !occasion.intro.isEmpty {
                    Text(occasion.intro).font(.ui(.subheadline)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
                }
                if kinds.count > 2 {
                    FlowLayout(spacing: 8) {
                        ForEach(kinds, id: \.self) { k in
                            Button(k) { filter = k }
                                .font(.ui(.footnote, .semibold)).padding(.horizontal, 12).frame(minHeight: 36)
                                .foregroundStyle(filter == k ? .white : Brand.primaryInk)
                                .background(filter == k ? Brand.primary : Brand.tint, in: Capsule())
                        }
                    }
                }
                ForEach(Array(occasion.items.enumerated()).filter { filter == "الكل" || $0.element.tag == filter }, id: \.offset) { i, item in
                    let text = lib.statusText(item)
                    VStack(spacing: 10) {
                        Capsule().fill(bg.accentColor.opacity(0.7)).frame(height: 4)
                        Text(item.tag).font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                            .padding(.horizontal, 12).padding(.vertical, 4).background(Brand.tint, in: Capsule())
                        Text(text).font(.custom(item.s != nil ? ContentLibrary.mushafFont : "Amiri", size: 20, relativeTo: .title3))
                            .lineSpacing(8).foregroundStyle(Brand.ink).textSelection(.enabled)
                        if !item.ref.isEmpty { Text(item.ref).font(.ui(.caption)).foregroundStyle(Brand.muted) }
                        if !item.src.isEmpty { Text(item.src).font(.ui(.caption2)).foregroundStyle(Brand.muted) }
                        if let sh = item.sharh, !sh.isEmpty {
                            Button(openSharh.contains(i) ? "إخفاء الشرح" : "شرح مختصر") {
                                if openSharh.contains(i) { openSharh.remove(i) } else { openSharh.insert(i) }
                            }
                            .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                            if openSharh.contains(i) { Text(sh).font(.ui(.subheadline)).foregroundStyle(Brand.ink) }
                        }
                        HStack(spacing: 8) {
                            NavigationLink { StatusCardDestination(occasion: occasion, item: item) } label: {
                                Label("صممها حالة", systemImage: "paintpalette").font(.ui(.subheadline, .semibold))
                                    .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                                    .foregroundStyle(.white).background(Brand.green, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { UIPasteboard.general.string = [text, item.ref].filter { !$0.isEmpty }.joined(separator: "\n") } label: {
                                Label("نسخ", systemImage: "doc.on.doc").font(.ui(.subheadline, .semibold))
                                    .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                                    .foregroundStyle(Brand.ink).background(Brand.surface2, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            ShareLink(item: [text, item.ref].filter { !$0.isEmpty }.joined(separator: "\n")) {
                                Label("مشاركة", systemImage: "square.and.arrow.up").font(.ui(.subheadline, .semibold))
                                    .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                                    .foregroundStyle(Brand.ink).background(Brand.surface2, in: Capsule())
                            }
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .surface()
                }
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("حالات \(occasion.title)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
