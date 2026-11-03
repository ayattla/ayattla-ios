import SwiftUI
import AyatDesign
import AyatCalc

/// Every tool of the Tools tab (docs/APP_ARCHITECTURE.md §1). Tools that depend on the content
/// pack or on behaviour not yet confirmed on the site show a placeholder until they are built.
enum ToolItem: String, CaseIterable, Identifiable {
    case azkar, tasbih, duas, prayer, qibla, hijri, occasions, zakat, qada, sawm, mosques, hadith, hadithChecker, prayerGuide, kids
    var id: String { rawValue }

    var title: String {
        switch self {
        case .azkar: "الأذكار"
        case .tasbih: "المسبحة"
        case .duas: "الأدعية"
        case .prayer: "مواقيت الصلاة"
        case .qibla: "القبلة"
        case .hijri: "الهجري"
        case .occasions: "المناسبات"
        case .zakat: "الزكاة"
        case .qada: "قضاء الصلوات"
        case .sawm: "الصيام"
        case .mosques: "المساجد"
        case .hadith: "الأحاديث"
        case .hadithChecker: "التحقق من حديث"
        case .prayerGuide: "صفة الوضوء والصلاة"
        case .kids: "تحفيظ الأطفال جزء عم"
        }
    }

    var symbol: String {
        switch self {
        case .azkar: "sun.max"
        case .tasbih: "circle.circle"
        case .duas: "hands.sparkles"
        case .prayer: "clock"
        case .qibla: "location.north.line"
        case .hijri: "calendar"
        case .occasions: "star"
        case .zakat: "percent"
        case .qada: "checklist"
        case .sawm: "moon"
        case .mosques: "mappin.and.ellipse"
        case .hadith: "text.book.closed"
        case .hadithChecker: "checkmark.seal"
        case .prayerGuide: "drop"
        case .kids: "star.circle"
        }
    }

    var isReady: Bool { true }

    @ViewBuilder var destination: some View {
        switch self {
        case .prayer: PrayerTimesView()
        case .qibla: QiblaView()
        case .hijri: HijriView()
        case .occasions: OccasionsView()
        case .zakat: ZakatView()
        case .mosques: MosquesView()
        case .azkar: AzkarView()
        case .tasbih: TasbihView()
        case .qada: QadaView()
        case .duas: DuasView()
        case .hadith: HadithView()
        case .hadithChecker: HadithCheckerView()
        case .prayerGuide: PrayerGuideView()
        case .kids: KidsJuzAmmaView()
        case .sawm: SawmView()
        default: PlaceholderScreen(title: title)
        }
    }

    static let today: [ToolItem] = [.azkar, .tasbih, .duas]
    static let worship: [ToolItem] = [.hijri, .zakat, .qada, .sawm, .mosques, .hadith]
}

/// Tools tab, per design/Tools.dc.html.
struct ToolsView: View {
    @State private var query = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if query.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        NextPrayerCard()
                        // Side by side, or stacked at accessibility text sizes so no word breaks.
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                                 count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                            NavigationLink { LibraryView() } label: { ToolCard("مكتبتي", subtitle: "المشاريع والمفضلة والتنزيلات", symbol: "books.vertical") }
                            NavigationLink { SettingsView() } label: { ToolCard("الإعدادات", subtitle: "القارئ والخط والتنبيهات", symbol: "gearshape") }
                        }
                        .buttonStyle(.plain)
                        section("اليوم", ToolItem.today)
                        section("العبادات والحساب", ToolItem.worship)
                        NavigationLink {
                            AllToolsView()
                        } label: {
                            Text("كل الأدوات (\(Num.int(ToolItem.allCases.count)))")
                                .font(.ui(.headline)).foregroundStyle(Brand.primaryInk)
                                .frame(maxWidth: .infinity, minHeight: Brand.minTap)
                        }
                    }
                    .padding(Brand.Space.l)
                    .frame(maxWidth: Brand.readableWidth)
                    .frame(maxWidth: .infinity)
                }
            } else {
                List(results) { item in
Group {
                    NavigationLink { item.destination } label: { ToolRow(item: item) }
                
}.listRowBackground(Brand.surface)
}
                .overlay { if results.isEmpty { ContentUnavailableView.search(text: query) } }
            }
        }
        .brandScreen()
        .navigationTitle("المزيد")
        .searchable(text: $query, prompt: "ابحث عن أداة")
    }

    private var results: [ToolItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return ToolItem.allCases.filter { $0.title.localizedStandardContains(q) }
    }

    private func section(_ title: String, _ items: [ToolItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.ui(.headline))
            // One column at accessibility text sizes so titles are never cut off.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                     count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
                ForEach(items) { item in
                    NavigationLink { item.destination } label: { ToolTile(item: item) }
                        .buttonStyle(.pressable)
                }
            }
        }
    }
}

struct ToolTile: View {
    let item: ToolItem
    var body: some View {
        LauncherTile(item.title, symbol: item.symbol)
    }
}

struct ToolRow: View {
    let item: ToolItem
    var body: some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if !item.isReady { Text("قيد البناء").font(.ui(.caption)).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: item.symbol).foregroundStyle(Brand.primary)
        }
        .frame(minHeight: Brand.minTap)
    }
}

struct AllToolsView: View {
    var body: some View {
        List(ToolItem.allCases) { item in
Group {
            NavigationLink { item.destination } label: { ToolRow(item: item) }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("كل الأدوات")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "Next prayer" card at the top of the Tools tab, with a shortcut to the qibla.
struct NextPrayerCard: View {
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name

    var body: some View {
        let city = PrayerCity.named(cityName) ?? PrayerCity.all[0]
        let place = PrayerTimesView.Place(name: city.name, lat: city.lat, lng: city.lng,
                                          zone: TimeZone(identifier: city.zone) ?? .current, method: city.method)
        TimelineView(.everyMinute) { ctx in
            let d = PrayerTimesView.Day(place: place, now: ctx.date)
            let t = d.next.isTomorrow ? d.tomorrow.fajr : d.today.hours(d.next.prayer)
            HStack(spacing: 12) {
                NavigationLink { PrayerTimesView() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("الصلاة القادمة").font(.ui(.footnote)).foregroundStyle(.secondary)
                        Text("\(d.next.prayer.name) · \(Num.time(t))").font(.ui(.title2, .semibold))
                            .foregroundStyle(Brand.primaryInk)
                        Text("\(place.name) · بعد \(Num.duration(minutes: d.next.minutesUntil))")
                            .font(.ui(.footnote)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                NavigationLink { QiblaView() } label: {
                    Image(systemName: "location.north.line.fill")
                        .font(.ui(.title3)).foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Brand.primary, in: Circle())
                }
                .accessibilityLabel("القبلة")
            }
            .padding(16)
            .background(Brand.tint, in: RoundedRectangle(cornerRadius: Brand.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: Brand.radiusCard).stroke(Brand.line, lineWidth: 1))
        }
    }
}
