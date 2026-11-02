import SwiftUI
import AyatDesign
import AyatCalc

// MARK: - Qada of prayers (/tools/qada-salah)

/// Missed-prayer tracker: owed count per prayer, "قضيت واحدة" after each made-up prayer,
/// remaining and a daily plan. Saved on the device.
struct QadaState: Codable, Equatable {
    static let prayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    var owed: [Int] = [0, 0, 0, 0, 0]
    var done: [Int] = [0, 0, 0, 0, 0]
    var perDay = 1

    init() {}
    init(days: Int) { owed = Array(repeating: max(days, 0), count: 5) }

    func remaining(_ i: Int) -> Int { max(owed[i] - done[i], 0) }
    var totalRemaining: Int { (0..<5).map(remaining).reduce(0, +) }
    var totalOwed: Int { owed.reduce(0, +) }

    /// Days left if `perDay` extra prayers of each kind are made up every day.
    var daysLeft: Int {
        let worst = (0..<5).map(remaining).max() ?? 0
        return worst == 0 ? 0 : (worst + perDay - 1) / perDay
    }

    mutating func makeUp(_ i: Int) { if remaining(i) > 0 { done[i] += 1 } }
    mutating func undo(_ i: Int) { if done[i] > 0 { done[i] -= 1 } }
}

struct QadaView: View {
    @AppStorage("qada.state") private var raw = ""
    @State private var days = 30
    @State private var confirmReset = false

    private var state: QadaState? {
        raw.isEmpty ? nil : try? JSONDecoder().decode(QadaState.self, from: Data(raw.utf8))
    }

    private func save(_ s: QadaState?) {
        raw = s.flatMap { try? JSONEncoder().encode($0) }.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    var body: some View {
        Form {
            if let s = state {
                Section {
                    LabeledContent("المتبقي", value: Num.int(s.totalRemaining))
                    LabeledContent("قضيت", value: "\(Num.int(s.totalOwed - s.totalRemaining)) من \(Num.int(s.totalOwed))")
                    ProgressView(value: Double(s.totalOwed - s.totalRemaining), total: Double(max(s.totalOwed, 1)))
                        .tint(Brand.primary)
                }
                Section("الصلوات") {
                    ForEach(0..<5, id: \.self) { i in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(QadaState.prayers[i].name).font(.headline)
                                Text("متبق \(Num.int(s.remaining(i)))").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                var n = s; n.undo(i); save(n)
                            } label: { Image(systemName: "minus.circle").frame(width: Brand.minTap, height: Brand.minTap) }
                            .buttonStyle(.borderless)
                            .disabled(s.done[i] == 0)
                            .accessibilityLabel("تراجع عن قضاء \(QadaState.prayers[i].name)")
                            Button {
                                var n = s; n.makeUp(i); save(n)
                            } label: {
                                Text("قضيت واحدة").font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).frame(minHeight: 36)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .disabled(s.remaining(i) == 0)
                        }
                        .frame(minHeight: Brand.minTap)
                    }
                }
                Section {
                    Stepper("مع كل صلاة: \(Num.int(s.perDay)) قضاء يوميا", value: Binding(
                        get: { s.perDay }, set: { var n = s; n.perDay = $0; save(n) }), in: 1...5)
                    if s.daysLeft > 0 {
                        let end = Calendar(identifier: .gregorian).date(byAdding: .day, value: s.daysLeft, to: Date()) ?? Date()
                        LabeledContent("تنتهي بعد", value: "\(Num.int(s.daysLeft)) يوما")
                        LabeledContent("نحو", value: end.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Num.locale)))
                    } else {
                        Text("أتممت القضاء").foregroundStyle(Brand.primaryInk)
                    }
                } header: { Text("الخطة اليومية") }
                Section {
                    Button("بدء من جديد", role: .destructive) { confirmReset = true }
                }
            } else {
                Section {
                    Stepper("الأيام الفائتة تقريبا: \(Num.int(days))", value: $days, in: 1...20_000, step: days < 60 ? 1 : 30)
                    Button("ابدأ") { save(QadaState(days: days)) }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: Brand.minTap)
                } footer: {
                    Text("يحسب لكل صلاة من الخمس عدد الأيام الفائتة، واضغط «قضيت واحدة» بعد كل صلاة تقضيها. يحفظ على جهازك.")
                }
            }
        }
        .navigationTitle("قضاء الصلوات")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("حذف العداد والبدء من جديد؟", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("بدء من جديد", role: .destructive) { save(nil) }
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
    }

    var required = 0
    var marks: [String: Kind] = [:]

    var qadaDone: Int { marks.values.filter { $0 == .qada }.count }
    var qadaRemaining: Int { max(required - qadaDone, 0) }
    var tatawwu: Int { marks.values.filter { $0 == .tatawwu }.count }

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
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.locale = Num.locale; return c
    }()

    private var state: SawmState {
        (try? JSONDecoder().decode(SawmState.self, from: Data(raw.utf8))) ?? SawmState()
    }

    private func save(_ s: SawmState) {
        raw = (try? JSONEncoder().encode(s)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    var body: some View {
        let s = state
        Form {
            Section {
                Stepper("أيام القضاء المطلوبة: \(Num.int(s.required))", value: Binding(
                    get: { s.required }, set: { var n = s; n.required = $0; save(n) }), in: 0...60)
                LabeledContent("المتبقي من القضاء", value: Num.int(s.qadaRemaining))
                LabeledContent("أيام التطوع", value: Num.int(s.tatawwu))
            }
            Section {
                Picker("النوع", selection: $mode) {
                    ForEach(SawmState.Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                monthHeader
                grid(s)
            } footer: {
                Text("اختر قضاء أو تطوع ثم اضغط اليوم في التقويم. الضغط مرة ثانية يلغي العلامة.")
            }
        }
        .navigationTitle("متتبع الصيام")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.backward").frame(width: Brand.minTap, height: Brand.minTap) }
                .accessibilityLabel("الشهر السابق")
            Spacer()
            VStack(spacing: 2) {
                Text(month.formatted(Date.FormatStyle(locale: Num.locale).month(.wide).year())).font(.headline)
                Text(Num.hijri(month)).font(.caption).foregroundStyle(.secondary)
            }
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
            ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 44) }
            ForEach(days, id: \.self) { d in
                let mark = s.marks[SawmState.key(d, cal)]
                let h = Hijri.fromGregorian(d)
                Button {
                    var n = s; n.tap(d, mode: mode, cal: cal); save(n)
                } label: {
                    VStack(spacing: 0) {
                        Text(Num.int(cal.component(.day, from: d))).font(.subheadline.weight(.medium))
                        Text(Num.int(h.day)).font(.system(size: 9)).opacity(0.7)
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
