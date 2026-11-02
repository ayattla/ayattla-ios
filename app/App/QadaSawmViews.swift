import SwiftUI
import AyatDesign
import AyatCalc

// MARK: - Qada of prayers (/tools/qada-salah)

/// Missed-prayer tracker, matching ayattla.com/tools/qada-salah: a count left per prayer,
/// «أضف للعداد» adds the missed days to every prayer (again and again), «قضيت واحدة» and «+» per
/// prayer, the daily pace 1/2/3/5 and the finishing estimate. Saved on the device only.
struct QadaState: Codable, Equatable {
    static let prayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
    struct Pace: Hashable { let value: Int; let title: String }
    static let paces: [Pace] = [.init(value: 1, title: "صلاة واحدة"), .init(value: 2, title: "صلاتان"),
                                .init(value: 3, title: "ثلاث صلوات"), .init(value: 5, title: "خمس صلوات")]

    var left: [Int] = [0, 0, 0, 0, 0]
    var done = 0
    var per = 1

    init() {}

    mutating func add(days: Int) { guard days > 0 else { return }; left = left.map { $0 + days } }
    mutating func makeUp(_ i: Int) { if left[i] > 0 { left[i] -= 1; done += 1 } }
    mutating func more(_ i: Int) { left[i] += 1 }

    var totalRemaining: Int { left.reduce(0, +) }
    /// Days to finish at `per` made-up prayers with each obligatory prayer (site: ceil(max / per)).
    var daysLeft: Int {
        let worst = left.max() ?? 0
        return worst == 0 ? 0 : (worst + per - 1) / per
    }

    var status: String { "المتبقي: \(Num.int(totalRemaining)) صلاة — تم قضاء: \(Num.int(done))" }
    var plan: String? {
        daysLeft > 0 ? "بقضاء \(Num.int(per)) مع كل فرض تنتهي خلال نحو \(Num.int(daysLeft)) يوما بإذن الله" : nil
    }

    private enum Keys: String, CodingKey { case left, done, per, owed, perDay }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if let l = try c.decodeIfPresent([Int].self, forKey: .left) {
            left = l
            done = try c.decodeIfPresent(Int.self, forKey: .done) ?? 0
            per = try c.decodeIfPresent(Int.self, forKey: .per) ?? 1
        } else {
            // Earlier app format: owed and done per prayer, perDay 1…5.
            let owed = try c.decodeIfPresent([Int].self, forKey: .owed) ?? [0, 0, 0, 0, 0]
            let d = try c.decodeIfPresent([Int].self, forKey: .done) ?? [0, 0, 0, 0, 0]
            left = zip(owed, d).map { max($0 - $1, 0) }
            done = d.reduce(0, +)
            let p = try c.decodeIfPresent(Int.self, forKey: .perDay) ?? 1
            per = Self.paces.map(\.value).last { $0 <= p } ?? 1
        }
        if left.count != 5 { left = Array((left + [0, 0, 0, 0, 0]).prefix(5)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(left, forKey: .left); try c.encode(done, forKey: .done); try c.encode(per, forKey: .per)
    }
}

struct QadaView: View {
    @AppStorage("qada.state") private var raw = ""
    @State private var daysText = ""
    @State private var confirmReset = false

    private var state: QadaState {
        (try? JSONDecoder().decode(QadaState.self, from: Data(raw.utf8))) ?? QadaState()
    }

    private func save(_ s: QadaState) {
        raw = (try? JSONEncoder().encode(s)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    var body: some View {
        let s = state
        Form {
Group {
            Section {
                LabeledContent("عدد الأيام الفائتة تقريبا") {
                    TextField("مثال: ٣٠", text: $daysText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 120)
                }
                Button("أضف للعداد") {
                    var n = s; n.add(days: Int(ZakatForm.number(daysText))); save(n); daysText = ""
                }
                .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
                .disabled(ZakatForm.number(daysText) < 1)
            } footer: {
                Text("يضاف العدد لكل صلاة من الصلوات الخمس، ويمكنك تعديل كل صلاة بالأزرار.")
            }

            Section {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text(QadaState.prayers[i].name).font(.ui(.headline))
                            .lineLimit(1).fixedSize()
                        Spacer(minLength: 4)
                        Text(Num.int(s.left[i])).font(.ui(.title3, .semibold)).monospacedDigit()
                            .foregroundStyle(Brand.primaryInk)
                            .lineLimit(1).fixedSize()
                            .frame(minWidth: 28)
                        Button {
                            var n = s; n.makeUp(i); save(n)
                        } label: {
                            Text("قضيت واحدة").font(.ui(.subheadline, .semibold))
                                .lineLimit(1).fixedSize()
                                .padding(.horizontal, 6).frame(minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(s.left[i] == 0)
                        Button {
                            var n = s; n.more(i); save(n)
                        } label: {
                            Image(systemName: "plus").frame(width: 30, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("زيادة \(QadaState.prayers[i].name)")
                    }
                    .frame(minHeight: Brand.minTap)
                    .accessibilityElement(children: .contain)
                }
            } header: {
                Text(s.status)
            }

            Section {
                Picker("كم صلاة تقضي يوميا مع كل فرض؟", selection: Binding(
                    get: { s.per }, set: { var n = s; n.per = $0; save(n) })) {
                    ForEach(QadaState.paces, id: \.value) { Text($0.title).tag($0.value) }
                }
                if let plan = s.plan {
                    Text(plan).foregroundStyle(Brand.primaryInk)
                }
            }

            Section {
                Button("تصفير العداد", role: .destructive) { confirmReset = true }
                    .disabled(s.totalRemaining == 0 && s.done == 0)
            } footer: {
                Text("هذه الأداة تنظم العدد فقط. اسأل أهل العلم عن أحكام القضاء وترتيبه. يحفظ على جهازك فقط.")
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("قضاء الصلوات")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("تصفير العداد؟", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("تصفير العداد", role: .destructive) { save(QadaState()) }
        }
    }
}

// MARK: - Fasting tracker (/tools/sawm-tracker)

/// Days marked on a calendar as qada (making up Ramadan) or voluntary, keyed "yyyy-m-d".
struct SawmState: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case qada, tatawwu
        var id: String { rawValue }
        var title: String { self == .qada ? "قضاء" : "تطوع" }
        var recordTitle: String { self == .qada ? "تسجيل قضاء" : "تسجيل تطوع" }
    }

    var required = 0
    var marks: [String: Kind] = [:]

    var qadaDone: Int { marks.values.filter { $0 == .qada }.count }
    var qadaRemaining: Int { max(required - qadaDone, 0) }
    var tatawwu: Int { marks.values.filter { $0 == .tatawwu }.count }

    /// Voluntary days in the given Gregorian year (the site shows «التطوع هذا العام»).
    func tatawwu(inYear year: Int) -> Int {
        marks.filter { $0.value == .tatawwu && $0.key.hasPrefix("\(year)-") }.count
    }

    /// The site's line: «القضاء: ١ من ٥ — التطوع هذا العام: ٠ يوما».
    func status(year: Int) -> String {
        "القضاء: \(Num.int(qadaDone)) من \(Num.int(required)) — التطوع هذا العام: \(Num.int(tatawwu(inYear: year))) يوما"
    }

    /// «نوفمبر ٢٠٢٦ — جمادى الأولى ١٤٤٨ هـ»: the Hijri month of the month's first day, as on the site.
    static func monthTitle(_ firstDay: Date, cal: Calendar) -> String {
        let g = firstDay.formatted(Date.FormatStyle(locale: Num.locale, calendar: cal).month(.wide).year())
        let h = Hijri.fromGregorian(firstDay)
        return "\(g) — \(Hijri.months[h.month - 1]) \(Num.int(h.year)) هـ"
    }

    static func key(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// Tapping a day with the current mode marks it; tapping again with the same mode clears it.
    mutating func tap(_ d: Date, mode: Kind, cal: Calendar) {
        let k = Self.key(d, cal)
        marks[k] = marks[k] == mode ? nil : mode
    }
}

struct SawmView: View {
    @AppStorage("sawm.state") private var raw = ""
    @State private var mode = SawmState.Kind.qada
    @State private var month = Date()
    @State private var requiredText = ""
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.locale = Num.locale
        c.firstWeekday = 1   // the site's calendar starts on Sunday (أحد)
        return c
    }()
    static let weekdays = ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"]

    private var state: SawmState {
        (try? JSONDecoder().decode(SawmState.self, from: Data(raw.utf8))) ?? SawmState()
    }

    private func save(_ s: SawmState) {
        raw = (try? JSONEncoder().encode(s)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    var body: some View {
        let s = state
        Form {
Group {
            Section {
                LabeledContent("عدد أيام القضاء المطلوبة") {
                    HStack {
                        TextField(Num.int(s.required), text: $requiredText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: 80)
                        Button("حفظ") {
                            var n = s; n.required = max(0, Int(ZakatForm.number(requiredText))); save(n); requiredText = ""
                        }
                        .buttonStyle(.bordered)
                        .disabled(requiredText.isEmpty)
                    }
                }
            } header: {
                Text(s.status(year: cal.component(.year, from: Date())))
            }
            Section {
                Picker("النوع", selection: $mode) {
                    ForEach(SawmState.Kind.allCases) { Text($0.recordTitle).tag($0) }
                }
                .pickerStyle(.segmented)
                monthHeader
                grid(s)
            } footer: {
                Text("اختر قضاء أو تطوع ثم اضغط اليوم في التقويم. الضغط مرة ثانية يلغي العلامة.")
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("متتبع الصيام")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.backward").frame(width: Brand.minTap, height: Brand.minTap) }
                .accessibilityLabel("الشهر السابق")
            Spacer()
            Text(SawmState.monthTitle(monthDays().first ?? month, cal: cal))
                .font(.ui(.subheadline, .semibold))
                .multilineTextAlignment(.center)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.forward").frame(width: Brand.minTap, height: Brand.minTap) }
                .accessibilityLabel("الشهر التالي")
        }
        .buttonStyle(.borderless)
    }

    private func grid(_ s: SawmState) -> some View {
        let days = monthDays()
        let lead = (cal.component(.weekday, from: days.first ?? month) - cal.firstWeekday + 7) % 7
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Self.weekdays, id: \.self) { w in
                Text(w).font(.ui(.caption2, .semibold)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 44) }
            ForEach(days, id: \.self) { d in
                let mark = s.marks[SawmState.key(d, cal)]
                let h = Hijri.fromGregorian(d)
                Button {
                    var n = s; n.tap(d, mode: mode, cal: cal); save(n)
                } label: {
                    VStack(spacing: 0) {
                        Text(Num.int(cal.component(.day, from: d))).font(.ui(.subheadline, .medium))
                        Text(Num.int(h.day)).font(.ui(size: 9)).opacity(0.7)
                    }
                    .foregroundStyle(mark == nil ? Color.primary : Color.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(color(mark), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(cal.isDateInToday(d) ? Brand.primary : .clear, lineWidth: 2))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(Num.int(cal.component(.day, from: d)))، \(mark?.title ?? "بلا علامة")")
            }
        }
    }

    private func color(_ k: SawmState.Kind?) -> Color {
        switch k {
        case .qada: Brand.primary
        case .tatawwu: Color(hex: 0xB07D2B)
        case nil: Brand.tint
        }
    }

    private func monthDays() -> [Date] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        var out: [Date] = []
        var d = interval.start
        while d < interval.end { out.append(d); d = cal.date(byAdding: .day, value: 1, to: d)! }
        return out
    }

    private func shift(_ n: Int) { month = cal.date(byAdding: .month, value: n, to: month) ?? month }
}
