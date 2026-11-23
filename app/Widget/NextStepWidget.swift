import WidgetKit
import SwiftUI
import AppIntents
import AyatCalc
import AyatDesign

/// «يومي: الخطوة التالية» on the Home Screen and the Lock Screen: the step for this part of the day,
/// chosen by the prayer times of the city picked in the widget's settings, and the season of the day
/// (Friday, Ramadan, the ten of Dhul-Hijjah, voluntary fasts). Same rules as the app's card and the
/// Android widget. A new entry is laid at every prayer, so it changes on its own through the day.

struct CityEntity: AppEntity {
    let id: String
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "المدينة"
    static let defaultQuery = CityQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct CityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        identifiers.filter { PrayerCity.named($0) != nil }.map(CityEntity.init)
    }
    func suggestedEntities() async throws -> [CityEntity] { PrayerCity.all.map { CityEntity(id: $0.name) } }
    func defaultResult() async -> CityEntity? { CityEntity(id: PrayerCity.all[0].name) }
}

struct NextStepIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "يومي"
    static let description = IntentDescription("خطوة يومي بعد كل صلاة")
    @Parameter(title: "المدينة") var city: CityEntity?
}

struct NextStepEntry: TimelineEntry {
    let date: Date
    let slot: TodaySlot
    let nextTime: String
    let note: SeasonNote?
}

struct NextStepProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NextStepEntry {
        NextStepEntry(date: Date(), slot: .morning, nextTime: "", note: nil)
    }

    func snapshot(for configuration: NextStepIntent, in context: Context) async -> NextStepEntry {
        Self.entry(at: Date(), city: Self.city(configuration))
    }

    func timeline(for configuration: NextStepIntent, in context: Context) async -> Timeline<NextStepEntry> {
        let city = Self.city(configuration)
        let zone = TimeZone(identifier: city.zone) ?? .current
        let now = Date()
        var dates = [now]
        // One entry at each prayer of today and tomorrow that is still ahead.
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        for back in 0...1 {
            guard let day = cal.date(byAdding: .day, value: back, to: now) else { continue }
            let t = Self.times(city, zone, day)
            let start = cal.startOfDay(for: day)
            for s in TodaySlot.allCases {
                let at = start.addingTimeInterval(Double(PrayerTimes.displayMinute(t.hours(s.after))) * 60 + 5)
                if at > now { dates.append(at) }
            }
        }
        let entries = dates.sorted().prefix(8).map { Self.entry(at: $0, city: city) }
        return Timeline(entries: Array(entries), policy: .atEnd)
    }

    static func city(_ c: NextStepIntent) -> PrayerCity {
        c.city.flatMap { PrayerCity.named($0.id) } ?? PrayerCity.all[0]
    }

    static func times(_ city: PrayerCity, _ zone: TimeZone, _ day: Date) -> PrayerTimes {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return PrayerTimes.compute(year: c.year!, month: c.month!, day: c.day!, lat: city.lat, lng: city.lng,
                                   tzHours: PrayerTimes.tzHours(zone, at: day), method: city.method,
                                   ramadan: Hijri.isRamadan(day))
    }

    static func entry(at date: Date, city: PrayerCity) -> NextStepEntry {
        let zone = TimeZone(identifier: city.zone) ?? .current
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let t = times(city, zone, date)
        let hm = cal.dateComponents([.hour, .minute], from: date)
        let minute = (hm.hour ?? 0) * 60 + (hm.minute ?? 0)
        let slot = TodayPlan.slot(minute: minute, times: t)
        let back = TodayPlan.daysBack(minute: minute, times: t)
        let day = cal.date(byAdding: .day, value: -back, to: date) ?? date
        let tomorrow = times(city, zone, cal.date(byAdding: .day, value: 1, to: date) ?? date)
        let h = Hijri.fromGregorian(day)
        let notes = Seasons.notes(weekday: Seasons.isoWeekday(day, calendar: cal), hijriMonth: h.month, hijriDay: h.day,
                                  slot: slot, maghrib: Num.time(t.maghrib), fajrTomorrow: Num.time((back == 1 ? t : tomorrow).fajr))
        let nextHours = slot == .night ? (back == 1 ? t.fajr : tomorrow.fajr) : t.hours(slot.next.after)
        return NextStepEntry(date: date, slot: slot, nextTime: Num.time(nextHours), note: notes.first)
    }
}

struct NextStepWidgetView: View {
    let entry: NextStepEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 1) {
                    Text("يومي · بعد \(entry.slot.after.name)").font(.ui(.caption2, .semibold))
                    Text(entry.slot.title).font(.ui(.headline)).lineLimit(1)
                    Text(entry.note?.title ?? "التالي \(entry.slot.next.title)").font(.ui(.caption2)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("يومي · بعد \(entry.slot.after.name)")
                            .font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Brand.tint, in: Capsule())
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(TodaySlot.allCases) { s in
                                Circle().fill(s == entry.slot ? Brand.green : Brand.surface2)
                                    .frame(width: s == entry.slot ? 9 : 7, height: s == entry.slot ? 9 : 7)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text(entry.slot.title).font(.ui(.title3, .bold)).foregroundStyle(Brand.ink).lineLimit(1)
                    Text(entry.slot.line).font(.ui(.subheadline)).foregroundStyle(Brand.muted).lineLimit(1)
                    Spacer(minLength: 0)
                    if let n = entry.note {
                        Text("\(n.title) · \(n.line)")
                            .font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Brand.goldSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Text("التالي \(entry.nextTime): \(entry.slot.next.title)")
                            .font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(1)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "ayattla://home"))
        .containerBackground(for: .widget) { Brand.surface }
    }
}

struct NextStepWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "NextStep", intent: NextStepIntent.self, provider: NextStepProvider()) {
            NextStepWidgetView(entry: $0)
        }
        .configurationDisplayName("يومي: الخطوة التالية")
        .description("خطوة يومي بعد كل صلاة، ومواسم اليوم")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}
