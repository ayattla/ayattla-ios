import WidgetKit
import SwiftUI
import AppIntents
import AyatDesign

// MARK: - «دعاء من القرآن» (same daily pick as the home section, text from the verified pack)

struct DuaEntry: TimelineEntry {
    let date: Date
    let surah: Int
    let ayah: Int
    let text: String
    let reference: String
}

enum DuaContent {
    private struct Refs: Decodable { struct R: Decodable { let s: Int; let a: Int; let b: Int }; let quran: [R] }

    static func entry(for date: Date) -> DuaEntry {
        let store = WidgetContent.store
        guard let raw = (try? store?.meta("duas")) ?? nil,
              let refs = try? JSONDecoder().decode(Refs.self, from: Data(raw.utf8)).quran, !refs.isEmpty
        else { return DuaEntry(date: date, surah: 1, ayah: 1, text: "", reference: "دعاء من القرآن") }
        let r = refs[Int(date.timeIntervalSince1970 / 86400) % refs.count]
        let ayat = (try? store?.ayat(surah: r.s, from: r.a, to: r.b)) ?? []
        let text = ayat.map { $0.textUthmani + " " + WidgetContent.marker($0.ayah) }.joined(separator: " ")
        let name = (try? store?.surahs())?.first { $0.id == r.s }?.shortName ?? ""
        let ref = r.a == r.b ? "\(name) · \(Num.int(r.a))" : "\(name) · \(Num.int(r.a))–\(Num.int(r.b))"
        return DuaEntry(date: date, surah: r.s, ayah: r.a, text: text, reference: ref)
    }
}

struct DuaProvider: TimelineProvider {
    func placeholder(in context: Context) -> DuaEntry { DuaEntry(date: Date(), surah: 1, ayah: 1, text: "", reference: "دعاء من القرآن") }
    func getSnapshot(in context: Context, completion: @escaping (DuaEntry) -> Void) { completion(DuaContent.entry(for: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DuaEntry>) -> Void) {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        var entries = [DuaContent.entry(for: Date())]
        for d in 1...3 { if let n = cal.date(byAdding: .day, value: d, to: today) { entries.append(DuaContent.entry(for: n)) } }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DuaWidgetView: View {
    let entry: DuaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("دعاء من القرآن").font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk)
                Spacer()
                Text(entry.reference).font(.ui(.caption2, .medium)).foregroundStyle(Brand.muted)
            }
            Spacer(minLength: 0)
            Text(entry.text)
                .font(.custom("Amiri Quran", size: family == .systemLarge ? 22 : 17))
                .lineSpacing(family == .systemLarge ? 8 : 4)
                .multilineTextAlignment(.center).minimumScaleFactor(0.5)
                .foregroundStyle(Brand.ink)
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "ayattla://ayah/\(entry.surah)/\(entry.ayah)"))
        .containerBackground(for: .widget) { Brand.surface }
    }
}

struct DuaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuranDua", provider: DuaProvider()) { DuaWidgetView(entry: $0) }
            .configurationDisplayName("دعاء من القرآن")
            .description("دعاء جديد كل يوم بنص المصحف")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - «التسبيح»: count on the Home Screen without opening the app (33 for each phrase)

enum TasbihWidgetStore {
    static let phrases = ["سبحان الله", "الحمد لله", "الله أكبر"]
    static let goal = 33
    private static let d = UserDefaults.standard
    static var phrase: Int { get { d.integer(forKey: "tw.phrase") } set { d.set(newValue, forKey: "tw.phrase") } }
    static var count: Int { get { d.integer(forKey: "tw.count") } set { d.set(newValue, forKey: "tw.count") } }
}

struct TasbihTapIntent: AppIntent {
    static let title: LocalizedStringResource = "سبح"
    func perform() async throws -> some IntentResult {
        var c = TasbihWidgetStore.count + 1, p = TasbihWidgetStore.phrase
        if c >= TasbihWidgetStore.goal { c = 0; p = (p + 1) % TasbihWidgetStore.phrases.count }
        TasbihWidgetStore.count = c; TasbihWidgetStore.phrase = p
        return .result()
    }
}

struct TasbihResetIntent: AppIntent {
    static let title: LocalizedStringResource = "ابدأ من جديد"
    func perform() async throws -> some IntentResult {
        TasbihWidgetStore.count = 0; TasbihWidgetStore.phrase = 0
        return .result()
    }
}

struct TasbihEntry: TimelineEntry { let date: Date; let phrase: Int; let count: Int }

struct TasbihProvider: TimelineProvider {
    private func now() -> TasbihEntry { TasbihEntry(date: Date(), phrase: TasbihWidgetStore.phrase, count: TasbihWidgetStore.count) }
    func placeholder(in context: Context) -> TasbihEntry { TasbihEntry(date: Date(), phrase: 0, count: 0) }
    func getSnapshot(in context: Context, completion: @escaping (TasbihEntry) -> Void) { completion(now()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TasbihEntry>) -> Void) { completion(Timeline(entries: [now()], policy: .never)) }
}

struct TasbihWidgetView: View {
    let entry: TasbihEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(TasbihWidgetStore.phrases[entry.phrase % TasbihWidgetStore.phrases.count])
                .font(.ui(.headline, .bold)).foregroundStyle(Brand.ink).minimumScaleFactor(0.7)
            Button(intent: TasbihTapIntent()) {
                Text(Num.int(entry.count))
                    .font(.ui(.largeTitle, .bold)).foregroundStyle(Brand.onPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.primary, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("سبح، العدد \(entry.count) من \(TasbihWidgetStore.goal)")
            HStack {
                Text("من \(Num.int(TasbihWidgetStore.goal))").font(.ui(.caption2, .medium)).foregroundStyle(Brand.muted)
                Spacer()
                Button(intent: TasbihResetIntent()) {
                    Image(systemName: "arrow.counterclockwise").font(.caption).foregroundStyle(Brand.muted)
                }
                .buttonStyle(.plain).accessibilityLabel("ابدأ من جديد")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { Brand.surface }
    }
}

struct TasbihWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Tasbih", provider: TasbihProvider()) { TasbihWidgetView(entry: $0) }
            .configurationDisplayName("التسبيح")
            .description("سبح من الشاشة الرئيسية بدون ما تفتح التطبيق")
            .supportedFamilies([.systemSmall])
    }
}
