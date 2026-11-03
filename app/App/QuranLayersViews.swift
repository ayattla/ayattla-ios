import SwiftUI
import AyatDesign
import AyatContent

// MARK: - Layer page in the reader

/// One mushaf page shown ayah by ayah with a layer: tajweed colors, word meanings or tafsir.
struct LayerPage: View {
    let number: Int
    let layer: QuranLayer
    let scale: Double
    @AppStorage("wbw.lang") private var lang = "en"
    @State private var tajweed: [String: String] = [:]
    @State private var words: [String: QF.WordsChapter.Verse] = [:]
    @State private var failed = false
    private let lib = ContentLibrary.shared

    var body: some View {
        let ayat = (try? lib.store?.page(number)) ?? []
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if layer == .tajweed { TajweedLegend() }
                ForEach(ayat) { a in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(QuranText.reference(.init(surah: a.surah, ayah: a.ayah)))
                            .font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                        switch layer {
                        case .tajweed:
                            if let html = tajweed[a.id] {
                                Text(Tajweed.attributed(html))
                                    .font(.custom(ContentLibrary.mushafFont, size: 24 * scale, relativeTo: .title2))
                                    .lineSpacing(10).frame(maxWidth: .infinity, alignment: .trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                            } else { placeholder(a) }
                        case .words:
                            if let v = words[a.id] { WordGrid(words: v.words, scale: scale) } else { placeholder(a) }
                        case .tafsir:
                            Text(a.textUthmani + " " + QuranText.marker(a.ayah))
                                .font(.custom(ContentLibrary.mushafFont, size: 22 * scale, relativeTo: .title3)).lineSpacing(8)
                            if let t = words[a.id]?.tafsir {
                                Text(t).font(.ui(.body)).lineSpacing(5).foregroundStyle(.secondary).textSelection(.enabled)
                            } else if !failed { ProgressView() }
                        case .mushaf:
                            EmptyView()
                        }
                    }
                    .padding(16)
                    .card()
                }
                if failed {
                    Text("تعذر التحميل من Quran.com الآن. تحقق من الاتصال.").font(.ui(.footnote)).foregroundStyle(.secondary)
                }
                Text(sourceLine).font(.ui(.caption2)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .task(id: "\(number)-\(layer.rawValue)-\(lang)") { await load(Set(ayat.map(\.surah))) }
    }

    private var sourceLine: String {
        switch layer {
        case .tajweed: "التجويد من Quran.com (Quran Foundation)"
        case .words: "معاني الكلمات من Quran.com (Quran Foundation)"
        case .tafsir: "التفسير الميسر (مجمع الملك فهد)"
        case .mushaf: ""
        }
    }

    @ViewBuilder private func placeholder(_ a: Ayah) -> some View {
        if failed {
            Text(a.textUthmani).font(.custom(ContentLibrary.mushafFont, size: 22 * scale))
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func load(_ surahs: Set<Int>) async {
        failed = false
        do {
            for s in surahs.sorted() {
                if layer == .tajweed {
                    for v in try await QF.tajweed(chapter: s).verses { tajweed[v.key] = v.html }
                } else {
                    for v in try await QF.words(chapter: s, lang: lang).verses { words[v.key] = v }
                }
            }
        } catch {
            failed = true
        }
    }
}

struct WordGrid: View {
    let words: [QF.WordsChapter.Word]
    var scale: Double = 1
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, w in
                VStack(spacing: 4) {
                    Text(w.t).font(.custom(ContentLibrary.mushafFont, size: 22 * scale))
                    Text(w.m).font(.ui(.caption2)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Brand.tint, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct TajweedLegend: View {
    var body: some View {
        DisclosureGroup("مفتاح الألوان") {
            FlowLayout(spacing: 10) {
                ForEach(Tajweed.rules, id: \.0) { r in
                    HStack(spacing: 6) {
                        Text("ب").font(.custom(ContentLibrary.mushafFont, size: 22)).foregroundStyle(Tajweed.color(r.0) ?? .primary)
                        Text(r.1).font(.ui(.caption))
                    }
                }
            }
            .padding(.top, 6)
        }
        .padding(12)
        .card()
    }
}

// MARK: - Tools: tajweed and word by word (/tools/tajweed, /tools/word-by-word)

struct TajweedView: View {
    @State private var surah = 1
    @State private var verses: [QF.TajweedChapter.Verse] = []
    @State private var failed = false
    @State private var size: Double = 26
    private let lib = ContentLibrary.shared

    var body: some View {
        List {
Group {
            Section {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Picker("حجم الخط", selection: $size) {
                    Text("صغير").tag(22.0); Text("متوسط").tag(26.0); Text("كبير").tag(32.0)
                }
                .pickerStyle(.segmented)
                TajweedLegend().listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                if failed {
                    Text("تعذر تحميل السورة من Quran.com، حاول لاحقا.").foregroundStyle(.secondary)
                } else if verses.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                    let all = verses.reduce(into: AttributedString()) { $0 += Tajweed.attributed($1.html) + AttributedString(" ") }
                    Text(all).font(.custom(ContentLibrary.mushafFont, size: size)).lineSpacing(size * 0.6)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                        .textSelection(.enabled)
                }
            } footer: { Text("نص ملون بأحكام التجويد من Quran.com (Quran Foundation).") }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("المصحف الملون بالتجويد")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: surah) {
            verses = []; failed = false
            do { verses = try await QF.tajweed(chapter: surah).verses } catch { failed = true }
        }
    }
}

struct WordByWordView: View {
    @AppStorage("wbw.lang") private var lang = "en"
    @State private var surah = 1
    @State private var verses: [QF.WordsChapter.Verse] = []
    @State private var failed = false
    private let lib = ContentLibrary.shared

    var body: some View {
        List {
Group {
            Section {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Picker("لغة المعنى", selection: $lang) {
                    ForEach(QF.wordLanguages, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            if failed {
                Text("تعذر التحميل من Quran.com الآن.").foregroundStyle(.secondary)
            } else if verses.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            ForEach(verses, id: \.key) { v in
                Section("الآية \(Num.int(v.n))") {
                    WordGrid(words: v.words)
                    if let t = v.tafsir { Text(t).font(.ui(.footnote)).foregroundStyle(.secondary) }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("معاني الكلمات")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(surah)-\(lang)") {
            verses = []; failed = false
            do { verses = try await QF.words(chapter: surah, lang: lang).verses } catch { failed = true }
        }
    }
}

// MARK: - Ruqya and Asma ul-Husna

struct RuqyaData: Codable { let title: String; let items: [DuasData.QuranRef] }
struct AsmaName: Codable, Hashable { let n: Int; let name: String }

extension ContentLibrary {
    var ruqya: RuqyaData? { json("ruqya") }
    var asma: [AsmaName] { json("asma") ?? [] }
}

/// Ruqya from the Quran, the passages the site lists (/api/ruqya); text from the verified pack.
struct RuqyaView: View {
    private let data = ContentLibrary.shared.ruqya
    private let lib = ContentLibrary.shared
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var player = RecitationPlayer()

    var body: some View {
        Group {
            if let d = data {
                List {
Group {
                    Section { Text(d.title).font(.ui(.headline)) }
                    ForEach(d.items, id: \.self) { q in
                        let ayat = (try? lib.store?.ayat(surah: q.s, from: q.a, to: q.b)) ?? []
                        let name = lib.surah(q.s)?.shortName ?? ""
                        Section(q.a == q.b ? "\(name) · \(Num.int(q.a))" : "\(name) · \(Num.int(q.a))–\(Num.int(q.b))") {
                            Text(ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " "))
                                .font(.custom(ContentLibrary.mushafFont, size: 21, relativeTo: .body)).lineSpacing(8)
                            if folder != nil {
                                Button {
                                    player.folder = folder
                                    player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
                                    player.stopAt = .init(surah: q.s, ayah: q.b)
                                    player.play(from: .init(surah: q.s, ayah: q.a))
                                } label: { Label("استمع", systemImage: "play.circle") }
                            }
                        }
                    }
                
}.listRowBackground(Brand.surface)
}
            } else {
                ContentUnavailableView("الرقية غير متاحة", systemImage: "book", description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            }
        }
        .brandScreen()
        .navigationTitle("الرقية الشرعية")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private var folder: String? { (try? lib.store?.reciterFolders())?[reciter] }
}

/// The 99 names as listed on /tools/asma-ul-husna, each can become a card.
struct AsmaView: View {
    private let names = ContentLibrary.shared.asma
    @State private var query = ""

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(filtered, id: \.n) { a in
                    NavigationLink {
                        TextCardView(title: "بطاقة اسم", text: a.name, reference: "من أسماء الله الحسنى", initialRatio: .square)
                    } label: {
                        VStack(spacing: 6) {
                            Text(Num.int(a.n)).font(.ui(.caption2)).foregroundStyle(.secondary)
                            Text(a.name).font(.custom("Amiri", size: 22, relativeTo: .title3)).foregroundStyle(Brand.primaryInk)
                                .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, minHeight: 86)
                        .card()
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("اصنع بطاقة")
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .overlay { if names.isEmpty { ContentUnavailableView("غير متاح", systemImage: "sparkles") } }
        .brandScreen()
        .navigationTitle("الأسماء الحسنى")
        .searchable(text: $query, prompt: "ابحث في الأسماء")
    }

    private var filtered: [AsmaName] {
        let q = ContentStore.clean(query.trimmingCharacters(in: .whitespaces))
        return q.isEmpty ? names : names.filter { ContentStore.clean($0.name).contains(q) }
    }
}
