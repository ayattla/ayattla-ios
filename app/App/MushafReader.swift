import SwiftUI
import UIKit
import AyatDesign
import AyatContent

// MARK: - Reader

/// Page-by-page mushaf reader, per design/Quran.dc.html. Pages turn right-to-left.
struct MushafReader: View {
    let startPage: Int
    var focus: RecitationPlayer.Position?

    @AppStorage("quran.lastPage") private var lastPage = 0
    @AppStorage(Prefs.fontScale) private var fontScale = FontScale.m.rawValue
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @AppStorage(Favorites.key) private var favorites = ""
    @AppStorage(MushafTheme.key) private var mushafTheme = MushafTheme.paper.rawValue
    @State private var page = 1
    @State private var marks = MushafMarks.load()
    @State private var showMarks = false
    @State private var layer = QuranLayer.mushaf
    /// Blurs the page while listening, to recite from memory (site: «إخفاء الآيات»).
    @State private var hideText = false
    @State private var selected: RecitationPlayer.Position?
    /// Reuses the recitation already playing (from the mini player) so its controls show here.
    @State private var player = (AudioCenter.shared.active as? RecitationPlayer) ?? RecitationPlayer()
    private let lib = ContentLibrary.shared

    init(startPage: Int, focus: RecitationPlayer.Position? = nil) {
        self.startPage = startPage
        self.focus = focus
        _page = State(initialValue: startPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            LayerChips(selection: $layer)
            GeometryReader { geo in
                // iPad in landscape: two facing pages, odd on the right as in the printed mushaf.
                if size == .regular && geo.size.width > geo.size.height * 1.15 && layer == .mushaf {
                    TabView(selection: spread) {
                        ForEach(1...max((lib.pageCount + 1) / 2, 1), id: \.self) { s in
                            HStack(spacing: 1) {
                                pageView(2 * s - 1)
                                if 2 * s <= lib.pageCount { pageView(2 * s) }
                            }
                            .background(Brand.line)
                            .tag(s)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    TabView(selection: $page) {
                        ForEach(1...max(lib.pageCount, 1), id: \.self) { n in
                            pageView(n).tag(n)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .environment(\.openURL, OpenURLAction { url in
                if let p = Self.position(url) { selected = p; return .handled }
                return .systemAction
            })
            if folder != nil {
                PlayerBar(player: player, reciterName: Catalog.reciter(reciter)?.name ?? "") {
                    firstAyah(on: page)
                }
            }
        }
        // Where you are in the juz, and a bookmark for this page (same as Android).
        .safeAreaInset(edge: .bottom) { juzBar }
        .sheet(isPresented: $showMarks) { marksSheet }
        .background(MushafStyle.backdrop.ignoresSafeArea())
        .id(mushafTheme)   // the page colours are read from the chosen theme
        // Reading the mushaf keeps the screen awake, like the leading mushaf apps.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .brandScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(title).font(.ui(.headline))
                    Text(subtitle).font(.ui(.caption2)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) { MushafThemeMenu() }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("حجم الخط", selection: $fontScale) {
                        ForEach(FontScale.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                } label: { Image(systemName: "textformat.size") }
                .accessibilityLabel("حجم خط المصحف")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { hideText.toggle() } label: { Image(systemName: hideText ? "eye" : "eye.slash") }
                    .accessibilityLabel(hideText ? "أظهر الآيات" : "أخف الآيات لاختبار الحفظ")
                    .disabled(layer != .mushaf)
            }
        }
        .onAppear {
            player.folder = folder
            player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
            player.stopAt = nil
            player.stopsAtSurahEnd = false
            AudioCenter.shared.fullPlayerShown = folder != nil
        }
        // Playback carries on after leaving the mushaf; the mini player takes over.
        .onDisappear { AudioCenter.shared.fullPlayerShown = false }
        .onChange(of: page) { _, p in lastPage = p }
        // A page that stays on screen two seconds counts as read for «رحلتي مع القرآن».
        .task(id: page) {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            Journey.shared.readPage(page); JourneyReminder.goalCheck()
        }
        .onChange(of: player.current) { _, c in
            if let c, let p = (try? lib.store?.ayat(surah: c.surah, from: c.ayah, to: c.ayah))?.first?.page, p != page {
                page = p
            }
        }
        .onChange(of: reciter) { _, _ in player.stop(); player.folder = folder }
        .sheet(item: $selected) { p in
            AyahActions(position: p, isFavorite: Favorites.list(favorites).contains(p),
                        canListen: folder != nil,
                        onListen: { selected = nil; player.play(from: p) },
                        onFavorite: { favorites = Favorites.toggled(favorites, p) })
                .presentationDetents([.medium, .large])
        }
    }

    @Environment(\.horizontalSizeClass) private var size

    /// Spread index (pages 2s-1 and 2s) mapped onto `page`, so the rest of the reader is unchanged.
    private var spread: Binding<Int> {
        Binding(get: { (page + 1) / 2 }, set: { page = 2 * $0 - 1 })
    }

    @ViewBuilder private func pageView(_ n: Int) -> some View {
        Group {
            if layer == .mushaf {
                MushafPage(number: n, scale: FontScale(rawValue: fontScale)?.factor ?? 1,
                           highlighted: player.current ?? focus)
                    .blur(radius: hideText ? 9 : 0)
                    .overlay {
                        if hideText {
                            Button { hideText = false } label: {
                                Label("الآيات مخفية لاختبار الحفظ، اضغط للإظهار", systemImage: "eye")
                                    .font(.ui(.footnote, .medium)).foregroundStyle(Brand.primaryInk)
                                    .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                                    .background(Brand.surface, in: Capsule())
                                    .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
            } else {
                LayerPage(number: n, layer: layer, scale: FontScale(rawValue: fontScale)?.factor ?? 1)
            }
        }
        .background(MushafStyle.backdrop)
    }

    private var folder: String? { lib.reciterFolders[reciter] }

    private var juzBar: some View {
        let juz = firstOnPage?.juz ?? MushafMarks.juz(of: page)
        let (from, to) = MushafMarks.pages(juz: juz)
        return VStack(spacing: 6) {
            ProgressView(value: Double(page - from + 1), total: Double(to - from + 1)).tint(MushafStyle.gold)
            HStack {
                Text("الجزء \(Num.int(juz)) · صفحة \(Num.int(page - from + 1)) من \(Num.int(to - from + 1))")
                    .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.muted)
                Spacer()
                Button { marks = MushafMarks.toggle(page) } label: {
                    Image(systemName: marks.contains(page) ? "bookmark.fill" : "bookmark").foregroundStyle(MushafStyle.gold)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(marks.contains(page) ? "إزالة علامة الصفحة" : "ضع علامة على الصفحة")
                Button { showMarks = true } label: { Image(systemName: "list.bullet").frame(width: 44, height: 44) }
                    .accessibilityLabel("علاماتي")
            }
        }
        .padding(.horizontal, 16).padding(.top, 6)
        .background(MushafStyle.backdrop)
    }

    private var marksSheet: some View {
        NavigationStack {
            List {
                if marks.isEmpty {
                    Text("ضع علامة على أي صفحة من زر العلامة أسفل المصحف، وترجع لها من هنا").foregroundStyle(Brand.muted)
                }
                ForEach(marks.sorted(), id: \.self) { p in
                    Button {
                        showMarks = false; page = p
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill").foregroundStyle(MushafStyle.gold)
                            Text("صفحة \(Num.int(p))" + (lib.page(p).first.flatMap { lib.surah($0.surah)?.namePlain }.map { " · سورة \($0)" } ?? ""))
                            Spacer()
                            Text("الجزء \(Num.int(MushafMarks.juz(of: p)))").font(.ui(.caption)).foregroundStyle(Brand.muted)
                        }
                    }
                }
            }
            .navigationTitle("علاماتي").navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var firstOnPage: Ayah? { lib.page(page).first }
    private var title: String { firstOnPage.flatMap { lib.surah($0.surah)?.namePlain } ?? "المصحف" }
    private var subtitle: String {
        "الجزء \(Num.int(firstOnPage?.juz ?? 1)) · صفحة \(Num.int(page))"
    }

    private func firstAyah(on page: Int) -> RecitationPlayer.Position {
        let a = firstOnPage
        return .init(surah: a?.surah ?? 1, ayah: a?.ayah ?? 1)
    }

    static func position(_ url: URL) -> RecitationPlayer.Position? {
        guard url.scheme == "ayah" else { return nil }
        let p = url.absoluteString.dropFirst("ayah:".count).split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? .init(surah: p[0], ayah: p[1]) : nil
    }
}

extension RecitationPlayer.Position: Identifiable {
    var id: String { "\(surah):\(ayah)" }
}

/// Display layers from the design, as on the site: the mushaf, tajweed colors, word meanings, tafsir.
enum QuranLayer: String, CaseIterable, Identifiable {
    case mushaf, tajweed, words, tafsir
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mushaf: "المصحف"
        case .tajweed: "التجويد"
        case .words: "معاني الكلمات"
        case .tafsir: "التفسير"
        }
    }
}

struct LayerChips: View {
    @Binding var selection: QuranLayer

    var body: some View {
        CategorySelector(QuranLayer.allCases.map { (id: $0, title: $0.title) }, selection: $selection)
            .padding(.vertical, 8)
    }
}

struct MushafPage: View {
    let number: Int
    let scale: Double
    let highlighted: RecitationPlayer.Position?
    private let lib = ContentLibrary.shared

    var body: some View {
        let ayat = lib.page(number)
        // Text grows with the page width (iPad, landscape spread) so a page fills the screen as on
        // a phone; the reader's own size setting multiplies on top.
        GeometryReader { geo in
        let scale = self.scale * min(max(geo.size.width / 400, 1), 1.7)
        ScrollView {
            VStack(spacing: 16) {
                runningHead(ayat)
                ForEach(Array(blocks(ayat).enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .header(let s):
                        SurahCartouche(surah: s, scale: scale)
                    case .basmala(let text):
                        Text(text).font(.custom(ContentLibrary.mushafFont, size: 23 * scale, relativeTo: .title3))
                            .foregroundStyle(Color(light: 0x1B1A16, dark: 0xECE8DC))
                    case .text(let run):
                        Text(attributed(run))
                            // Room above and below each line so the marks never touch the next line.
                            .font(.custom(ContentLibrary.mushafFont, size: 25 * scale, relativeTo: .title2))
                            .lineSpacing(15 * scale)
                            .foregroundStyle(MushafStyle.ink)
                            .multilineTextAlignment(.center)
                            .tint(.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                PageMedallion(number: number).padding(.top, 4)
            }
            .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 8)
            // The page in a mushaf frame: paper inside a double gold rule.
            .background(MushafStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { MushafBorder() }
            .padding(10)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        }
    }

    /// Running head: the surah at the start, the juz at the end, over a fine gold rule.
    private func runningHead(_ ayat: [Ayah]) -> some View {
        let first = ayat.first
        return VStack(spacing: 6) {
            HStack {
                Text(first.flatMap { lib.surah($0.surah)?.namePlain } ?? "")
                Spacer()
                Text("الجزء \(Num.int(first?.juz ?? 1))")
            }
            .font(.ui(.caption, .medium)).foregroundStyle(MushafStyle.gold)
            Rectangle().fill(MushafStyle.gold.opacity(0.45)).frame(height: 0.8)
        }
        .padding(.top, 12)
    }

    enum Block { case header(Surah), basmala(String), text([Ayah]) }

    private func blocks(_ ayat: [Ayah]) -> [Block] {
        var out: [Block] = []
        var run: [Ayah] = []
        for a in ayat {
            if a.ayah == 1, let s = lib.surah(a.surah) {
                if !run.isEmpty { out.append(.text(run)); run = [] }
                out.append(.header(s))
                if s.hasBasmala, let b = lib.basmala { out.append(.basmala(b)) }
            }
            run.append(a)
        }
        if !run.isEmpty { out.append(.text(run)) }
        return out
    }

    private func attributed(_ run: [Ayah]) -> AttributedString {
        var out = AttributedString()
        for a in run {
            var part = AttributedString(a.textUthmani + " " + QuranText.marker(a.ayah) + " ")
            part.link = URL(string: "ayah:\(a.surah):\(a.ayah)")
            if highlighted == .init(surah: a.surah, ayah: a.ayah) {
                part.backgroundColor = Color(light: 0xF6E7B0, dark: 0x2F4A38)
            }
            out += part
        }
        return out
    }
}

/// Page bookmarks (kept on the device) and the juz boundaries of the Madinah mushaf (604 pages).
enum MushafMarks {
    static let starts = [1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582]
    static func juz(of page: Int) -> Int { (starts.lastIndex { $0 <= page } ?? 0) + 1 }
    static func pages(juz: Int) -> (Int, Int) {
        let j = min(max(juz, 1), 30)
        return (starts[j - 1], j == 30 ? 604 : starts[j] - 1)
    }
    static func load() -> Set<Int> {
        Set((UserDefaults.standard.string(forKey: "mushaf.bookmarks") ?? "").split(separator: ",").compactMap { Int($0) })
    }
    static func toggle(_ page: Int) -> Set<Int> {
        var m = load()
        if m.contains(page) { m.remove(page) } else { m.insert(page) }
        UserDefaults.standard.set(m.map(String.init).joined(separator: ","), forKey: "mushaf.bookmarks")
        return m
    }
}
