import Foundation

/// Reciters and translations as listed on ayattla.com (docs/site_snapshot_2026-11-02.json).
/// Names only; audio and translation text come with the content pack. Diacritics removed (UI rule).
enum Catalog {
    struct Reciter: Identifiable, Hashable {
        let id: String
        let name: String
        /// Has word timings on Quran.com, so the clip maker can highlight words (★ on the site).
        let wordHighlight: Bool
    }

    struct Translation: Identifiable, Hashable {
        let id: String   // "" = no translation
        let name: String
    }

    static let reciters: [Reciter] = [
        .init(id: "basit_murattal", name: "الشيخ عبدالباسط عبدالصمد (مرتل)", wordHighlight: true),
        .init(id: "basit_mujawwad", name: "الشيخ عبدالباسط عبدالصمد (مجود)", wordHighlight: true),
        .init(id: "sudais", name: "الشيخ عبدالرحمن السديس", wordHighlight: true),
        .init(id: "maher", name: "الشيخ ماهر المعيقلي", wordHighlight: false),
        .init(id: "minshawi_murattal", name: "الشيخ محمد صديق المنشاوي (مرتل)", wordHighlight: true),
        .init(id: "minshawi_mujawwad", name: "الشيخ محمد صديق المنشاوي (مجود)", wordHighlight: true),
        .init(id: "shuraim", name: "الشيخ سعود الشريم", wordHighlight: true),
        .init(id: "alafasy", name: "الشيخ مشاري العفاسي", wordHighlight: true),
        .init(id: "husary", name: "الشيخ محمود خليل الحصري", wordHighlight: true),
        .init(id: "hudhaify", name: "الشيخ علي الحذيفي", wordHighlight: false),
        .init(id: "shatri", name: "الشيخ أبو بكر الشاطري", wordHighlight: true),
        .init(id: "ghamdi", name: "الشيخ سعد الغامدي", wordHighlight: false),
        .init(id: "ajamy", name: "الشيخ أحمد العجمي", wordHighlight: false),
        .init(id: "dossari", name: "الشيخ ياسر الدوسري", wordHighlight: false),
        .init(id: "qatami", name: "الشيخ ناصر القطامي", wordHighlight: false),
        .init(id: "qahtani", name: "الشيخ خالد القحطاني", wordHighlight: false),
        .init(id: "ayyoub", name: "الشيخ محمد أيوب", wordHighlight: false),
        .init(id: "jibreel", name: "الشيخ محمد جبريل", wordHighlight: false),
        .init(id: "rifai", name: "الشيخ هاني الرفاعي", wordHighlight: true),
        .init(id: "tablawy", name: "الشيخ محمد الطبلاوي", wordHighlight: true),
        .init(id: "budair", name: "الشيخ صلاح البدير", wordHighlight: false),
        .init(id: "bukhatir", name: "الشيخ صلاح بوخاطر", wordHighlight: false),
        .init(id: "basfar", name: "الشيخ عبدالله بصفر", wordHighlight: false),
        .init(id: "matroud", name: "الشيخ عبدالله مطرود", wordHighlight: false),
        .init(id: "juhany", name: "الشيخ عبدالله الجهني", wordHighlight: false),
        .init(id: "qasim", name: "الشيخ محسن القاسم", wordHighlight: false),
        .init(id: "neana", name: "الشيخ أحمد نعينع", wordHighlight: false),
        .init(id: "salamah", name: "الشيخ ياسر سلامة", wordHighlight: false),
        .init(id: "akhdar", name: "الشيخ إبراهيم الأخضر", wordHighlight: false),
        .init(id: "banna", name: "الشيخ محمود علي البنا", wordHighlight: false),
        .init(id: "alijaber", name: "الشيخ علي جابر", wordHighlight: false),
        .init(id: "abbad", name: "الشيخ فارس عباد", wordHighlight: false),
        .init(id: "sowaid", name: "الشيخ أيمن سويد", wordHighlight: false),
        .init(id: "tunaiji", name: "الشيخ خليفة الطنيجي", wordHighlight: false),
    ]

    static let translations: [Translation] = [
        .init(id: "", name: "بدون ترجمة"),
        .init(id: "ar.muyassar", name: "التفسير الميسر (عربي)"),
        .init(id: "en.sahih", name: "الإنجليزية — Saheeh International"),
        .init(id: "ur.jalandhry", name: "الأردية — جالندهري"),
        .init(id: "id.indonesian", name: "الإندونيسية"),
        .init(id: "tr.diyanet", name: "التركية — Diyanet"),
        .init(id: "fr.hamidullah", name: "الفرنسية — Hamidullah"),
        .init(id: "bn.bengali", name: "البنغالية"),
        .init(id: "ms.basmeih", name: "الملايوية — Basmeih"),
        .init(id: "es.garcia", name: "الإسبانية — Isa Garcia"),
        .init(id: "de.bubenheim", name: "الألمانية — Bubenheim"),
        .init(id: "ru.kuliev", name: "الروسية — Kuliev"),
    ]

    static func reciter(_ id: String) -> Reciter? { reciters.first { $0.id == id } }
    static func translation(_ id: String) -> Translation? { translations.first { $0.id == id } }
}
