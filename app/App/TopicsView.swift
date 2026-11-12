import SwiftUI
import AyatDesign
import AyatContent

/// Ayat by topic (ayattla.com/ayat/): the site's topics in its order, each with the ayat it lists.
/// Only the references come from the site (content pack meta "topics", checked against the pack
/// when it is built); the ayah text is the pack's and the tafsir is Al-Muyassar from Quran.com.
struct TopicData: Codable, Hashable, Identifiable {
    let slug: String
    let title: String
    let desc: String
    let items: [DuasData.QuranRef]
    var id: String { slug }
}

extension ContentLibrary {
    var topics: [TopicData] { json("topics") ?? [] }
}

struct TopicsView: View {
    private let topics = ContentLibrary.shared.topics
    @State private var query = ""

    var body: some View {
        Group {
            if topics.isEmpty {
                EmptyState("آيات بالموضوع غير متاحة", symbol: "leaf", message: "لم تجهز حزمة المحتوى في هذه النسخة")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ToolPageHead(id: "topics")
                        Text("آيات مختارة حسب الموضوع بالرسم العثماني مع التفسير الميسر، وتحويل أي آية إلى مقطع أو بطاقة.")
                            .font(.ui(.footnote)).foregroundStyle(Brand.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                            ForEach(filtered) { t in
                                NavigationLink { TopicView(topic: t) } label: {
                                    ToolCard(t.title, subtitle: "\(Num.int(t.items.count)) مواضع مع التفسير الميسر", symbol: "leaf")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if filtered.isEmpty { EmptyState("لا نتائج", symbol: "magnifyingglass") }
                    }
                    .padding(16)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .brandScreen()
        .navigationTitle("آيات بالموضوع")
        .searchable(text: $query, prompt: "ابحث عن موضوع")
    }

    private var filtered: [TopicData] {
        let q = ContentStore.clean(query.trimmingCharacters(in: .whitespaces))
        return q.isEmpty ? topics : topics.filter { ContentStore.clean($0.title + " " + $0.desc).localizedStandardContains(q) }
    }
}

struct TopicView: View {
    let topic: TopicData
    private let lib = ContentLibrary.shared
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @AppStorage(Favorites.key) private var favorites = ""
    /// Same language as «معاني الكلمات», so both share the cached chapter (the tafsir is the same).
    @AppStorage("wbw.lang") private var lang = "en"
    @State private var player = RecitationPlayer()
    /// Al-Muyassar per ayah key ("2:255"), loaded per surah when a tafsir is first opened.
    @State private var tafsir: [String: String] = [:]
    @State private var loading: Set<Int> = []
    @State private var failed: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(topic.desc).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(topic.items, id: \.self) { q in card(q) }
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ q: DuasData.QuranRef) -> some View {
        let ayat = (try? lib.store?.ayat(surah: q.s, from: q.a, to: q.b)) ?? []
        let name = lib.surah(q.s)?.shortName ?? ""
        let ref = q.a == q.b ? "سورة \(name) · الآية \(Num.int(q.a))" : "سورة \(name) · الآيات \(Num.int(q.a))–\(Num.int(q.b))"
        let first = RecitationPlayer.Position(surah: q.s, ayah: q.a)
        let isFav = Favorites.list(favorites).contains(first)
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.custom(ContentLibrary.mushafFont, size: 22, relativeTo: .title3))
                .lineSpacing(10)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
            Text(ref).font(.ui(.caption, .medium)).foregroundStyle(Brand.goldInk)
            FlowLayout(spacing: 8) {
                NavigationLink { ClipMakerView(surah: q.s, from: q.a, to: q.b) } label: { Text("مقطع فيديو") }
                    .buttonStyle(.brandPrimary)
                NavigationLink { AyahCardView(surah: q.s, from: q.a, to: q.b) } label: { Text("بطاقة صورة") }
                    .buttonStyle(.brandSecondary)
                if folder != nil {
                    Button {
                        if player.isPlaying && player.current.map({ $0.surah == q.s && (q.a...q.b).contains($0.ayah) }) == true {
                            player.stop()
                        } else {
                            player.folder = folder
                            player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
                            player.stopAt = .init(surah: q.s, ayah: q.b)
                            player.play(from: first)
                        }
                    } label: {
                        Label(isPlayingHere(q) ? "إيقاف" : "استماع", systemImage: isPlayingHere(q) ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.brandSecondary)
                }
                NavigationLink { MushafReader(startPage: ayat.first?.page ?? 1, focus: first) } label: { Text("في المصحف") }
                    .buttonStyle(.brandSecondary)
                Button { favorites = Favorites.toggled(favorites, first) } label: {
                    Label(isFav ? "محفوظة" : "حفظ", systemImage: isFav ? "heart.fill" : "heart")
                }
                .buttonStyle(.brandSecondary)
                .accessibilityLabel(isFav ? "أزل من المحفوظة" : "احفظ الآية")
                ShareLink(item: "﴿\(text)﴾ [\(ref)]") { Label("مشاركة", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.brandSecondary)
            }
            DisclosureGroup {
                tafsirText(q)
            } label: {
                Text("التفسير الميسر").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                    .frame(minHeight: Brand.minTap, alignment: .leading)
            }
            .tint(Brand.primaryInk)
        }
        .padding(16)
        .card()
    }

    @ViewBuilder private func tafsirText(_ q: DuasData.QuranRef) -> some View {
        let lines = (q.a...q.b).compactMap { n in tafsir["\(q.s):\(n)"].map { (n, $0) } }
        VStack(alignment: .leading, spacing: 8) {
            if !lines.isEmpty {
                ForEach(lines.indices, id: \.self) { i in
                    (Text("\(Num.int(lines[i].0)): ").bold() + Text(lines[i].1))
                        .font(.ui(.footnote)).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("التفسير الميسر عبر Quran.com").font(.ui(.caption2)).foregroundStyle(Brand.muted)
            } else if failed.contains(q.s) {
                HStack {
                    Text("تعذر تحميل التفسير، تحقق من الاتصال").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                    Button("حاول مرة أخرى") { failed.remove(q.s); Task { await load(q.s) } }.font(.ui(.footnote, .medium))
                }
            } else {
                ProgressView().tint(Brand.primaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
        .task { await load(q.s) }
    }

    private func load(_ surah: Int) async {
        guard !loading.contains(surah), tafsir["\(surah):1"] == nil, !failed.contains(surah) else { return }
        loading.insert(surah)
        defer { loading.remove(surah) }
        do {
            let verses = try await QF.words(chapter: surah, lang: lang).verses
            for v in verses { if let t = v.tafsir, !t.isEmpty { tafsir[v.key] = t } }
        } catch {
            failed.insert(surah)
        }
    }

    private func isPlayingHere(_ q: DuasData.QuranRef) -> Bool {
        player.isPlaying && player.current.map { $0.surah == q.s && (q.a...q.b).contains($0.ayah) } == true
    }

    private var folder: String? { lib.reciterFolders[reciter] }
}
