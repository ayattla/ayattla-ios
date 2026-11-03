import SwiftUI
import AyatDesign

// The sections of ayattla.com's home page, in the site's order (docs/SITE_AUDIT.md §2): product
// cards, sources line, how it works, features, stats, questions and the closing call. Wording is
// the site's; where the site describes the web (files deleted after an hour), the app says what
// it actually does (everything stays on the device).

/// The six product cards under the hero.
struct HomeProducts: View {
    @AppStorage("quran.lastPage") private var lastPage = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2),
                  spacing: 10) {
            card("مقطع تلاوة", "فيديو بتظليل الكلمات وأكثر من ٣٠ قارئا", "play.rectangle") { ClipMakerView() }
            card("بطاقة آية", "صورة جاهزة للمنشورات والحالة", "rectangle.portrait") { AyahCardView() }
            card("حالة واتساب", "صورة أو فيديو أو نص متحرك", "text.bubble") { StatusSourceView() }
            card("بطاقة حديث", "صحيح أو حسن مع تخريجه", "text.book.closed") { HadithView() }
            card("أسماء الله الحسنى", "بطاقة لكل اسم بخلفية حقيقية", "sparkles") { AsmaView() }
            card("المصحف", "٦٠٤ صفحات بترقيم مصحف المدينة", "book") { MushafReader(startPage: max(lastPage, 1)) }
        }
    }

    private func card<D: View>(_ title: String, _ subtitle: String, _ symbol: String, @ViewBuilder _ to: @escaping () -> D) -> some View {
        NavigationLink { to() } label: { ToolCard(title, subtitle: subtitle, symbol: symbol) }
            .buttonStyle(.plain)
    }
}

/// «مصادر موثوقة:» line with the three sources.
struct HomeSources: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("مصادر موثوقة:").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.ink)
            FlowLayout(spacing: 6) {
                chip("النص القرآني من Tanzil")
                chip("التلاوات من EveryAyah")
                chip("توقيت الكلمات من Quran.com")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func chip(_ t: String) -> some View {
        Label(t, systemImage: "checkmark.seal").font(.ui(.caption, .medium)).foregroundStyle(Brand.primaryInk)
            .padding(.horizontal, 10).frame(minHeight: 30)
            .background(Brand.tint, in: Capsule())
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("ثلاث خطوات ويصبح مقطعك جاهزا")
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 12) {
                    Text(Num.int(i + 1)).font(.ui(.headline)).foregroundStyle(Brand.primary)
                        .frame(width: 36, height: 36).background(Brand.accent, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.0).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                        Text(s.1).font(.ui(.footnote)).foregroundStyle(Brand.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
            NavigationLink { ClipMakerView() } label: {
                Label("ابدأ مجانا الآن", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.brandPrimary)
        }
        .padding(16)
        .card()
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("ما الذي يميز آيات تتلى")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                ForEach(Array(Self.items.enumerated()), id: \.offset) { _, f in ToolCard(f.0, subtitle: f.1, symbol: f.2) }
            }
        }
    }
}

/// The four numbers band, counted from the app's own data where it has it.
struct HomeStats: View {
    var body: some View {
        let surahs = ContentLibrary.shared.surahs.count
        let translations = Catalog.translations.filter { !$0.id.isEmpty }.count
        HStack(spacing: 0) {
            stat(Catalog.reciters.count, "قارئا")
            stat(surahs > 0 ? surahs : 114, "سورة")
            stat(translations, "ترجمة وتفسير")
            stat(CardOptions.Ratio.allCases.count, "مقاسات")
        }
        .padding(.vertical, 18)
        .emeraldPanel(radius: 20)
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(Num.int(n)).font(.ui(.title2, .semibold)).foregroundStyle(Brand.onDeepAccent)
            Text(label).font(.ui(.caption)).foregroundStyle(Brand.onPrimary.opacity(0.85)).multilineTextAlignment(.center)
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
            SectionHeader("الأسئلة الشائعة")
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
        VStack(spacing: 12) {
            StarOrnament().frame(width: 22, height: 22)
            Text("اجعلها صدقة جارية، اصنع مقطعا وشاركه").font(.ui(.title3, .semibold)).multilineTextAlignment(.center)
            Text("صانع مقاطع وبطاقات قرآنية مجاني، صدقة جارية لكل من شارك").font(.ui(.footnote))
                .foregroundStyle(Brand.onPrimary.opacity(0.85)).multilineTextAlignment(.center)
            NavigationLink { ClipMakerView() } label: { Text("اصنع مقطعك الآن") }
                .buttonStyle(.brandGold)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .emeraldPanel()
    }
}
