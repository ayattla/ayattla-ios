import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Pack data (prayer guide, duas)

struct PrayerGuide: Codable {
    struct Item: Codable, Hashable { let text: String; let source: String; let grade: String; let url: String }
    struct Section: Codable, Hashable { let title: String; let items: [Item] }
    let lead: String
    let source: String
    let source_url: String
    let sections: [Section]
}

struct DuasData: Codable {
    struct QuranRef: Codable, Hashable { let s: Int; let a: Int; let b: Int }
    struct Item: Codable, Hashable { let i: Int?; let text: String }
    struct Chapter: Codable, Hashable { let name: String; let items: [Item] }
    struct Need: Codable, Hashable { let need: String; let chapters: [Chapter] }
    let quran: [QuranRef]
    let needs: [Need]
}

extension ContentLibrary {
    func json<T: Decodable>(_ key: String) -> T? {
        guard let raw = (try? store?.meta(key)) ?? nil, !raw.isEmpty else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(raw.utf8))
    }
    var prayerGuide: PrayerGuide? { json("prayer_guide") }
    var duas: DuasData? { json("duas") }
}

// MARK: - Generic text card (status from dhikr, hadith card)

/// Card for non-Quran text (dhikr, hadith), drawn with Amiri; same sizes and backgrounds as the ayah card.
struct TextCardView: View {
    let title: String
    let text: String
    let reference: String
    @State private var ratio: CardOptions.Ratio
    @State private var background = CardOptions.backgrounds[0]
    @State private var fontScale = 1.0
    @State private var saved = false

    init(title: String, text: String, reference: String, initialRatio: CardOptions.Ratio = .square) {
        self.title = title; self.text = text; self.reference = reference
        _ratio = State(initialValue: initialRatio)
    }

    private var model: CardCanvas.Model {
        .init(text: text, reference: reference, template: nil, name: nil, background: background, fontScale: fontScale,
              ratio: ratio, lightBackground: background.id == "sand", fontName: "Amiri")
    }

    var body: some View {
        EditorLayout(preview: CardCanvas(model: model, photo: nil)
            .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))) {
            Section("الشكل") {
                Picker("المقاس", selection: $ratio) { ForEach(CardOptions.Ratio.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.segmented)
                Picker("حجم الخط", selection: $fontScale) { ForEach(CardOptions.fontScales, id: \.1) { Text($0.0).tag($0.1) } }
                    .pickerStyle(.segmented)
                Picker("الخلفية", selection: $background) { ForEach(CardOptions.backgrounds) { Text($0.name).tag($0) } }
            }
            Section {
                Button {
                    if let img = CardCanvas.render(model, photo: nil) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        try? ProjectStore.shared.addImage(img, kind: title == "بطاقة حديث" ? .hadithCard : .status, title: title,
                                                          ratio: ratio.rawValue, settings: nil)
                        saved = true
                    }
                } label: { Label("حفظ في الصور ومكتبتي", systemImage: "square.and.arrow.down") }
                ShareLink(item: CardImage(model: model, photo: nil), preview: SharePreview(title)) {
                    Label("مشاركة", systemImage: "square.and.arrow.up")
                }
                AnimatedTextButton(model: model, photo: nil, title: title)
            }
        }
        .brandScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("حفظت الصورة في الصور وفي مكتبتي", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
    }
}

// MARK: - Hadith row (shared by browse, checker and guide)

struct HadithRow: View {
    let text: String
    let source: String
    let grade: String
    let category: String?
    let url: String
    var match: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let match {
                Text("التطابق \(Num.int(match))٪").font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
            }
            Text(text).font(.custom("Amiri", size: 18, relativeTo: .body)).lineSpacing(6).textSelection(.enabled)
            Text([source, grade.isEmpty ? nil : "الحكم: \(grade)", category].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.ui(.caption)).foregroundStyle(Brand.muted)
            HStack(spacing: 14) {
                if let u = URL(string: url), !url.isEmpty {
                    Link(destination: u) { Label("الشرح في الموسوعة", systemImage: "arrow.up.left.square") }
                }
                NavigationLink { TextCardView(title: "بطاقة حديث", text: text, reference: [source, grade].filter { !$0.isEmpty }.joined(separator: " · ")) } label: {
                    Label("اصنع بطاقة", systemImage: "rectangle.portrait")
                }
                ShareLink(item: "\(text)\n\n\(source)") { Label("مشاركة", systemImage: "square.and.arrow.up") }
            }
            .labelStyle(.iconOnly)
            .font(.ui(.title3))
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Hadith (/tools/hadith)

struct HadithView: View {
    @State private var cats: [SiteAPI.HadithPage.Cat] = []
    @State private var cat = ""
    @State private var query = ""
    @State private var items: [SiteAPI.Hadith] = []
    @State private var page = 1
    @State private var total = 0
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        List {
Group {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("الكل", "")
                        ForEach(cats, id: \.name) { c in chip("\(c.name) (\(Num.int(c.count)))", c.name) }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            Section {
                ForEach(items) { h in
                    HadithRow(text: h.text, source: h.source, grade: h.grade, category: h.cat, url: h.url)
                }
                if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                if !loading && items.count < total {
                    Button("عرض المزيد") { Task { await load(more: true) } }.frame(maxWidth: .infinity)
                }
            } header: {
                if total > 0 { Text("\(Num.int(total)) حديثا") }
            } footer: {
                Text("من موسوعة الأحاديث النبوية (hadeethenc.com)، بالتخريج والحكم ورابط الشرح.")
            }
        
}.listRowBackground(Brand.surface)
}
        .overlay {
            if failed && items.isEmpty {
                ContentUnavailableView {
                    Label("تعذر التحميل الآن", systemImage: "wifi.exclamationmark")
                } description: { Text("تحقق من الاتصال ثم حاول مرة أخرى") } actions: {
                    Button("إعادة المحاولة") { Task { await load(more: false) } }
                }
            } else if !loading && items.isEmpty && total == 0 && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .brandScreen()
        .navigationTitle("الأحاديث")
        .searchable(text: $query, prompt: "ابحث في الأحاديث")
        .onSubmit(of: .search) { Task { await load(more: false) } }
        .onChange(of: query) { _, q in if q.isEmpty { Task { await load(more: false) } } }
        .task { if items.isEmpty { await load(more: false) } }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        let on = cat == value
        return Button {
            cat = value
            Task { await load(more: false) }
        } label: {
            Text(title).font(.ui(.footnote, .medium)).foregroundStyle(on ? .white : .primary)
                .padding(.horizontal, 12).frame(minHeight: 36)
                .background(on ? Brand.primary : Color.cardSurface, in: Capsule())
                .overlay(Capsule().stroke(on ? .clear : Brand.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func load(more: Bool) async {
        loading = true; failed = false
        let p = more ? page + 1 : 1
        do {
            let r = try await SiteAPI.hadith(cat: cat, page: p, query: query.trimmingCharacters(in: .whitespaces))
            if cats.isEmpty { cats = r.cats }
            items = more ? items + r.items : r.items
            total = r.total; page = p
        } catch {
            failed = true
        }
        loading = false
    }
}

// MARK: - Hadith checker (/tools/hadith-checker)

struct HadithCheckerView: View {
    @State private var text = ""
    @State private var result: SiteAPI.HadithCheck?
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        Form {
Group {
            Section {
                TextField("الصق نص الحديث أو جزءا منه", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                Button {
                    Task { await check() }
                } label: {
                    if loading { ProgressView() } else { Text("تحقق").font(.ui(.headline)) }
                }
                .frame(maxWidth: .infinity, minHeight: Brand.minTap)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 || loading)
            } footer: {
                Text("يبحث في موسوعة الأحاديث النبوية ويعرض أقرب الأحاديث مع تخريجها وحكمها. النتيجة بحث وليست حكما من التطبيق؛ راجع أهل العلم.")
            }
            if failed {
                Section { Text("تعذر التحقق الآن، تحقق من الاتصال").foregroundStyle(.secondary) }
            }
            if let r = result {
                Section(r.items.isEmpty ? "لم يعثر على حديث مطابق في الموسوعة" : "أقرب النتائج") {
                    ForEach(r.items) { h in
                        HadithRow(text: h.text, source: h.source, grade: h.grade, category: h.cat, url: h.url, match: h.match)
                    }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("التحقق من حديث")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func check() async {
        loading = true; failed = false
        do { result = try await SiteAPI.checkHadith(text) } catch { failed = true }
        loading = false
    }
}

// MARK: - Prayer guide (/tools/prayer-guide)

struct PrayerGuideView: View {
    private let guide = ContentLibrary.shared.prayerGuide

    var body: some View {
        Group {
            if let g = guide {
                List {
Group {
                    Section { Text(g.lead).font(.ui(.subheadline)).foregroundStyle(.secondary) }
                    ForEach(g.sections, id: \.title) { s in
                        Section(s.title) {
                            ForEach(s.items, id: \.self) { h in
                                HadithRow(text: h.text, source: h.source, grade: h.grade, category: nil, url: h.url)
                            }
                        }
                    }
                
}.listRowBackground(Brand.surface)
}
            } else {
                ContentUnavailableView("غير متاح", systemImage: "drop", description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            }
        }
        .brandScreen()
        .navigationTitle("صفة الوضوء والصلاة")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Duas (/tools/duas)

struct DuasView: View {
    private let data = ContentLibrary.shared.duas
    private let lib = ContentLibrary.shared
    @State private var section = 0

    var body: some View {
        Group {
            if let d = data {
                List {
Group {
                    Picker("القسم", selection: $section) {
                        Text("من القرآن").tag(0)
                        Text("حسب الحاجة").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    if section == 0 {
                        ForEach(d.quran, id: \.self) { q in quranDua(q) }
                    } else {
                        ForEach(d.needs, id: \.need) { n in
                            NavigationLink { NeedView(need: n) } label: { Text(n.need).frame(minHeight: Brand.minTap) }
                        }
                    }
                
}.listRowBackground(Brand.surface)
}
            } else {
                ContentUnavailableView("الأدعية غير متاحة", systemImage: "hands.sparkles",
                                       description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            }
        }
        .brandScreen()
        .navigationTitle("الأدعية")
    }

    private func quranDua(_ q: DuasData.QuranRef) -> some View {
        let ayat = (try? lib.store?.ayat(surah: q.s, from: q.a, to: q.b)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let name = lib.surah(q.s)?.shortName ?? ""
        let ref = q.a == q.b ? "[\(name): \(Num.int(q.a))]" : "[\(name): \(Num.int(q.a))–\(Num.int(q.b))]"
        return VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.custom(ContentLibrary.mushafFont, size: 20, relativeTo: .body)).lineSpacing(8)
            HStack {
                Text(ref).font(.ui(.caption)).foregroundStyle(Brand.primaryInk)
                Spacer()
                NavigationLink { AyahCardView(surah: q.s, from: q.a, to: q.b) } label: { Image(systemName: "rectangle.portrait") }
                    .buttonStyle(.borderless).accessibilityLabel("اصنع بطاقة")
                ShareLink(item: "﴿\(text)﴾ \(ref)") { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless).accessibilityLabel("مشاركة")
            }
        }
        .padding(.vertical, 6)
    }
}

struct NeedView: View {
    let need: DuasData.Need
    var body: some View {
        List {
Group {
            ForEach(need.chapters, id: \.name) { c in
                Section(c.name) {
                    ForEach(c.items, id: \.self) { it in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(it.text).font(.custom("Amiri", size: 19, relativeTo: .body)).lineSpacing(6).textSelection(.enabled)
                            HStack {
                                Spacer()
                                NavigationLink { TextCardView(title: "حالة", text: it.text, reference: c.name, initialRatio: .story) } label: {
                                    Image(systemName: "rectangle.portrait")
                                }
                                .buttonStyle(.borderless).accessibilityLabel("اصنع حالة")
                                ShareLink(item: it.text) { Image(systemName: "square.and.arrow.up") }
                                    .buttonStyle(.borderless).accessibilityLabel("مشاركة")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle(need.need)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Radio (/tools/radio)

/// Live radio from the site's list (mp3quran.net). One shared player, so a station keeps playing
/// after leaving the screen and shows in the mini player.
@Observable
final class RadioPlayer {
    static let shared = RadioPlayer()

    /// The station loaded (playing or paused); nil when stopped.
    private(set) var playing: SiteAPI.Radio?
    private(set) var isPlaying = false
    private(set) var failed = false
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var stallObserver: NSObjectProtocol?

    func toggle(_ r: SiteAPI.Radio) {
        if playing == r { if isPlaying { pause() } else { resume() }; return }
        guard let url = URL(string: r.url) else { return }
        AudioCenter.shared.claim(self, spoken: false)
        failed = false
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status) { [weak self] item, _ in
            if item.status == .failed { DispatchQueue.main.async { self?.connectionLost() } }
        }
        if let stallObserver { NotificationCenter.default.removeObserver(stallObserver) }
        stallObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification,
                                                               object: item, queue: .main) { [weak self] _ in self?.connectionLost() }
        player.replaceCurrentItem(with: item)
        player.play()
        playing = r
        isPlaying = true
        AudioCenter.shared.changed()
    }

    func pause() { player.pause(); isPlaying = false; AudioCenter.shared.changed() }

    /// A live stream resumes at the live edge: reload the station rather than continue a stale buffer.
    func resume() {
        guard let r = playing else { return }
        playing = nil
        toggle(r)
    }

    func stop() {
        halt()
        AudioCenter.shared.release(self)
    }

    private func halt() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playing = nil
        isPlaying = false
    }

    private func connectionLost() {
        failed = true
        isPlaying = false
        AudioCenter.shared.changed()
    }
}

extension RadioPlayer: AudioSource {
    var audioIsPlaying: Bool { isPlaying }
    var audioTitle: String { playing?.name ?? "إذاعات القرآن" }
    var audioSubtitle: String { failed ? "انقطع الاتصال، اضغط للمحاولة" : "بث مباشر · إذاعات القرآن" }
    var audioIsLive: Bool { true }
    func audioPause() { pause() }
    func audioResume() { resume() }
    func audioNext() {}
    func audioPrevious() {}
    func audioStop() { halt() }
}

struct RadioView: View {
    @State private var radios: [SiteAPI.Radio] = []
    @State private var query = ""
    @State private var failed = false
    @State private var player = RadioPlayer.shared

    var body: some View {
        List(filtered) { r in
Group {
            Button { player.toggle(r) } label: {
                HStack {
                    Image(systemName: player.playing == r && player.isPlaying ? "pause.circle.fill" : "play.circle")
                        .font(.ui(.title2)).foregroundStyle(Brand.primary)
                    Text(r.name).foregroundStyle(.primary)
                    Spacer()
                    if player.playing == r {
                        if player.failed {
                            Text("انقطع الاتصال").font(.ui(.caption)).foregroundStyle(.red)
                        } else if player.isPlaying {
                            Image(systemName: "waveform").foregroundStyle(Brand.primaryInk)
                        }
                    }
                }
                .frame(minHeight: Brand.minTap)
            }
            .accessibilityLabel(player.playing == r && player.isPlaying ? "إيقاف \(r.name)" : "تشغيل \(r.name)")
        
}.listRowBackground(Brand.surface)
}
        .overlay {
            if failed && radios.isEmpty {
                ContentUnavailableView("تعذر تحميل الإذاعات", systemImage: "antenna.radiowaves.left.and.right.slash",
                                       description: Text("تحقق من الاتصال ثم حاول مرة أخرى"))
            } else if radios.isEmpty {
                ProgressView()
            }
        }
        .brandScreen()
        .navigationTitle("الإذاعات")
        .searchable(text: $query, prompt: "ابحث في الإذاعات")
        .task {
            do { radios = try await SiteAPI.radios() } catch { failed = true }
        }
    }

    private var filtered: [SiteAPI.Radio] {
        let q = ContentStore.clean(query.trimmingCharacters(in: .whitespaces))
        return q.isEmpty ? radios : radios.filter { ContentStore.clean($0.name).localizedStandardContains(q) }
    }
}

// MARK: - Hifz test (/tools/hifz-test)

/// Hides a share of the words (25٪، 50٪ or all) in a range of ayat; tap a hidden word to reveal it.
struct HifzTestView: View {
    enum Level: Double, CaseIterable, Identifiable {
        case quarter = 0.25, half = 0.5, all = 1
        var id: Double { rawValue }
        var title: String {
            switch self {
            case .quarter: "٢٥٪"
            case .half: "٥٠٪"
            case .all: "الكل"
            }
        }
    }

    @State private var surah = 1
    @State private var from = 1
    @State private var to = 7
    @State private var level = Level.half
    @State private var started = false
    @State private var hidden: Set<String> = []
    private let lib = ContentLibrary.shared

    var body: some View {
        Form {
Group {
            Section("الآيات") {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Stepper("من آية \(Num.int(from))", value: $from, in: 1...ayahCount)
                Stepper("إلى آية \(Num.int(to))", value: $to, in: from...ayahCount)
                Picker("نسبة الإخفاء", selection: $level) { ForEach(Level.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                Button(started ? "اختبار جديد" : "ابدأ الاختبار") { start() }
                    .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
            }
            if started {
                Section {
                    ForEach(ayat, id: \.id) { a in
                        WordFlow(words: Self.words(a.textUthmani), key: a.id, hidden: $hidden, marker: QuranText.marker(a.ayah))
                    }
                    Button("اكشف الكل") { hidden = [] }.frame(maxWidth: .infinity)
                } footer: {
                    Text("اضغط على الكلمة المخفية لكشفها. المخفي الآن: \(Num.int(hidden.count))")
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("اختبار الحفظ")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: surah) { _, s in from = 1; to = min(lib.surah(s)?.ayahCount ?? 1, 7); started = false }
        .onChange(of: from) { _, f in if to < f { to = f } }
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }
    private var ayat: [Ayah] { (try? lib.store?.ayat(surah: surah, from: from, to: to)) ?? [] }

    static func words(_ text: String) -> [String] { text.split(separator: " ").map(String.init) }

    /// Picks which words to hide; pause marks (single characters like ۖ) are never hidden.
    static func pick(_ keys: [String], words: [String], share: Double, seed: Int) -> Set<String> {
        var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: seed))
        let candidates = zip(keys, words).filter { $0.1.unicodeScalars.count > 1 }.map(\.0)
        let n = share >= 1 ? candidates.count : Int((Double(candidates.count) * share).rounded())
        return Set(candidates.shuffled(using: &rng).prefix(n))
    }

    private func start() {
        var keys: [String] = [], words: [String] = []
        for a in ayat { for (i, w) in Self.words(a.textUthmani).enumerated() { keys.append("\(a.id)#\(i)"); words.append(w) } }
        hidden = Self.pick(keys, words: words, share: level.rawValue, seed: Int(Date().timeIntervalSince1970))
        started = true
    }
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Words of one ayah, right to left, wrapping; hidden words show as blanks.
struct WordFlow: View {
    let words: [String]
    let key: String
    @Binding var hidden: Set<String>
    let marker: String

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                let k = "\(key)#\(i)"
                if hidden.contains(k) {
                    Button { hidden.remove(k) } label: {
                        Text(w).font(.custom(ContentLibrary.mushafFont, size: 22)).hidden()
                            .padding(.horizontal, 4)
                            .background(Brand.tint, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Brand.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("كلمة مخفية، اضغط للكشف")
                } else {
                    Text(w).font(.custom(ContentLibrary.mushafFont, size: 22))
                }
            }
            Text(marker).font(.custom(ContentLibrary.mushafFont, size: 22))
        }
        .padding(.vertical, 6)
    }
}

/// Simple wrapping layout that respects the layout direction.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing; row = max(row, s.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.width, x > 0 { x = 0; y += row + spacing; row = 0 }
            // Placed from the leading edge; SwiftUI mirrors leading/trailing in right-to-left.
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += s.width + spacing; row = max(row, s.height)
        }
    }
}
