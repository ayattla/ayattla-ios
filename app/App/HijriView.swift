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
            ToolHeadSection(id: "hijri")
Group {
            Section {
                Text(Num.hijri(Date()))
                    .font(.ui(.title2, .semibold))
                    .foregroundStyle(Brand.primaryInk)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("اليوم \(Num.hijri(Date()))")
            } header: { Text("اليوم") }

            Section { HijriMonthGrid(month: Hijri.fromGregorian(Date())) } header: { Text("الشهر الهجري") }

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
            List {
                ToolHeadSection(id: "occasions")
                ForEach(Occasion.upcoming(from: ctx.date), id: \.occasion) { u in
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


/// The Hijri month as a calendar (Saturday first): Gregorian day under each Hijri day, today and the white days (13–15) marked.
struct HijriMonthGrid: View {
    let month: Hijri.Date

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    var body: some View {
        let first = Hijri.toGregorian(Hijri.Date(year: month.year, month: month.month, day: 1)) ?? Date()
        let next = Hijri.toGregorian(Hijri.Date(year: month.month == 12 ? month.year + 1 : month.year, month: month.month == 12 ? 1 : month.month + 1, day: 1))
        let len = next.map { cal.dateComponents([.day], from: first, to: $0).day ?? 30 } ?? 30
        let weekday = cal.component(.weekday, from: first)   // 1 = Sunday … 7 = Saturday
        let lead = weekday % 7                                // Saturday first
        let cells: [Int?] = Array(repeating: nil, count: lead) + (1...max(1, len)).map { Optional($0) }
        let today = Hijri.fromGregorian(Date())
        VStack(spacing: 6) {
            Text("\(Hijri.months[month.month - 1]) \(Num.int(month.year))").font(.ui(.headline)).foregroundStyle(Brand.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(["سبت", "أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة"], id: \.self) {
                    Text($0).font(.ui(.caption2, .semibold)).foregroundStyle(Brand.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                    if let d {
                        let g = cal.date(byAdding: .day, value: d - 1, to: first) ?? first
                        let isToday = today.year == month.year && today.month == month.month && today.day == d
                        VStack(spacing: 1) {
                            Text(Num.int(d)).font(.ui(.subheadline, .semibold)).foregroundStyle(isToday ? .white : Brand.ink)
                            Text(Num.int(cal.component(.day, from: g))).font(.ui(.caption2)).foregroundStyle(isToday ? .white.opacity(0.85) : Brand.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isToday ? Brand.green : (13...15).contains(d) ? Brand.goldSoft : Brand.surface2,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityElement(children: .combine)
                    } else {
                        Color.clear.frame(minHeight: 44)
                    }
                }
            }
            Text("الأيام البيض ١٣–١٥ مظللة بالذهبي").font(.ui(.caption2)).foregroundStyle(Brand.muted)
        }
        .padding(.vertical, 6)
    }
}
