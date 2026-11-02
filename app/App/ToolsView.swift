import SwiftUI
import AyatCalc
import CoreLocation

// STATUS: first real feature screens (qibla and zakat) on top of AyatCalc; not compiled yet.
struct ToolsView: View {
    var body: some View {
        List {
            Section("العبادات والحساب") {
                NavigationLink("حاسبة الزكاة") { ZakatView() }
                NavigationLink("التاريخ الهجري") { HijriTodayView() }
            }
        }
        .navigationTitle("الأدوات")
    }
}

struct HijriTodayView: View {
    var body: some View {
        let h = Hijri.fromGregorian(Date())
        VStack(spacing: 8) {
            Text("\(h.day.formatted(.number.locale(Locale(identifier: "ar")))) \(Hijri.months[h.month - 1]) \(h.year.formatted(.number.grouping(.never).locale(Locale(identifier: "ar")))) هـ")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Brand.primaryInk)
        }
        .navigationTitle("التاريخ الهجري")
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
