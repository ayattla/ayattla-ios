import WidgetKit
import SwiftUI
import CoreText
import AyatContent
import AyatDesign

/// «آية اليوم» on the Home Screen and Lock Screen (master prompt §2, §5ط). The same ayah as the
/// app's home (AyatContent.DailyAyah), text from the bundled verified pack, never from memory.
/// Tapping opens the ayah in the mushaf (ayattla://ayah/s/a).
struct DailyAyahEntry: TimelineEntry {
    let date: Date
    let pick: DailyAyah.Pick
    let text: String
    let reference: String
}

enum WidgetContent {
    static let store: ContentStore? = {
        let b = Bundle.main
        for url in b.urls(forResourcesWithExtension: "ttf", subdirectory: "Content") ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        guard let url = b.url(forResource: "content-v1", withExtension: "sqlite", subdirectory: "Content") else { return nil }
        return try? ContentStore(url: url)
    }()

    static func entry(for date: Date) -> DailyAyahEntry {
        let p = DailyAyah.pick(for: date)
        let ayat = (try? store?.ayat(surah: p.surah, from: p.from, to: p.to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + marker($0.ayah) }.joined(separator: " ")
        let name = (try? store?.surahs())?.first { $0.id == p.surah }?.shortName ?? ""
        let ref = p.from == p.to ? "\(name) · \(Num.int(p.from))" : "\(name) · \(Num.int(p.from))–\(Num.int(p.to))"
        return DailyAyahEntry(date: date, pick: p, text: text, reference: ref)
    }

    /// End-of-ayah sign with Arabic-Indic digits, as in the app's mushaf.
    static func marker(_ n: Int) -> String { "\u{06DD}\(Num.int(n))" }
}

struct DailyAyahProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyAyahEntry {
        DailyAyahEntry(date: Date(), pick: DailyAyah.picks[1], text: "", reference: "آية اليوم")
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyAyahEntry) -> Void) {
        completion(WidgetContent.entry(for: Date()))
    }

    /// Today's ayah, then a new entry at each of the next midnights.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAyahEntry>) -> Void) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var entries = [WidgetContent.entry(for: Date())]
        for d in 1...3 {
            if let next = cal.date(byAdding: .day, value: d, to: today) { entries.append(WidgetContent.entry(for: next)) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DailyAyahWidgetView: View {
    let entry: DailyAyahEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("آية اليوم · \(entry.reference)").font(.ui(.caption2, .semibold))
                    Text(entry.text).font(.custom("Amiri Quran", size: 13)).lineLimit(2)
                }
            case .accessoryInline:
                Text("آية اليوم: \(entry.reference)")
            default:
                VStack(spacing: family == .systemSmall ? 6 : 10) {
                    HStack {
                        Text("آية اليوم").font(.ui(.caption, .semibold)).foregroundStyle(Brand.onDeepAccent)
                        Spacer()
                        Text(entry.reference).font(.ui(.caption2, .medium)).foregroundStyle(Brand.onDeepAccent.opacity(0.9))
                    }
                    Spacer(minLength: 0)
                    Text(entry.text)
                        .font(.custom("Amiri Quran", size: family == .systemLarge ? 22 : 17))
                        .lineSpacing(family == .systemLarge ? 8 : 4)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Brand.onPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "ayattla://ayah/\(entry.pick.surah)/\(entry.pick.from)"))
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(hex: 0x17392F), Color(hex: 0x102D27), Color(hex: 0x0B211C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct DailyAyahWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyAyah", provider: DailyAyahProvider()) { DailyAyahWidgetView(entry: $0) }
            .configurationDisplayName("آية اليوم")
            .description("آية جديدة كل يوم للتدبر، تفتح في المصحف")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct AyatWidgetBundle: WidgetBundle {
    var body: some Widget { DailyAyahWidget() }
}
