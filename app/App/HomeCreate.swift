import SwiftUI
import AyatDesign

// Home v3.1 (owner review): content making leads the page, with real photos and videos from the
// site's library behind the shortcuts; then a gallery of real backgrounds, daily tools and Quran
// content, each in its own card style so no two sections look the same.

/// Curated photos and videos for the home page, loaded once per launch from the site's library.
@MainActor @Observable
final class FeaturedMedia {
    static let shared = FeaturedMedia()
    private(set) var videos: [MediaLibrary.Item] = []
    private(set) var images: [MediaLibrary.Item] = []
    private(set) var byCategory: [String: [MediaLibrary.Item]] = [:]
    private var started = false

    func load() async {
        guard !started else { return }
        started = true
        let vs = (try? await MediaLibrary.search(.video, category: "mosques")) ?? []
        let ims = (try? await MediaLibrary.search(.image, category: "mosques")) ?? []
        let ns = (try? await MediaLibrary.search(.image, category: "night")) ?? []
        videos = Self.curated(vs)
        images = Self.curated(ims) + Self.curated(ns)
        byCategory["mosques"] = Self.mix(videos: videos, images: Self.curated(ims))
        if videos.isEmpty && images.isEmpty { started = false }   // try again next time the home shows
    }

    func gallery(_ category: String) async -> [MediaLibrary.Item] {
        if let c = byCategory[category] { return c }
        let v = (try? await MediaLibrary.search(.video, category: category)) ?? []
        let i = (try? await MediaLibrary.search(.image, category: category)) ?? []
        let out = Self.mix(videos: Self.curated(v), images: Self.curated(i))
        if !out.isEmpty { byCategory[category] = out }
        return out
    }

    private static func curated(_ items: [MediaLibrary.Item]) -> [MediaLibrary.Item] {
        let c = items.filter(\.curated)
        return Array((c.isEmpty ? items : c).prefix(10))
    }

    /// Video, photo, photo, video… so the rail alternates tall and shorter tiles.
    private static func mix(videos: [MediaLibrary.Item], images: [MediaLibrary.Item]) -> [MediaLibrary.Item] {
        var out: [MediaLibrary.Item] = []
        var vi = videos.makeIterator(), ii = images.makeIterator()
        while out.count < 14 {
            var added = false
            if let v = vi.next() { out.append(v); added = true }
            for _ in 0..<2 { if let i = ii.next() { out.append(i); added = true } }
            if !added { break }
        }
        return out
    }
}

/// A shortcut with a real photo or a looping video behind it (or the site's tile gradient while it
/// loads or when offline), a dark fade for the white text, and an icon chip.
struct MediaShortcut: View {
    let title: String
    let subtitle: String
    let symbol: String
    var media: MediaLibrary.Item?
    var gradient = 0
    var height: CGFloat = 170
    var big = false
    var badge: String?

    var body: some View {
        Rectangle().fill(Brand.tileGradient(gradient))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let media {
                    MediaThumb(url: media.type == .image ? (media.previewUrl ?? media.thumbUrl) : media.thumbUrl)
                    if media.type == .video, let url = media.previewUrl { LoopingVideo(url: url) }
                }
            }
            .overlay { LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.62)], startPoint: .top, endPoint: .bottom) }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: big ? 8 : 6) {
                    HStack {
                        Image(systemName: symbol).font(.system(size: big ? 18 : 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: big ? 42 : 34, height: big ? 42 : 34)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
                        Spacer()
                        if let badge { Badge(badge, gold: true) }
                    }
                    Spacer(minLength: 0)
                    Text(title).font(.ui(big ? .title2 : .headline, .bold)).foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.85)
                    Text(subtitle).font(.ui(big ? .subheadline : .caption)).foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(big ? 18 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        .clipShape(RoundedRectangle(cornerRadius: big ? Brand.Radius.hero : Brand.Radius.card, style: .continuous))
        .shadow(color: Color(hex: 0x0F1F17).opacity(0.16), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// «ابدأ صناعة المحتوى»: clip (large, video), ayah card and WhatsApp status (half width, photos),
/// hadith card (wide), each opening its editor; the photo or video carries into the editor.
struct HomeCreateBento: View {
    @State private var media = FeaturedMedia.shared
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            SiteSectionHead(eyebrow: "اصنع", "ابدأ صناعة المحتوى", subtitle: "مقاطع وبطاقات وحالات بخلفيات حقيقية، جاهزة للنشر")
            let v = media.videos.first
            NavigationLink { ClipMakerView(media: v?.ref) } label: {
                MediaShortcut(title: "مقطع تلاوة بالفيديو", subtitle: "تظليل الكلمة مع التلاوة وأكثر من ٣٠ قارئا، بخلفية فيديو حقيقية",
                              symbol: "play.rectangle.fill", media: v, gradient: 0, height: typeSize.isAccessibilitySize ? 260 : 210,
                              big: true, badge: "MP4")
            }
            .buttonStyle(.pressable)
            let cols = typeSize.isAccessibilitySize ? 1 : 2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.Space.m), count: cols), spacing: Brand.Space.m) {
                let card = media.images.first
                NavigationLink { AyahCardView(media: card?.ref) } label: {
                    MediaShortcut(title: "بطاقة آية", subtitle: "صورة للمنشورات والحالة", symbol: "photo.fill",
                                  media: card, gradient: 1, height: 190)
                }
                let status = media.images.dropFirst().first
                NavigationLink { StatusSourceView() } label: {
                    MediaShortcut(title: "حالة واتساب", subtitle: "صورة أو فيديو أو نص متحرك", symbol: "bubble.left.and.text.bubble.right.fill",
                                  media: status, gradient: 2, height: 190)
                }
            }
            .buttonStyle(.pressable)
            NavigationLink { HadithView() } label: {
                HStack(spacing: Brand.Space.m) {
                    IconTile("text.book.closed", style: .gold, size: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("بطاقة حديث").font(.ui(.headline)).foregroundStyle(Brand.ink)
                            Badge("جديد", gold: true)
                        }
                        Text("حديث صحيح أو حسن مع الراوي والمصدر والحكم").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.lineStrong)
                }
                .padding(16)
                .background(Brand.goldSoft, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous).strokeBorder(Brand.accent.opacity(0.35), lineWidth: 1))
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.pressable)
        }
        .task { await media.load() }
    }
}

/// «معرض الخلفيات والمقاطع»: a rail of real videos (tall) and photos from the site's library, by
/// collection. A video opens the clip maker with it, a photo opens the card maker with it.
struct HomeMediaGallery: View {
    @State private var media = FeaturedMedia.shared
    @State private var category = "mosques"
    @State private var items: [MediaLibrary.Item] = []
    @State private var loading = true

    private let categories: [(id: String, title: String)] = [
        ("mosques", "مساجد"), ("sky", "سماء"), ("night", "ليل"), ("nature", "طبيعة"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            SiteSectionHead(eyebrow: "المعرض", "خلفيات ومقاطع حقيقية",
                            subtitle: "من مكتبة الموقع (Pixabay وPexels). اضغط أي خلفية لتبدأ بها")
            CategorySelector(categories, selection: $category)
                .padding(.horizontal, -Brand.Space.l)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    if items.isEmpty {
                        ForEach(0..<5, id: \.self) { i in placeholder(i) }
                    }
                    ForEach(items) { it in link(it) }
                }
                .padding(.horizontal, Brand.Space.l).padding(.vertical, 4)
            }
            .padding(.horizontal, -Brand.Space.l)
            if !loading && items.isEmpty {
                Label("تعذر تحميل المعرض الآن. تحقق من الاتصال", systemImage: "wifi.exclamationmark")
                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)
            }
        }
        .task(id: category) {
            loading = true
            if category == "mosques" { await media.load() }
            items = await media.gallery(category)
            loading = false
        }
    }

    private func placeholder(_ i: Int) -> some View {
        let tall = i % 3 == 0
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Brand.surface2)
            .frame(width: tall ? 132 : 118, height: tall ? 236 : 158)
    }

    @ViewBuilder private func editor(_ it: MediaLibrary.Item) -> some View {
        if it.type == .video { ClipMakerView(media: it.ref) } else { AyahCardView(media: it.ref) }
    }

    private func link(_ it: MediaLibrary.Item) -> some View {
        NavigationLink { editor(it) } label: { tile(it) }
            .buttonStyle(.pressable)
    }

    private func tile(_ it: MediaLibrary.Item) -> some View {
        let video = it.type == .video
        return Brand.surface2
            .frame(width: video ? 132 : 118, height: video ? 236 : 158)
            .overlay { MediaThumb(url: it.thumbUrl) }
            .overlay { LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom) }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 5) {
                    Image(systemName: video ? "play.fill" : "photo").font(.system(size: 10, weight: .bold))
                    Text(video ? (MediaLibrary.durationText(it.duration).map { "مقطع · \($0)" } ?? "مقطع") : "بطاقة")
                        .font(.ui(.caption2, .semibold))
                }
                .foregroundStyle(.white)
                .padding(10)
            }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(video ? "اصنع مقطعا بهذه الخلفية" : "اصنع بطاقة بهذه الصورة")
    }
}

/// «المحتوى القرآني»: round icons with labels (a different shape from the cards above).
struct HomeQuranContent: View {
    @AppStorage("quran.lastPage") private var lastPage = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Entry { let title: String; let symbol: String; let open: () -> AnyView }

    private var entries: [Entry] {
        [
            .init(title: "المصحف", symbol: "book.fill") { AnyView(MushafReader(startPage: max(lastPage, 1))) },
            .init(title: "الاستماع", symbol: "headphones") { AnyView(MushafReader(startPage: max(lastPage, 1))) },
            .init(title: "البحث", symbol: "magnifyingglass") { AnyView(QuranView()) },
            .init(title: "المواضيع", symbol: "square.grid.3x2.fill") { AnyView(TopicsView()) },
            .init(title: "الأجزاء", symbol: "list.number") { AnyView(JuzListView()) },
            .init(title: "التجويد", symbol: "paintpalette.fill") { AnyView(TajweedView()) },
            .init(title: "معاني الكلمات", symbol: "character.book.closed.fill") { AnyView(WordByWordView()) },
            .init(title: "اختبار الحفظ", symbol: "checkmark.seal.fill") { AnyView(HifzTestView()) },
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            SiteSectionHead(eyebrow: "القرآن", "المحتوى القرآني", subtitle: "القراءة والاستماع والبحث والتدبر")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: typeSize.isAccessibilitySize ? 2 : 4),
                      spacing: Brand.Space.m) {
                ForEach(entries.indices, id: \.self) { i in
                    let e = entries[i]
                    NavigationLink { e.open() } label: {
                        VStack(spacing: 8) {
                            Image(systemName: e.symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(Brand.primaryInk)
                                .frame(width: 58, height: 58)
                                .background(Brand.surface, in: Circle())
                                .overlay(Circle().strokeBorder(Brand.line, lineWidth: 1))
                                .shadow(color: Color(hex: 0x0F1F17).opacity(0.06), radius: 6, y: 3)
                            Text(e.title).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.vertical, Brand.Space.l).padding(.horizontal, Brand.Space.s)
            .background(Brand.surface2, in: RoundedRectangle(cornerRadius: Brand.Radius.hero, style: .continuous))
        }
    }
}
