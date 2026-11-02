import SwiftUI
import UIKit
import AyatDesign
import AyatContent

/// Saved ayat ("s:a" keys, newest first), shared by the reader and Library.
enum Favorites {
    static let key = "favorites.ayat"

    static func list(_ raw: String) -> [RecitationPlayer.Position] {
        raw.split(separator: ",").compactMap { part in
            let p = part.split(separator: ":").compactMap { Int($0) }
            return p.count == 2 ? .init(surah: p[0], ayah: p[1]) : nil
        }
    }

    static func toggled(_ raw: String, _ p: RecitationPlayer.Position) -> String {
        var l = list(raw)
        if let i = l.firstIndex(of: p) { l.remove(at: i) } else { l.insert(p, at: 0) }
        return l.map { "\($0.surah):\($0.ayah)" }.joined(separator: ",")
    }
}

enum QuranText {
    /// "مكية · ٧ آيات"
    static func surahLine(_ s: Surah) -> String {
        let place = s.revelation == "Medinan" ? "مدنية" : "مكية"
        return "\(place) · \(ayatCount(s.ayahCount))"
    }

    static func ayatCount(_ n: Int) -> String {
        switch n {
        case 1: "آية واحدة"
        case 2: "آيتان"
        case 3...10: "\(Num.int(n)) آيات"
        default: "\(Num.int(n)) آية"
        }
    }

    /// "[البقرة: ٢٥٥]"
    static func reference(_ p: RecitationPlayer.Position) -> String {
        let name = ContentLibrary.shared.surah(p.surah)?.shortName ?? Num.int(p.surah)
        return "[\(name): \(Num.int(p.ayah))]"
    }

    /// Ayah end mark (U+06DD) with the number, drawn as an ornament by the mushaf font.
    static func marker(_ n: Int) -> String { "\u{06DD}\(Num.int(n))" }
}

// MARK: - Index

/// Quran tab: surah index, continue reading, and search in names and ayat.
struct QuranView: View {
    @AppStorage("quran.lastPage") private var lastPage = 0
    @State private var query = ""
    private let lib = ContentLibrary.shared

    var body: some View {
        Group {
            if !lib.isReady {
                ContentUnavailableView("المصحف غير متاح", systemImage: "book.closed",
                                       description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            } else {
                List {
                    if query.isEmpty, lastPage > 0 {
                        Section {
                            NavigationLink { MushafReader(startPage: lastPage) } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("تابع القراءة").font(.headline)
                                        Text(pageTitle(lastPage)).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                } icon: { Image(systemName: "bookmark.fill").foregroundStyle(Brand.primary) }
                                .frame(minHeight: Brand.minTap)
                            }
                        }
                    }
                    Section(query.isEmpty ? "السور" : "السور المطابقة") {
                        ForEach(surahResults) { s in
                            NavigationLink { MushafReader(startPage: s.pageStart ?? 1) } label: { SurahRow(surah: s) }
                        }
                    }
                    if ayahResults.count > 0 {
                        Section("في الآيات (\(Num.int(ayahResults.count)))") {
                            ForEach(ayahResults) { a in
                                NavigationLink { MushafReader(startPage: a.page ?? 1, focus: .init(surah: a.surah, ayah: a.ayah)) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(QuranText.reference(.init(surah: a.surah, ayah: a.ayah)))
                                            .font(.caption).foregroundStyle(Brand.primaryInk)
                                        Text(a.textUthmani).font(.custom(ContentLibrary.mushafFont, size: 19, relativeTo: .body))
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .overlay {
                    if !query.isEmpty && surahResults.isEmpty && ayahResults.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
        }
        .navigationTitle("القرآن")
        .searchable(text: $query, prompt: "ابحث في السور والآيات")
    }

    private var surahResults: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return lib.surahs }
        let clean = ContentStore.clean(q)
        return lib.surahs.filter {
            ContentStore.clean($0.shortName).localizedStandardContains(clean) || Num.int($0.id) == q || "\($0.id)" == q
        }
    }

    private var ayahResults: [Ayah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        return (try? lib.store?.search(q, limit: 50)) ?? []
    }

    private func pageTitle(_ page: Int) -> String {
        let first = (try? lib.store?.page(page))?.first
        let name = first.flatMap { lib.surah($0.surah)?.shortName } ?? ""
        return "\(name) · صفحة \(Num.int(page))"
    }
}

struct SurahRow: View {
    let surah: Surah
    var body: some View {
        HStack(spacing: 12) {
            Text(Num.int(surah.id))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.primaryInk)
                .frame(width: 36, height: 36)
                .background(Brand.tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(surah.shortName).font(.headline)
                Text(QuranText.surahLine(surah)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let p = surah.pageStart {
                Text("ص \(Num.int(p))").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: Brand.minTap)
        .accessibilityElement(children: .combine)
    }
}

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
    @State private var selected: RecitationPlayer.Position?
    @State private var player = RecitationPlayer()
    private let lib = ContentLibrary.shared

    init(startPage: Int, focus: RecitationPlayer.Position? = nil) {
        self.startPage = startPage
        self.focus = focus
        _page = State(initialValue: startPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            LayerChips()
            TabView(selection: $page) {
                ForEach(1...max(lib.pageCount, 1), id: \.self) { n in
                    MushafPage(number: n, scale: FontScale(rawValue: fontScale)?.factor ?? 1,
                               highlighted: player.current ?? focus)
                        .tag(n)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear {
            player.folder = folder
            player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
        }
        .onDisappear { player.stop() }
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
                .presentationDetents([.medium])
        }
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

/// Display layers from the design. Only the mushaf is available until the Quran Foundation
/// permission (tajweed, word meanings) and the tafsir licence are confirmed.
struct LayerChips: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("المصحف", on: true)
                chip("التجويد", on: false)
                chip("معاني الكلمات", on: false)
                chip("التفسير", on: false)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, on: Bool) -> some View {
        Text(title)
            .font(.footnote.weight(.medium))
            .foregroundStyle(on ? .white : .secondary)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(on ? Brand.primary : Color.cardSurface, in: Capsule())
            .overlay(Capsule().stroke(on ? .clear : Brand.line, lineWidth: 1))
            .accessibilityAddTraits(on ? [.isSelected] : [])
            .accessibilityHint(on ? "" : "قريبا")
    }
}

struct MushafPage: View {
    let number: Int
    let scale: Double
    let highlighted: RecitationPlayer.Position?
    private let lib = ContentLibrary.shared

    var body: some View {
        let ayat = (try? lib.store?.page(number)) ?? []
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(blocks(ayat).enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .header(let s):
                        Text(s.namePlain)
                            .font(.custom(ContentLibrary.mushafFont, size: 20 * scale, relativeTo: .title3))
                            .foregroundStyle(Brand.g0)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xD9CFAE), lineWidth: 1))
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
            Text(Num.int(number)).font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
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

struct AyahActions: View {
    let position: RecitationPlayer.Position
    let isFavorite: Bool
    let canListen: Bool
    let onListen: () -> Void
    let onFavorite: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let text = (try? ContentLibrary.shared.store?.ayat(surah: position.surah, from: position.ayah, to: position.ayah))?.first?.textUthmani ?? ""
        let share = "﴿\(text)﴾ \(QuranText.reference(position))"
        NavigationStack {
            List {
                Section {
                    Text(text).font(.custom(ContentLibrary.mushafFont, size: 21, relativeTo: .body))
                        .lineSpacing(8).padding(.vertical, 6)
                }
                Section {
                    if canListen {
                        Button { onListen() } label: { Label("استمع من هنا", systemImage: "play.fill") }
                    }
                    Button {
                        onFavorite(); dismiss()
                    } label: {
                        Label(isFavorite ? "أزل من المفضلة" : "أضف للمفضلة", systemImage: isFavorite ? "heart.slash" : "heart")
                    }
                    Button {
                        UIPasteboard.general.string = share; dismiss()
                    } label: { Label("نسخ الآية", systemImage: "doc.on.doc") }
                    ShareLink(item: share) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                }
            }
            .navigationTitle(QuranText.reference(position))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
        }
    }
}

struct PlayerBar: View {
    @Bindable var player: RecitationPlayer
    let reciterName: String
    let start: () -> RecitationPlayer.Position

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(reciterName).lineLimit(1)
                Spacer()
                if player.failed {
                    Text("تعذر التشغيل، تحقق من الاتصال").foregroundStyle(.red)
                } else if let c = player.current {
                    Text(QuranText.reference(c))
                }
            }
            .font(.caption).foregroundStyle(Brand.muted)
            HStack {
                Menu {
                    Picker("تكرار كل آية", selection: $player.repeatEach) {
                        ForEach(RecitationPlayer.repeats, id: \.self) { Text("\(Num.int($0)) مرة").tag($0) }
                    }
                } label: {
                    Image(systemName: player.repeatEach > 1 ? "repeat.1" : "repeat")
                        .frame(width: Brand.minTap, height: Brand.minTap)
                }
                .accessibilityLabel("تكرار كل آية")
                Spacer()
                Button { player.previous() } label: { Image(systemName: "forward.end.fill").frame(width: Brand.minTap, height: Brand.minTap) }
                    .accessibilityLabel("الآية السابقة")
                Button { player.toggle(startAt: start()) } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).foregroundStyle(.white)
                        .frame(width: 52, height: 52).background(Brand.primary, in: Circle())
                }
                .accessibilityLabel(player.isPlaying ? "إيقاف مؤقت" : "تشغيل")
                Button { player.next() } label: { Image(systemName: "backward.end.fill").frame(width: Brand.minTap, height: Brand.minTap) }
                    .accessibilityLabel("الآية التالية")
                Spacer()
                Button {
                    let i = RecitationPlayer.speeds.firstIndex(of: player.speed) ?? 1
                    player.speed = RecitationPlayer.speeds[(i + 1) % RecitationPlayer.speeds.count]
                } label: {
                    Text("\(Num.decimal(Double(player.speed), digits: player.speed == 1.25 || player.speed == 0.75 ? 2 : 1))×")
                        .font(.caption.weight(.medium)).padding(.horizontal, 10).frame(minHeight: 36)
                        .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                }
                .accessibilityLabel("السرعة")
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .card()
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}
