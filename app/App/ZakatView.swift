import SwiftUI
import AyatDesign
import AyatCalc

/// Zakat calculator, matching ayattla.com/tools/zakat: same fields and labels, currency list,
/// entries kept on the device (the site keeps them in localStorage "zk"), a status line and a
/// breakdown that lists only the non-zero amounts. The arithmetic is `Zakat.calculate` (AyatCalc).
struct ZakatView: View {
    @AppStorage("zakat.form") private var stored = ""
    @State private var form = ZakatForm()
    @State private var loaded = false

    var body: some View {
        let r = Zakat.calculate(form.input)
        let summary = ZakatSummary(form: form, result: r)
        Form {
            ToolHeadSection(id: "zakat")
Group {
            Section {
                Picker("العملة", selection: $form.currency) {
                    ForEach(ZakatForm.currencies, id: \.self) { Text($0).tag($0) }
                }
                Picker("النصاب على أساس", selection: $form.basis) {
                    Text("الذهب (٨٥ غراما)").tag(Zakat.Basis.gold.rawValue)
                    Text("الفضة (٥٩٥ غراما)").tag(Zakat.Basis.silver.rawValue)
                }
                field("سعر غرام الذهب عيار ٢٤", $form.goldPrice)
                field("سعر غرام الفضة", $form.silverPrice)
            }
            Section("أموالك التي حال عليها الحول") {
                field("النقد والأرصدة البنكية", $form.cash)
                field("قيمة عروض التجارة (البضائع)", $form.trade)
                field("ذهب عيار ٢٤ (غرام)", $form.gold24)
                field("عيار ٢١ (غرام)", $form.gold21)
                field("عيار ١٨ (غرام)", $form.gold18)
                field("فضة (غرام)", $form.silverGrams)
                field("ديون لك مرجوة السداد", $form.receivables)
                field("ديون عليك حالة الآن", $form.debts)
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("الزكاة الواجبة").font(.ui(.subheadline)).foregroundStyle(.secondary)
                    Text(summary.due).font(.ui(.largeTitle, .semibold)).foregroundStyle(Brand.primaryInk)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(summary.status).font(.ui(.subheadline))
                        .foregroundStyle(summary.reached ? Brand.primaryInk : .secondary)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
                ForEach(summary.lines, id: \.label) { line in
                    LabeledContent(line.label, value: line.value)
                }
                LabeledContent("صافي المال الزكوي", value: summary.net).fontWeight(.semibold)
                LabeledContent("النصاب", value: summary.nisab)
            } footer: {
                Text("الزكاة ربع العشر (٢٫٥٪) إذا بلغ المال النصاب وحال عليه حول هجري. في زكاة الحلي المستعملة خلاف بين العلماء، والحالات الخاصة يسأل عنها أهل العلم.")
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("حاسبة الزكاة")
        .onAppear {
            if !loaded { form = ZakatForm.decode(stored); loaded = true }
        }
        .onChange(of: form) { _, f in stored = f.encoded() }
    }

    private func field(_ title: String, _ value: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("٠", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 140)
        }
    }
}

/// The form exactly as typed (empty stays empty, like the site's inputs), saved as JSON.
struct ZakatForm: Codable, Equatable {
    static let currencies = ["ريال", "درهم", "دينار", "جنيه", "دولار", "ليرة"]

    var currency = "ريال"
    var basis = Zakat.Basis.gold.rawValue
    var goldPrice = "", silverPrice = ""
    var cash = "", trade = "", gold24 = "", gold21 = "", gold18 = "", silverGrams = ""
    var receivables = "", debts = ""

    /// Accepts Arabic-Indic digits and the Arabic decimal separator as typed on an Arabic keyboard.
    static func number(_ s: String) -> Double {
        var t = ""
        for c in s {
            if let v = c.wholeNumberValue { t.append(String(v)) }
            else if c == "." || c == "٫" { t.append(".") }   // grouping commas are ignored
        }
        return Double(t) ?? 0
    }

    var input: Zakat.Input {
        var i = Zakat.Input()
        i.basis = Zakat.Basis(rawValue: basis) ?? .gold
        i.goldPricePerGram24 = Self.number(goldPrice)
        i.silverPricePerGram = Self.number(silverPrice)
        i.cash = Self.number(cash); i.trade = Self.number(trade)
        i.gold24 = Self.number(gold24); i.gold21 = Self.number(gold21); i.gold18 = Self.number(gold18)
        i.silverGrams = Self.number(silverGrams)
        i.receivables = Self.number(receivables); i.debts = Self.number(debts)
        return i
    }

    func encoded() -> String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "" }
    static func decode(_ s: String) -> ZakatForm {
        (try? JSONDecoder().decode(ZakatForm.self, from: Data(s.utf8))) ?? ZakatForm()
    }
}

/// Texts of the result box, as the site writes them.
struct ZakatSummary {
    struct Line { let label: String; let value: String }

    let due: String
    let status: String
    let reached: Bool
    let lines: [Line]
    let net: String
    let nisab: String

    init(form: ZakatForm, result r: Zakat.Result) {
        let cur = form.currency
        let i = form.input
        func m(_ x: Double) -> String { "\(Self.money(x)) \(cur)" }
        var lines: [Line] = []
        if i.cash != 0 { lines.append(.init(label: "النقد والأرصدة", value: m(i.cash))) }
        if i.trade != 0 { lines.append(.init(label: "عروض التجارة", value: m(i.trade))) }
        if r.goldValue != 0 { lines.append(.init(label: "قيمة الذهب", value: m(r.goldValue))) }
        if r.silverValue != 0 { lines.append(.init(label: "قيمة الفضة", value: m(r.silverValue))) }
        if i.receivables != 0 { lines.append(.init(label: "ديون لك", value: m(i.receivables))) }
        if i.debts != 0 { lines.append(.init(label: "يخصم: ديون عليك", value: m(-i.debts))) }
        self.lines = lines
        net = m(r.total)
        reached = r.reachedNisab
        if r.nisab <= 0 {
            due = "—"
            status = i.basis == .silver ? "أدخل سعر غرام الفضة لحساب النصاب" : "أدخل سعر غرام الذهب لحساب النصاب"
            nisab = "أدخل السعر"
        } else {
            nisab = m(r.nisab)
            if r.reachedNisab {
                due = m(r.due)
                status = "بلغ مالك النصاب"
            } else {
                due = Self.money(0)
                status = "لم يبلغ النصاب — بقي \(m(r.nisab - r.total))"
            }
        }
    }

    /// The site's `toLocaleString('en-US', {maximumFractionDigits: 2})` with Arabic-Indic digits:
    /// "٢,٤٩٠.٦٣".
    static func money(_ x: Double) -> String {
        Num.digits(moneyFormatter.string(from: NSNumber(value: x)) ?? "0")
    }

    /// Built once; recalculating used to create a formatter for every figure on screen.
    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.roundingMode = .halfUp   // JS toLocaleString rounds half away from zero (2490.625 → .63)
        f.minimumFractionDigits = 0
        return f
    }()
}
