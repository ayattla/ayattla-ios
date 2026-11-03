import SwiftUI
import AyatDesign
import AyatCalc

/// Hijri ⇄ Gregorian on Umm al-Qura, like ayattla.com/tools/hijri.
struct HijriView: View {
    enum Direction: String, CaseIterable, Identifiable {
        case toHijri, toGregorian
        var id: String { rawValue }
        var title: String { self == .toHijri ? "ميلادي إلى هجري" : "هجري إلى ميلادي" }
    }

    @State private var direction = Direction.toHijri
    @State private var gregorian = Date()
    @State private var hYear = Hijri.fromGregorian(Date()).year
    @State private var hMonth = Hijri.fromGregorian(Date()).month
    @State private var hDay = Hijri.fromGregorian(Date()).day

    var body: some View {
        Form {
Group {
            Section {
                Text(Num.hijri(Date()))
                    .font(.ui(.title2, .semibold))
                    .foregroundStyle(Brand.primaryInk)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("اليوم \(Num.hijri(Date()))")
            } header: { Text("اليوم") }

            Section {
                Picker("اتجاه التحويل", selection: $direction) {
                    ForEach(Direction.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            switch direction {
            case .toHijri:
                Section("التاريخ الميلادي") {
                    DatePicker("التاريخ", selection: $gregorian, displayedComponents: .date)
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                }
                Section("النتيجة") { result(Num.hijri(gregorian)) }
            case .toGregorian:
                Section("التاريخ الهجري") {
                    Picker("الشهر", selection: $hMonth) {
                        ForEach(1...12, id: \.self) { Text(Hijri.months[$0 - 1]).tag($0) }
                    }
                    Stepper("اليوم: \(Num.int(hDay))", value: $hDay, in: 1...30)
                    Stepper("السنة: \(Num.int(hYear))", value: $hYear, in: 1300...1500)
                }
                Section("النتيجة") {
                    if let g = Hijri.toGregorianExact(.init(year: hYear, month: hMonth, day: hDay)) {
                        result(Self.gregorianText(g))
                    } else {
                        Text("هذا الشهر \(Num.int(29)) يوما فقط").foregroundStyle(.secondary)
                    }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("التاريخ الهجري")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func result(_ text: String) -> some View {
        HStack {
            Text(text).font(.ui(.headline))
            Spacer()
            Button { UIPasteboard.general.string = text } label: { Image(systemName: "doc.on.doc") }
                .accessibilityLabel("نسخ النتيجة")
                .frame(minWidth: Brand.minTap, minHeight: Brand.minTap)
        }
    }

    static func gregorianText(_ d: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Num.locale
        return d.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Num.locale, calendar: cal,
                                            timeZone: cal.timeZone)) + " م"
    }
}

/// Countdown to Ramadan, the two Eids and Arafah, like ayattla.com/tools/occasions.
struct OccasionsView: View {
    var body: some View {
        TimelineView(.everyMinute) { ctx in
            List(Occasion.upcoming(from: ctx.date), id: \.occasion) { u in
Group {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(u.occasion.name).font(.ui(.headline))
                        Text("\(Num.int(u.hijri.day)) \(Hijri.months[u.hijri.month - 1]) \(Num.int(u.hijri.year)) هـ · \(HijriView.gregorianText(u.gregorian))")
                            .font(.ui(.footnote)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Self.countdown(u.days))
                        .font(.ui(.headline)).foregroundStyle(Brand.primaryInk)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            
}.listRowBackground(Brand.surface)
}
        }
        .brandScreen()
        .navigationTitle("المناسبات")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func countdown(_ days: Int) -> String {
        if days == 0 { return "اليوم" }
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day]
        f.unitsStyle = .full
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Num.locale
        f.calendar = cal
        return "بعد " + (f.string(from: TimeInterval(days * 86_400)) ?? Num.int(days))
    }
}
