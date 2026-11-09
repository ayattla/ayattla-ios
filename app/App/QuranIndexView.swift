import SwiftUI
import UIKit
import AyatDesign
import AyatContent

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
            } else if query.isEmpty {
                dashboard
            } else {
                List {
Group {
                    Section("السور المطابقة") {
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
                                            .font(.ui(.caption)).foregroundStyle(Brand.primaryInk)
                                        Text(a.textUthmani).font(.custom(ContentLibrary.mushafFont, size: 19, relativeTo: .body))
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                
}.listRowBackground(Brand.surface)
}
                .overlay {
                    if !query.isEmpty && surahResults.isEmpty && ayahResults.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
        }
        .brandScreen()
        .navigationTitle("القرآن")
        .searchable(text: $query, prompt: "ابحث في السور والآيات")
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Tools of the Quran section, in the site's order (tool directory, group «القرآن»).
    private static let tools: [(String, String, () -> AnyView)] = [
        ("الأجزاء", "list.number", { AnyView(JuzListView()) }),
        ("آيات بالموضوع", "leaf", { AnyView(TopicsView()) }),
        ("التجويد الملون", "paintpalette", { AnyView(TajweedView()) }),
        ("معاني الكلمات", "character.book.closed", { AnyView(WordByWordView()) }),
        ("اختبار الحفظ", "eye.slash", { AnyView(HifzTestView()) }),
        ("خطة الختمة", "calendar", { AnyView(KhatmaView()) }),
        ("الإذاعات", "antenna.radiowaves.left.and.right", { AnyView(RadioView()) }),
        ("الرقية الشرعية", "shield", { AnyView(RuqyaView()) }),
        ("الأسماء الحسنى", "sparkles", { AnyView(AsmaView()) }),
    ]

    /// Section root: hero with continue reading, the tool launcher, then every surah.
    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                HeroHeader(eyebrow: "المصحف الشريف", title: "القرآن الكريم",
                           subtitle: "\(Num.int(lib.pageCount)) صفحة بترقيم مصحف المدينة والرسم العثماني، مع التلاوة والتفسير") {
                    HStack(spacing: Brand.Space.s) {
                        NavigationLink { MushafReader(startPage: max(lastPage, 1)) } label: {
                            Label(lastPage > 0 ? "تابع: \(pageTitle(lastPage))" : "ابدأ القراءة", systemImage: "book")
                                .lineLimit(1)
                        }
                        .buttonStyle(.brandGold)
                        NavigationLink { JuzListView() } label: { Text("الأجزاء") }
                            .buttonStyle(GhostOnEmerald())
                    }
                    .padding(.top, Brand.Space.xs)
                }

                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    SectionHeader("أدوات القرآن", subtitle: "اقرأ واستمع واحفظ وتدبر")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.Space.s),
                                             count: typeSize.isAccessibilitySize ? 2 : 3), spacing: Brand.Space.s) {
                        ForEach(Self.tools.indices, id: \.self) { i in
                            let t = Self.tools[i]
                            NavigationLink { t.2() } label: { LauncherTile(t.0, symbol: t.1) }
                                .buttonStyle(.pressable)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    SectionHeader("السور", subtitle: "\(Num.int(lib.surahs.count)) سورة · ابحث بالاسم أو بكلمة من الآية")
                    LazyVStack(spacing: 0) {
                        ForEach(lib.surahs) { s in
                            NavigationLink { MushafReader(startPage: s.pageStart ?? 1) } label: {
                                SurahRow(surah: s).padding(.horizontal, Brand.Space.l).padding(.vertical, Brand.Space.s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if s.id < lib.surahs.count { Divider().overlay(Brand.line).padding(.leading, 64) }
                        }
                    }
                    .surface(.raised)
                }
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
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
        let first = lib.page(page).first
        let name = first.flatMap { lib.surah($0.surah)?.shortName } ?? ""
        return "\(name) · صفحة \(Num.int(page))"
    }
}

struct SurahRow: View {
    let surah: Surah
    var body: some View {
        HStack(spacing: 12) {
            Text(Num.int(surah.id))
                .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                .frame(width: 36, height: 36)
                .background(Brand.tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(surah.shortName).font(.ui(.headline))
                Text(QuranText.surahLine(surah)).font(.ui(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            if let p = surah.pageStart {
                Text("ص \(Num.int(p))").font(.ui(.caption)).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: Brand.minTap)
        .accessibilityElement(children: .combine)
    }
}
