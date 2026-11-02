import SwiftUI
import AyatDesign
import AyatCalc

/// Every tool of the Tools tab (docs/APP_ARCHITECTURE.md §1). Tools that depend on the content
/// pack or on behaviour not yet confirmed on the site show a placeholder until they are built.
enum ToolItem: String, CaseIterable, Identifiable {
    case azkar, tasbih, duas, prayer, qibla, hijri, occasions, zakat, qada, sawm, mosques, hadith, hadithChecker, prayerGuide
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
        }
    }

    var isReady: Bool { [.prayer, .qibla, .hijri, .occasions, .zakat, .mosques].contains(self) }

    @ViewBuilder var destination: some View {
        switch self {
        case .prayer: PrayerTimesView()
        case .qibla: QiblaView()
        case .hijri: HijriView()
        case .occasions: OccasionsView()
        case .zakat: ZakatView()
        case .mosques: MosquesView()
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
                        section("اليوم", ToolItem.today)
                        section("العبادات والحساب", ToolItem.worship)
                        NavigationLink {
                            AllToolsView()
                        } label: {
                            Text("كل الأدوات (\(Num.int(ToolItem.allCases.count)))")
                                .font(.headline).foregroundStyle(Brand.primaryInk)
                                .frame(maxWidth: .infinity, minHeight: Brand.minTap)
                        }
                    }
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                List(results) { item in
                    NavigationLink { item.destination } label: { ToolRow(item: item) }
                }
                .overlay { if results.isEmpty { ContentUnavailableView.search(text: query) } }
            }
        }
        .navigationTitle("الأدوات")
        .searchable(text: $query, prompt: "ابحث عن أداة")
    }

    private var results: [ToolItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return ToolItem.allCases.filter { $0.title.localizedStandardContains(q) }
    }

    private func section(_ title: String, _ items: [ToolItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            // One column at accessibility text sizes so titles are never cut off.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                     count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
                ForEach(items) { item in
                    NavigationLink { item.destination } label: { ToolTile(item: item) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ToolTile: View {
    let item: ToolItem
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.symbol).font(.title3)
                .foregroundStyle(item.isReady ? Brand.primary : Brand.muted)
            Text(item.title).font(.subheadline).multilineTextAlignment(.center).lineLimit(2)
                .foregroundStyle(.primary)
            if !item.isReady {
                Text("قريبا").font(.caption2).foregroundStyle(Brand.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .padding(.horizontal, 6)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(item.isReady ? String() : String("قيد البناء")))
    }
}

struct ToolRow: View {
    let item: ToolItem
    var body: some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if !item.isReady { Text("قيد البناء").font(.caption).foregroundStyle(.secondary) }
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
            NavigationLink { item.destination } label: { ToolRow(item: item) }
        }
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
                        Text("الصلاة القادمة").font(.footnote).foregroundStyle(.secondary)
                        Text("\(d.next.prayer.name) · \(Num.time(t))").font(.title2.weight(.semibold))
                            .foregroundStyle(Brand.primaryInk)
                        Text("\(place.name) · بعد \(Num.duration(minutes: d.next.minutesUntil))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                NavigationLink { QiblaView() } label: {
                    Image(systemName: "location.north.line.fill")
                        .font(.title3).foregroundStyle(.white)
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

struct ZakatView: View {
    @State private var input = Zakat.Input()

    var body: some View {
        let r = Zakat.calculate(input)
        Form {
            Section {
                Picker("النصاب على أساس", selection: $input.basis) {
                    Text("الذهب").tag(Zakat.Basis.gold)
                    Text("الفضة").tag(Zakat.Basis.silver)
                }
                field("سعر غرام الذهب عيار ٢٤", $input.goldPricePerGram24)
                field("سعر غرام الفضة", $input.silverPricePerGram)
            }
            Section("الأموال") {
                field("النقد والأرصدة البنكية", $input.cash)
                field("قيمة عروض التجارة", $input.trade)
                field("ذهب عيار ٢٤ (غرام)", $input.gold24)
                field("ذهب عيار ٢١ (غرام)", $input.gold21)
                field("ذهب عيار ١٨ (غرام)", $input.gold18)
                field("فضة (غرام)", $input.silverGrams)
                field("ديون لك مرجوة السداد", $input.receivables)
                field("ديون عليك حالة الآن", $input.debts)
            }
            Section("النتيجة") {
                LabeledContent("صافي المال الزكوي", value: r.total.formatted())
                LabeledContent("النصاب", value: r.nisab > 0 ? r.nisab.formatted() : "أدخل السعر")
                LabeledContent("الزكاة الواجبة", value: r.due.formatted())
                    .font(.headline)
            }
        }
        .navigationTitle("حاسبة الزكاة")
    }

    private func field(_ title: String, _ value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField("٠", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
        }
    }
}
