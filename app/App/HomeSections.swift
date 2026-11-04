import SwiftUI
import AyatDesign

// The sections of ayattla.com's home page, in the site's order (docs/SITE_AUDIT.md §2): product
// cards, sources line, how it works, features, stats, questions and the closing call. Wording is
// the site's; where the site describes the web (files deleted after an hour), the app says what
// it actually does (everything stays on the device).

/// The site's six products as a design gallery (as in design tools: pick what to make, see its
/// shape first). Each card previews its format on an emerald canvas with the star lattice.
struct HomeProducts: View {
    @AppStorage("quran.lastPage") private var lastPage = 0

    private struct Item {
        let title: String, subtitle: String, symbol: String, ratio: CGFloat, badge: String?
        let open: () -> AnyView
    }

    private var items: [Item] {
        [
            .init(title: "مقطع تلاوة", subtitle: "فيديو بتظليل الكلمات وأكثر من ٣٠ قارئا", symbol: "play.fill", ratio: 9 / 16, badge: "MP4") { AnyView(ClipMakerView()) },
            .init(title: "بطاقة آية", subtitle: "صورة جاهزة للمنشورات والحالة", symbol: "photo", ratio: 4 / 5, badge: nil) { AnyView(AyahCardView()) },
            .init(title: "حالة واتساب", subtitle: "صورة أو فيديو أو نص متحرك", symbol: "text.bubble", ratio: 9 / 16, badge: nil) { AnyView(StatusSourceView()) },
            .init(title: "بطاقة حديث", subtitle: "صحيح أو حسن مع تخريجه", symbol: "text.book.closed", ratio: 1, badge: nil) { AnyView(HadithView()) },
            .init(title: "أسماء الله الحسنى", subtitle: "بطاقة لكل اسم بخلفية حقيقية", symbol: "sparkles", ratio: 1, badge: nil) { AnyView(AsmaView()) },
            .init(title: "المصحف", subtitle: "٦٠٤ صفحات بترقيم مصحف المدينة", symbol: "book", ratio: 3 / 4, badge: nil) { AnyView(MushafReader(startPage: max(lastPage, 1))) },
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            SiteSectionHead(eyebrow: "اصنع", "ماذا تصنع اليوم؟", subtitle: "اختر الشكل، ثم الآيات والقارئ والخلفية")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Brand.Space.m) {
                    ForEach(items.indices, id: \.self) { i in
                        let it = items[i]
                        NavigationLink { it.open() } label: { tile(it) }
                            .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Brand.Space.l)
                .padding(.vertical, Brand.Space.s)
            }
            .padding(.horizontal, -Brand.Space.l)
        }
    }

    private func tile(_ it: Item) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Brand.surface2)
                // Format preview: the canvas shape of this product, in the site's tile colours.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Brand.tileGradient(items.firstIndex { $0.title == it.title } ?? 0))
                    .overlay(Image(systemName: it.symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white))
                    .aspectRatio(it.ratio, contentMode: .fit)
                    .padding(14)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                if let b = it.badge {
                    Badge(b, gold: true).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: 150, height: 150)
            Text(it.title).font(.ui(.headline)).foregroundStyle(Brand.ink)
            Text(it.subtitle).font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 150, alignment: .leading)
        .padding(Brand.Space.s)
        .surface(.raised)
        .accessibilityElement(children: .combine)
    }
}

/// «مصادر موثوقة:» line with the three sources.
struct HomeSources: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("مصادر موثوقة:").font(.ui(.subheadline, .bold)).foregroundStyle(Brand.ink)
            FlowLayout(spacing: 8) {
                pill("النص القرآني من Tanzil")
                pill("التلاوات من EveryAyah")
                pill("توقيت الكلمات من Quran.com")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func pill(_ t: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Brand.green).frame(width: 7, height: 7)
            Text(t).font(.ui(.caption, .medium)).foregroundStyle(Brand.muted)
        }
        .padding(.horizontal, 12).frame(minHeight: 32)
        .background(Brand.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Brand.line, lineWidth: 1))
    }
}

/// «ثلاث خطوات ويصبح مقطعك جاهزا».
struct HomeSteps: View {
    static let steps: [(String, String)] = [
        ("اختر الآيات", "السورة والآيات، أو اختيار سريع مثل آية الكرسي وخواتيم البقرة."),
        ("اختر القارئ والشكل", "أكثر من ٣٠ قارئا، والمقاس والخلفية من مكتبة صور وفيديو حقيقية أو من جهازك."),
        ("حمل وشارك", "مقطع MP4 جاهز لواتساب وإنستغرام وتيك توك ويوتيوب."),
    ]

    var body: some View {
        VStack(spacing: Brand.Space.l) {
            SiteSectionHead(eyebrow: "كيف تعمل", "ثلاث خطوات ويصبح مقطعك جاهزا", subtitle: "كل شيء على جهازك، بلا حساب ولا تسجيل.")
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, s in
                VStack(spacing: 10) {
                    Text(Num.int(i + 1)).font(.ui(.title3, .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Brand.tileGradient(i == 2 ? 4 : 0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    Text(s.0).font(.ui(.headline)).foregroundStyle(Brand.ink)
                    Text(s.1).font(.ui(.footnote)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 22).padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .surface(.raised)
                .accessibilityElement(children: .combine)
            }
            NavigationLink { ClipMakerView() } label: {
                Label("ابدأ مجانا الآن", systemImage: "play.fill").frame(maxWidth: 320)
            }
            .buttonStyle(.brandPrimary)
        }
    }
}

/// «ما الذي يميز آيات تتلى».
struct HomeFeatures: View {
    static let items: [(String, String, String)] = [
        ("تظليل الكلمة مع التلاوة", "توقيتات دقيقة لكل كلمة، فيتابع المشاهد التلاوة بعينه، مع ١١ قارئا.", "highlighter"),
        ("أكثر من ٣٠ قارئا", "الحصري والمنشاوي وعبدالباسط والسديس والشريم والعفاسي وغيرهم.", "waveform"),
        ("أربعة مقاسات", "عمودي للريلز والستوري، و٤:٥ للمنشورات، ومربع، وأفقي ليوتيوب.", "aspectratio"),
        ("تفسير وترجمات", "التفسير الميسر وعشر لغات تظهر أسفل الآية بخط واضح.", "text.below.photo"),
        ("قوالب الإهداء", "صدقة جارية، إهداء، تهنئة رمضان والعيد والجمعة، باسم من تحب.", "gift"),
        ("بطاقات صور أيضا", "حول الآية إلى صورة للحالة أو المنشور بنفس الخطوط والخلفيات.", "photo"),
    ]

    var body: some View {
        VStack(spacing: Brand.Space.l) {
            SiteSectionHead(eyebrow: "المزايا", "ما الذي يميز آيات تتلى")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: Brand.Space.m)], spacing: Brand.Space.m) {
                ForEach(Array(Self.items.enumerated()), id: \.offset) { i, f in
                    VStack(spacing: 10) {
                        Image(systemName: f.2).font(.system(size: 26, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(i == 0 ? AnyShapeStyle(Color.white.opacity(0.18)) : AnyShapeStyle(Brand.tileGradient(i)),
                                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color(hex: 0x1F8A62).opacity(i == 0 ? 0 : 0.35), radius: 12, y: 8)
                            .accessibilityHidden(true)
                        Text(f.0).font(.ui(.headline)).foregroundStyle(i == 0 ? Color.white : Brand.ink)
                        Text(f.1).font(.ui(.footnote)).multilineTextAlignment(.center)
                            .foregroundStyle(i == 0 ? Color.white.opacity(0.88) : Brand.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 24).padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .modifier(FeatureCardStyle(featured: i == 0))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// First feature card in the site's green gradient; the rest are white cards with a top accent.
private struct FeatureCardStyle: ViewModifier {
    let featured: Bool
    func body(content: Content) -> some View {
        if featured {
            content.featureSurface(radius: Brand.Radius.card)
        } else {
            content.surface(.raised)
                .overlay(alignment: .top) { Capsule().fill(Brand.siteGradient).frame(width: 46, height: 3).offset(y: -1.5) }
        }
    }
}

/// The four numbers band, counted from the app's own data where it has it.
struct HomeStats: View {
    var body: some View {
        let surahs = ContentLibrary.shared.surahs.count
        let translations = Catalog.translations.filter { !$0.id.isEmpty }.count
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 20) {
            stat(Catalog.reciters.count, "قارئا")
            stat(surahs > 0 ? surahs : 114, "سورة")
            stat(translations, "ترجمة وتفسير")
            stat(CardOptions.Ratio.allCases.count, "مقاسات")
        }
        .padding(.vertical, 28).padding(.horizontal, 12)
        .featureSurface()
        .overlay {
            // Hairline dividers between the four numbers, as on the site.
            Rectangle().fill(Color.white.opacity(0.22)).frame(width: 1).padding(.vertical, 24)
        }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(Num.int(n)).font(.ui(size: 40, .bold)).foregroundStyle(.white)
            Text(label).font(.ui(.footnote)).foregroundStyle(Color.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// «الأسئلة الشائعة», answered for the app.
struct HomeFAQ: View {
    static let items: [(String, String)] = [
        ("هل التطبيق مجاني فعلا؟", "نعم، مجاني بالكامل وبدون تسجيل أو علامة مائية، نسأل الله أن يجعله صدقة جارية لكل من ساهم ونشر."),
        ("ما صيغة المقطع وأبعاده؟", "MP4 بأربعة مقاسات: عمودي 1080×1920 للريلز وتيك توك والستوري، و1080×1350 للمنشورات، ومربع 1080×1080، وأفقي 1920×1080 ليوتيوب."),
        ("كيف يعمل تظليل الكلمة مع التلاوة؟", "نعتمد على توقيتات دقيقة لبداية ونهاية كل كلمة في تلاوة القارئ، فتتلون الكلمة لحظة نطقها. الميزة متاحة مع القراء المميزين بنجمة في القائمة."),
        ("هل يمكن إضافة اسم للإهداء أو التهنئة؟", "نعم، اختر قالبا (صدقة جارية، إهداء، رمضان، العيد، الجمعة) واكتب الاسم."),
        ("من أين مصدر النص والتلاوات؟", "النص القرآني بالرسم العثماني من Tanzil عبر AlQuran Cloud، والتلاوات من مكتبة EveryAyah، وتوقيتات الكلمات من Quran.com."),
        ("أين تحفظ مقاطعي؟", "ينشأ المقطع على جهازك ويبقى في «مكتبتي» حتى تحذفه، ولا يرفع إلى أي خادم."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SiteSectionHead(eyebrow: "أسئلة", "الأسئلة الشائعة")
            VStack(spacing: 0) {
                ForEach(Array(Self.items.enumerated()), id: \.offset) { i, q in
                    DisclosureGroup {
                        Text(q.1).font(.ui(.footnote)).foregroundStyle(Brand.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 10)
                    } label: {
                        Text(q.0).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                            .frame(minHeight: Brand.minTap, alignment: .leading)
                    }
                    .tint(Brand.primaryInk)
                    .padding(.horizontal, 14)
                    if i < Self.items.count - 1 { Divider().overlay(Brand.line) }
                }
            }
            .card()
        }
    }
}

/// Closing call: «اجعلها صدقة جارية».
struct HomeClosing: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("اجعلها صدقة جارية — اصنع مقطعا وشاركه").font(.ui(.title3, .bold)).multilineTextAlignment(.center)
            Text("صانع مقاطع وبطاقات قرآنية مجاني، صدقة جارية لكل من شارك").font(.ui(.footnote))
                .foregroundStyle(Color.white.opacity(0.88)).multilineTextAlignment(.center)
            NavigationLink { ClipMakerView() } label: { Text("اصنع مقطعك الآن") }
                .buttonStyle(.brandDark)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .featureSurface()
    }
}
