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
                content(Day(place: place, now: ctx.date))
                    .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
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
            func times(_ d: Date) -> PrayerTimes {
                let c = cal.dateComponents([.year, .month, .day], from: d)
                return PrayerTimes.compute(year: c.year!, month: c.month!, day: c.day!, lat: place.lat, lng: place.lng,
                                           tzHours: PrayerTimes.tzHours(place.zone, at: d), method: place.method,
                                           ramadan: ramadan)
            }
            today = times(now)
            tomorrow = times(cal.date(byAdding: .day, value: 1, to: now) ?? now)
            let hm = cal.dateComponents([.hour, .minute], from: now)
            next = PrayerTimes.next(after: hm.hour! * 60 + hm.minute!, today: today, tomorrow: tomorrow)
        }
    }

    @ViewBuilder private func content(_ d: Day) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("\(d.place.name) · \(Num.hijri(d.now))").font(.footnote).opacity(0.9)
                Text("الصلاة القادمة").font(.subheadline)
                Text("\(d.next.prayer.name) \(nextTime(d))")
                    .font(.system(size: 34, weight: .semibold))
                    .minimumScaleFactor(0.6)
                Text("بعد \(Num.duration(minutes: d.next.minutesUntil))").font(.subheadline).opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(LinearGradient(colors: [Brand.g0, Brand.primary], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                ForEach(Prayer.allCases) { p in
                    let isNext = !d.next.isTomorrow && p == d.next.prayer
                    HStack {
                        Text(p.name).fontWeight(isNext ? .semibold : .regular)
                        Spacer()
                        Text(Num.time(d.today.hours(p)))
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

            HStack {
                Text("طريقة الحساب")
                Spacer()
                Text(methodLabel(d.place.method)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .card()

            Text("تحسب على الجهاز دون إنترنت").font(.footnote).foregroundStyle(.secondary)
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
                Section {
                    Toggle("استخدم موقعي", isOn: $useLocation)
                        .onChange(of: useLocation) { _, on in if on { location.requestLocation() } }
                    if useLocation && (location.failed || location.denied) {
                        Text("تعذر تحديد الموقع، فتستخدم المدينة المختارة. يمكنك السماح بالموقع من إعدادات الجهاز.")
                            .font(.footnote).foregroundStyle(.secondary)
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
            }
            .navigationTitle("إعدادات المواقيت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { showSettings = false } } }
        }
    }
}
