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
    @State private var page = 1
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
        .background(Color(light: 0xFBF9F2, dark: 0x121512).ignoresSafeArea())
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
        .background(Color(light: 0xFBF9F2, dark: 0x121512))
    }

    private var folder: String? { (try? lib.store?.reciterFolders())?[reciter] }

    private var firstOnPage: Ayah? { (try? lib.store?.page(page))?.first }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuranLayer.allCases) { l in
                    let on = selection == l
                    Button { selection = l } label: {
                        Text(l.title)
                            .font(.ui(.footnote, .medium))
                            .foregroundStyle(on ? .white : .primary)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(on ? Brand.primary : Color.cardSurface, in: Capsule())
                            .overlay(Capsule().stroke(on ? .clear : Brand.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }
}

struct MushafPage: View {
    let number: Int
    let scale: Double
    let highlighted: RecitationPlayer.Position?
    private let lib = ContentLibrary.shared

    var body: some View {
        let ayat = (try? lib.store?.page(number)) ?? []
        // Text grows with the page width (iPad, landscape spread) so a page fills the screen as on
        // a phone; the reader's own size setting multiplies on top.
        GeometryReader { geo in
        let scale = self.scale * min(max(geo.size.width / 400, 1), 1.7)
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(blocks(ayat).enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .header(let s):
                        Text(s.namePlain)
                            .font(.custom(ContentLibrary.mushafFont, size: 20 * scale, relativeTo: .title3))
                            .foregroundStyle(Brand.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Brand.goldSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.accent.opacity(0.7), lineWidth: 1))
                            .overlay(alignment: .leading) { StarOrnament().frame(width: 14, height: 14).padding(.leading, 12) }
                            .overlay(alignment: .trailing) { StarOrnament().frame(width: 14, height: 14).padding(.trailing, 12) }
                            .accessibilityAddTraits(.isHeader)
                    case .basmala(let text):
                        Text(text).font(.custom(ContentLibrary.mushafFont, size: 22 * scale, relativeTo: .title3))
                    case .text(let run):
                        Text(attributed(run))
                            .font(.custom(ContentLibrary.mushafFont, size: 23 * scale, relativeTo: .title2))
                            .lineSpacing(10 * scale)
                            .multilineTextAlignment(.center)
                            .tint(.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 22)
            .background(Color(light: 0xFFFDF7, dark: 0x1A1D1A), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(light: 0xE8E2D0, dark: 0x2E3B32), lineWidth: 1))
            .padding(.horizontal, 16).padding(.bottom, 12)
            Text(Num.int(number)).font(.ui(.caption)).foregroundStyle(.secondary).padding(.bottom, 8)
        }
        }
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
                part.backgroundColor = Color(hex: 0xF3D27A).opacity(0.55)
            }
            out += part
        }
        return out
    }
}
