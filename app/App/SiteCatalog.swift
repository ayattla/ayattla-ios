import SwiftUI
import AyatDesign
import AyatContent

/// Every tool as ayattla.com lists it (/tools/ and the home page's tool directory, November 2026):
/// the same titles, one-line descriptions, «جديد» badges, groups and order. The tools screen,
/// the home page and search all read from here, so the app shows the site's catalogue exactly.
struct SiteTool: Identifiable, Hashable {
    enum Group: String, CaseIterable, Identifiable {
        case content, quran, daily, hadith
        var id: String { rawValue }
        var title: String {
            switch self {
            case .content: "صناعة المحتوى"
            case .quran: "القرآن"
            case .daily: "أدوات يومية"
            case .hadith: "الحديث والتعلم"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let group: Group
    let isNew: Bool

    static func == (a: SiteTool, b: SiteTool) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// Order of /tools/ on the site; the clip maker (the site's home tool) leads content making.
    static let all: [SiteTool] = [
        .init(id: "clip", title: "صانع المقاطع القرآنية", subtitle: "فيديو بتظليل الكلمات وأكثر من ٣٠ قارئا", symbol: "play.rectangle.fill", group: .content, isNew: false),
        .init(id: "ayah-card", title: "صانع بطاقات الآيات", subtitle: "صورة جاهزة للحالة والمنشور بأربعة مقاسات", symbol: "photo.on.rectangle", group: .content, isNew: true),
        .init(id: "status", title: "حالات واتساب", subtitle: "صورة أو فيديو أو نص متحرك", symbol: "bubble.left.and.text.bubble.right", group: .content, isNew: false),
        .init(id: "listen", title: "المصحف المسموع والتحفيظ", subtitle: "استمع للسورة آية آية مع التكرار للحفظ", symbol: "headphones", group: .quran, isNew: true),
        .init(id: "search", title: "البحث في القرآن", subtitle: "ابحث بكلمة واصنع من النتيجة فيديو أو بطاقة", symbol: "magnifyingglass", group: .quran, isNew: true),
        .init(id: "topics", title: "آيات بالموضوع", subtitle: "الصبر والرزق والتوبة والرحمة مع التفسير الميسر", symbol: "leaf", group: .quran, isNew: true),
        .init(id: "favorites", title: "آياتي المحفوظة", subtitle: "الآيات التي حفظتها لتعود إليها وتصنع منها", symbol: "star", group: .content, isNew: true),
        .init(id: "ayah-of-the-day", title: "آية اليوم", subtitle: "آية جديدة كل يوم للتدبر والمشاركة", symbol: "sun.max", group: .quran, isNew: false),
        .init(id: "azkar", title: "الأذكار", subtitle: "أذكار الصباح والمساء والنوم مع العداد", symbol: "sun.horizon", group: .daily, isNew: true),
        .init(id: "hisn-almuslim", title: "حصن المسلم", subtitle: "أبواب الأذكار والأدعية كاملة مع العداد", symbol: "shield.lefthalf.filled", group: .daily, isNew: true),
        .init(id: "radio", title: "إذاعات القرآن", subtitle: "بث مباشر لإذاعات التلاوة", symbol: "radio", group: .quran, isNew: true),
        .init(id: "prayer-times", title: "مواقيت الصلاة", subtitle: "حسب مدينتك بطريقة الحساب المعتمدة", symbol: "clock", group: .daily, isNew: false),
        .init(id: "qibla", title: "اتجاه القبلة", subtitle: "زاوية القبلة من موقعك مع البوصلة", symbol: "safari", group: .daily, isNew: false),
        .init(id: "khatma", title: "خطة ختم القرآن", subtitle: "وزع الختمة على الأيام والصلوات", symbol: "book", group: .quran, isNew: true),
        .init(id: "hijri", title: "التاريخ الهجري", subtitle: "تحويل بين الهجري والميلادي", symbol: "calendar", group: .daily, isNew: false),
        .init(id: "occasions", title: "المناسبات الإسلامية", subtitle: "كم بقي على رمضان والعيدين وعرفة", symbol: "moon.stars", group: .daily, isNew: true),
        .init(id: "zakat", title: "حاسبة الزكاة", subtitle: "زكاة المال والذهب والفضة وعروض التجارة", symbol: "cylinder.split.1x2", group: .daily, isNew: true),
        .init(id: "tasbih", title: "المسبحة الإلكترونية", subtitle: "عداد تسبيح يحفظ العدد على جهازك", symbol: "circle.hexagongrid", group: .daily, isNew: false),
        .init(id: "hadith-card", title: "بطاقات الأحاديث الصحيحة", subtitle: "حديث صحيح أو حسن مع الراوي والمصدر والحكم", symbol: "text.book.closed", group: .content, isNew: true),
        .init(id: "tajweed", title: "المصحف الملون بالتجويد", subtitle: "أحكام التجويد بالألوان مع المفتاح", symbol: "paintpalette", group: .quran, isNew: true),
        .init(id: "word-by-word", title: "معاني الكلمات", subtitle: "كلمة بكلمة مع التفسير الميسر", symbol: "character.book.closed", group: .quran, isNew: true),
        .init(id: "hifz-test", title: "اختبار الحفظ", subtitle: "أخف الكلمات واختبر حفظك", symbol: "arrow.triangle.2.circlepath", group: .quran, isNew: true),
        .init(id: "duas", title: "أدعية من القرآن والسنة", subtitle: "مصنفة حسب الحاجة مع المصدر", symbol: "hands.sparkles", group: .daily, isNew: true),
        .init(id: "mushaf", title: "المصحف بالصفحات", subtitle: "٦٠٤ صفحات بترقيم مصحف المدينة", symbol: "book.pages", group: .quran, isNew: true),
        .init(id: "ruqya", title: "الرقية الشرعية", subtitle: "آيات الرقية من القرآن تتلى متتابعة", symbol: "play.circle", group: .quran, isNew: true),
        .init(id: "asma-ul-husna", title: "أسماء الله الحسنى", subtitle: "بطاقة لكل اسم من الأسماء الحسنى بخلفية حقيقية", symbol: "star.square", group: .quran, isNew: true),
        .init(id: "hadith", title: "الأحاديث النبوية حسب الموضوع", subtitle: "أحاديث صحيحة وحسنة بالتخريج والحكم والشرح", symbol: "books.vertical", group: .hadith, isNew: true),
        .init(id: "hadith-checker", title: "التحقق من حديث", subtitle: "الصق حديثا وصلك لتعرف تخريجه وحكمه", symbol: "checkmark.seal", group: .hadith, isNew: true),
        .init(id: "prayer-guide", title: "صفة الوضوء والصلاة", subtitle: "من الأحاديث الصحيحة مع الشرح", symbol: "drop", group: .hadith, isNew: true),
        .init(id: "kids-juz-amma", title: "تحفيظ الأطفال جزء عم", subtitle: "استماع وتكرار ونجوم وشهادة باسم الطفل", symbol: "star.circle", group: .hadith, isNew: true),
        .init(id: "group-khatma", title: "الختمة الجماعية", subtitle: "وزع الأجزاء على المجموعة برابط واحد", symbol: "person.3", group: .quran, isNew: true),
        .init(id: "qada-salah", title: "متتبع قضاء الصلوات", subtitle: "عداد لكل صلاة وخطة يومية", symbol: "checklist", group: .daily, isNew: true),
        .init(id: "sawm-tracker", title: "متتبع الصيام", subtitle: "قضاء رمضان والتطوع على تقويم هجري وميلادي", symbol: "moon", group: .daily, isNew: true),
        .init(id: "nearby-mosques", title: "المساجد القريبة", subtitle: "أقرب المساجد مع المسافة والاتجاهات", symbol: "mappin.and.ellipse", group: .daily, isNew: true),
    ]

    static func tool(_ id: String) -> SiteTool? { all.first { $0.id == id } }

    /// Position in the full list: drives the tile colour, as the site's nth-child cycle does.
    var index: Int { Self.all.firstIndex(of: self) ?? 0 }

    @ViewBuilder var destination: some View {
        switch id {
        case "clip": ClipMakerView()
        case "ayah-card": AyahCardView()
        case "status": StatusSourceView()
        case "listen", "mushaf":
            MushafReader(startPage: max(UserDefaults.standard.integer(forKey: "quran.lastPage"), 1))
        case "search": QuranView()
        case "topics": TopicsView()
        case "favorites": LibraryView(initial: .favorites)
        case "ayah-of-the-day": AyahOfTheDayView()
        case "azkar": AzkarView()
        case "hisn-almuslim": AzkarView(title: "حصن المسلم", showsDaily: false)
        case "radio": RadioView()
        case "prayer-times": PrayerTimesView()
        case "qibla": QiblaView()
        case "khatma", "group-khatma": KhatmaView()
        case "hijri": HijriView()
        case "occasions": OccasionsView()
        case "zakat": ZakatView()
        case "tasbih": TasbihView()
        case "hadith-card", "hadith": HadithView()
        case "tajweed": TajweedView()
        case "word-by-word": WordByWordView()
        case "hifz-test": HifzTestView()
        case "duas": DuasView()
        case "ruqya": RuqyaView()
        case "asma-ul-husna": AsmaView()
        case "hadith-checker": HadithCheckerView()
        case "prayer-guide": PrayerGuideView()
        case "kids-juz-amma": KidsJuzAmmaView()
        case "qada-salah": QadaView()
        case "sawm-tracker": SawmView()
        case "nearby-mosques": MosquesView()
        default: EmptyState(title, symbol: symbol)
        }
    }
}

/// «آية اليوم» as its own page (the site's /tools/ayah-of-the-day): today's ayah with its tafsir and
/// the same actions as the topic pages.
struct AyahOfTheDayView: View {
    var body: some View {
        let p = AyahOfTheDay.pick()
        TopicView(topic: TopicData(slug: "ayah-of-the-day", title: "آية اليوم",
                                   desc: "آية جديدة كل يوم للتدبر والمشاركة",
                                   items: [.init(s: p.surah, a: p.from, b: p.to)]))
    }
}

/// The site's tool card for a catalogue entry (centred, coloured tile, «جديد»).
struct SiteToolCard: View {
    let tool: SiteTool
    var compact = false
    var body: some View {
        if compact {
            LauncherTile(tool.title, symbol: tool.symbol, style: .accent(tool.accent))
        } else {
            ServiceCard(tool.title, subtitle: tool.subtitle, symbol: tool.symbol,
                        badge: tool.isNew ? "جديد" : nil, style: .accent(tool.accent))
        }
    }
}
