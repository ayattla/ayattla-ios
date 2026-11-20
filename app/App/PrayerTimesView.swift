import SwiftUI
import AyatDesign
import AyatCalc

/// Prayer times, per design/Prayer.dc.html. Computed on the device with the site's formulas.
struct PrayerTimesView: View {
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name
    @AppStorage("prayer.useLocation") private var useLocation = false
    @State private var location = LocationService()
    @State private var showSettings = false

    struct Place {
        let name: String
        let lat: Double, lng: Double
        let zone: TimeZone
        let method: PrayerTimes.Method
    }

    private var city: PrayerCity { PrayerCity.named(cityName) ?? PrayerCity.all[0] }

    private var place: Place {
        if useLocation, let c = location.coordinate {
            return Place(name: "موقعي", lat: c.latitude, lng: c.longitude, zone: .current,
                         method: .forLocation(lat: c.latitude, lng: c.longitude))
        }
        return Place(name: city.name, lat: city.lat, lng: city.lng,
                     zone: TimeZone(identifier: city.zone) ?? .current, method: city.method)
    }

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            ScrollView {
                VStack(spacing: 16) {
                    ToolPageHead(id: "prayer-times")
                    content(Day(place: place, now: ctx.date))
                }
                .padding(16)
            }
        }
        .background(Brand.background)
        .brandScreen()
        .navigationTitle("مواقيت الصلاة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("الإعدادات")
            }
        }
        .sheet(isPresented: $showSettings) { settings }
        .onAppear { if useLocation { location.requestLocation() } }
    }

    /// Everything for one place and moment.
    struct Day {
        let place: Place
        let now: Date
        let today: PrayerTimes
        let tomorrow: PrayerTimes
        let next: PrayerTimes.Next

        init(place: Place, now: Date) {
            self.place = place
            self.now = now
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = place.zone
            let ramadan = Hijri.isRamadan(now)
            _ = ramadan
            // The user's method, Asr school and minute adjustments (حساب المواقيت) apply everywhere.
            func times(_ d: Date) -> PrayerTimes {
                PrayerCalc.times(on: d, lat: place.lat, lng: place.lng, zone: place.zone, method: place.method)
            }
            today = times(now)
            tomorrow = times(cal.date(byAdding: .day, value: 1, to: now) ?? now)
            let hm = cal.dateComponents([.hour, .minute], from: now)
            next = PrayerTimes.next(after: hm.hour! * 60 + hm.minute!, today: today, tomorrow: tomorrow)
        }
    }

    /// Midnight and the last third of the night (between Maghrib and the next Fajr), and the length of the fast.
    private func nightCard(_ d: Day) -> some View {
        let night = d.tomorrow.fajr + 24 - d.today.maghrib
        let items: [(String, String)] = [
            ("منتصف الليل", Num.time((d.today.maghrib + night / 2).truncatingRemainder(dividingBy: 24))),
            ("الثلث الأخير", Num.time((d.today.maghrib + night * 2 / 3).truncatingRemainder(dividingBy: 24))),
            ("مدة الصيام", Num.duration(minutes: Int(((d.today.maghrib - d.today.fajr) * 60).rounded()))),
        ]
        return VStack(spacing: 10) {
            Text("الليل والنهار").font(.ui(.headline)).foregroundStyle(Brand.ink)
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { t, v in
                    VStack(spacing: 4) {
                        Text(t).font(.ui(.caption)).foregroundStyle(Brand.muted)
                        Text(v).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).minimumScaleFactor(0.7).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14).card()
    }

    /// The week ahead at a glance.
    private func weekCard(_ d: Day) -> some View {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = d.place.zone
        let five = Prayer.allCases.filter(\.isPrayer)
        let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "EEE d"; f.timeZone = d.place.zone
        return VStack(spacing: 6) {
            Text("مواقيت الأسبوع").font(.ui(.headline)).foregroundStyle(Brand.ink)
            HStack(spacing: 2) {
                Text("اليوم").frame(maxWidth: .infinity)
                ForEach(five) { Text($0.name).frame(maxWidth: .infinity) }
            }
            .font(.ui(.caption2, .semibold)).foregroundStyle(Brand.muted)
            ForEach(0..<7, id: \.self) { i in
                let date = cal.date(byAdding: .day, value: i, to: d.now) ?? d.now
                let t = Day(place: d.place, now: date).today
                HStack(spacing: 2) {
                    Text(f.string(from: date)).frame(maxWidth: .infinity)
                    ForEach(five) { p in Text(Num.time(t.hours(p))).frame(maxWidth: .infinity) }
                }
                .font(.ui(.caption2)).foregroundStyle(Brand.ink).lineLimit(1).minimumScaleFactor(0.6)
                .padding(.vertical, 7)
                .background(i == 0 ? Brand.tint : .clear, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14).card()
    }

    @ViewBuilder private func content(_ d: Day) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("\(d.place.name) · \(Num.hijri(d.now))").font(.ui(.footnote)).opacity(0.9)
                Text("الصلاة القادمة").font(.ui(.subheadline))
                Text("\(d.next.prayer.name) \(nextTime(d))")
                    .font(.ui(size: 34, .semibold))
                    .minimumScaleFactor(0.6)
                Text("بعد \(Num.duration(minutes: d.next.minutesUntil))").font(.ui(.subheadline)).opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Brand.gradient,
                        in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)

            if d.next.isTomorrow {
                Text("مواقيت الغد").font(.ui(.subheadline, .semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                let shown = d.next.isTomorrow ? d.tomorrow : d.today
                ForEach(Prayer.allCases) { p in
                    let isNext = p == d.next.prayer
                    HStack {
                        Text(p.name).fontWeight(isNext ? .semibold : .regular)
                        Spacer()
                        Text(Num.time(shown.hours(p)))
                            .foregroundStyle(isNext ? Brand.primaryInk : .secondary)
                            .fontWeight(isNext ? .semibold : .regular)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 58)
                    .background(isNext ? Brand.tint : Color.clear)
                    .accessibilityElement(children: .combine)
                    if p != .isha { Divider().overlay(Brand.line) }
                }
            }
            .card()

            nightCard(d)
            weekCard(d)

            HStack {
                Text("طريقة الحساب")
                Spacer()
                Text(methodLabel(PrayerCalc.method(default: d.place.method))).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .card()

            HStack(spacing: 10) {
                NavigationLink { NotificationCenterView() } label: { Label("تنبيهات الصلاة", systemImage: "bell.badge").frame(maxWidth: .infinity) }
                NavigationLink { PrayerCalcView() } label: { Label("طريقة الحساب", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.bordered).tint(Brand.primaryInk)

            Text("تحسب على الجهاز دون إنترنت").font(.ui(.footnote)).foregroundStyle(.secondary)
        }
    }

    private func nextTime(_ d: Day) -> String {
        Num.time(d.next.isTomorrow ? d.tomorrow.fajr : d.today.hours(d.next.prayer))
    }

    private func methodLabel(_ m: PrayerTimes.Method) -> String {
        if m == .ummAlQura { return "أم القرى" }
        let isha = m.isha > 30 ? "العشاء بعد المغرب بـ\(Num.int(Int(m.isha))) دقيقة" : "العشاء \(Num.decimal(m.isha))°"
        return "الفجر \(Num.decimal(m.fajrAngle))° · \(isha)"
    }

    private var settings: some View {
        NavigationStack {
            Form {
Group {
                Section {
                    Toggle("استخدم موقعي", isOn: $useLocation)
                        .onChange(of: useLocation) { _, on in if on { location.requestLocation() } }
                    if useLocation && (location.failed || location.denied) {
                        Text("تعذر تحديد الموقع، فتستخدم المدينة المختارة. يمكنك السماح بالموقع من إعدادات الجهاز.")
                            .font(.ui(.footnote)).foregroundStyle(.secondary)
                    }
                }
                Section("المدينة") {
                    Picker("المدينة", selection: $cityName) {
                        ForEach(PrayerCity.all) { Text($0.name).tag($0.name) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .disabled(useLocation && location.coordinate != nil)
                }
            
}.listRowBackground(Brand.surface)
}
            .brandScreen()
            .navigationTitle("إعدادات المواقيت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { showSettings = false } } }
        }
    }
}
