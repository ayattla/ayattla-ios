import SwiftUI
import AyatDesign
import AyatCalc
import AyatContent

/// «يومي»: one clear step for this part of the day, chosen by the real prayer times. A strip of five
/// marks shows the day at a glance; a finished step says so and names what comes next.
/// Same slots, wording and rules as the Android card.
struct HomeDaily: View {
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name
    @State private var hadith: SiteAPI.Hadith?
    @State private var tick = 0

    var body: some View {
        let city = PrayerCity.named(cityName) ?? PrayerCity.all[0]
        let place = PrayerTimesView.Place(name: city.name, lat: city.lat, lng: city.lng,
                                          zone: TimeZone(identifier: city.zone) ?? .current, method: city.method)
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let d = PrayerTimesView.Day(place: place, now: ctx.date)
            let minute = Self.minuteOfDay(ctx.date, zone: place.zone)
            let slot = TodayPlan.slot(minute: minute, times: d.today)
            let back = TodayPlan.daysBack(minute: minute, times: d.today)
            let dayNum = Journey.dayNumber() - back
            let dayDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -back, to: ctx.date) ?? ctx.date
            let all = Dictionary(uniqueKeysWithValues: TodaySlot.allCases.map { ($0, progress($0, dayNum: dayNum, dayDate: dayDate)) })
            card(slot: slot, all: all, dayNum: dayNum)
                .id(tick)
                .task(id: slot) {
                    guard slot == .hadith, hadith == nil else { return }
                    if let page = try? await SiteAPI.hadith(cat: "", page: 1, query: "", preferNetwork: false) {
                        hadith = TodayPlan.pick(page.items, dayNumber: dayNum)
                    }
                }
        }
        .onAppear { tick += 1 }   // counters are read again when the user comes back from a step
    }

    // MARK: - Card

    @ViewBuilder private func card(slot: TodaySlot, all: [TodaySlot: Double], dayNum: Int) -> some View {
        let frac = all[slot] ?? 0
        let done = frac >= 1
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("يومي · بعد \(slot.after.name)")
                    .font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Brand.tint, in: Capsule())
                Spacer()
                HStack(spacing: 5) {
                    ForEach(TodaySlot.allCases) { s in
                        let full = (all[s] ?? 0) >= 1
                        Circle()
                            .fill(full ? Brand.green : (s == slot ? Brand.surface : Brand.surface2))
                            .overlay { if s == slot && !full { Circle().strokeBorder(Brand.green, lineWidth: 2) } }
                            .frame(width: s == slot ? 10 : 8, height: s == slot ? 10 : 8)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("أتممت \(all.values.filter { $0 >= 1 }.count) من خمس خطوات اليوم")
            }

            HStack(spacing: 12) {
                IconTile(Self.symbol(slot), style: .gradient(TodaySlot.allCases.firstIndex(of: slot) ?? 0), size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title).font(.ui(.title3, .bold)).foregroundStyle(Brand.ink)
                    Text(done ? "أحسنت، أتممتها اليوم" : slot.line).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                }
                Spacer(minLength: 0)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(Brand.green, in: Circle())
                        .accessibilityLabel("تمت")
                }
            }

            if slot == .hadith, let h = hadith {
                VStack(alignment: .leading, spacing: 8) {
                    Text(h.text).font(.ui(.body)).foregroundStyle(Brand.ink).lineLimit(4).lineSpacing(6)
                    // «موثق»: the source and grade, and a tap shows where every text comes from.
                    NavigationLink { LicensesView() } label: {
                        Label([h.source, h.grade].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "checkmark.seal")
                            .font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk).lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("موثق: \(h.source)")
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if slot != .hadith && !done && frac > 0 {
                ProgressView(value: frac).tint(Brand.green)
            }

            HStack(spacing: 10) {
                if done {
                    Text("التالي بعد \(slot.next.after.name): \(slot.next.title)")
                        .font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    Spacer(minLength: 0)
                    NavigationLink { destination(slot, dayNum: dayNum) } label: { Text("افتح") }
                        .buttonStyle(.brandSecondary).fixedSize()
                } else {
                    NavigationLink { destination(slot, dayNum: dayNum) } label: {
                        Text(slot == .night ? "سورة الملك" : slot == .hadith ? "اقرأ المزيد" : (frac > 0 ? "تابع" : "ابدأ"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brandPrimary)
                    if slot == .night {
                        NavigationLink {
                            Route.azkar("أذكار النوم").destination.onAppear { Stats.event("today_opened", "sleep") }
                        } label: { Text("أذكار النوم").frame(maxWidth: .infinity) }
                        .buttonStyle(.brandSecondary)
                    }
                    if slot == .hadith, let h = hadith {
                        NavigationLink {
                            TextCardView(title: "بطاقة حديث", text: h.text,
                                         reference: [h.source, h.grade].filter { !$0.isEmpty }.joined(separator: " · "))
                                .onAppear { Stats.event("today_shared", slot.rawValue) }
                        } label: { Label("شارك", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.brandSecondary).fixedSize()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.raised, radius: 18)
        .animation(.easeOut(duration: 0.22), value: slot)
    }

    @ViewBuilder private func destination(_ s: TodaySlot, dayNum: Int) -> some View {
        Group {
            switch s {
            case .morning: Route.azkar("أذكار الصباح").destination
            case .evening: Route.azkar("أذكار المساء").destination
            case .wird: JourneyView()
            case .hadith: HadithView()
            case .night: Route.ayah(surah: 67, ayah: 1).destination
            }
        }
        .onAppear {
            Stats.event("today_opened", s.rawValue)
            if s == .hadith || s == .night { Self.markOpened(dayNum, s) }
        }
    }

    // MARK: - Progress

    private func progress(_ s: TodaySlot, dayNum: Int, dayDate: Date) -> Double {
        func azkar(_ word: String) -> Double {
            guard let c = ContentLibrary.shared.azkarCategories.first(where: { $0.title == "أذكار \(word)" })
                    ?? ContentLibrary.shared.azkarCategories.first(where: { $0.title.contains(word) }) else { return 0 }
            return AzkarLog.fraction(c.title, on: dayDate)
        }
        switch s {
        case .morning: return azkar("الصباح")
        case .evening: return azkar("المساء")
        case .wird:
            let j = Journey.shared
            return min(1, Double(j.day(dayNum).pages.count) / Double(max(j.goal, 1)))
        case .hadith: return Self.opened(dayNum, s) ? 1 : 0
        case .night: return max(azkar("النوم"), Self.opened(dayNum, s) ? 1 : 0)
        }
    }

    // Steps with no counter of their own (the hadith, Surat al-Mulk) are marked when opened.
    static func markOpened(_ day: Int, _ s: TodaySlot) { UserDefaults.standard.set(true, forKey: "today.\(day).\(s.rawValue)") }
    static func opened(_ day: Int, _ s: TodaySlot) -> Bool { UserDefaults.standard.bool(forKey: "today.\(day).\(s.rawValue)") }

    static func minuteOfDay(_ d: Date, zone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let c = cal.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func symbol(_ s: TodaySlot) -> String {
        switch s {
        case .morning: "sun.max"
        case .wird: "book"
        case .evening: "moon.stars"
        case .hadith: "text.book.closed"
        case .night: "bed.double"
        }
    }
}
