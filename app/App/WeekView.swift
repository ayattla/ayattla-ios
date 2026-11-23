import SwiftUI
import AyatDesign
import AyatCalc

/// «أسبوعي»: the last seven days of «يومي» at a glance, five steps a day, and the prayers logged in
/// «صلواتي اليوم». Everything is read from this device and stays on it. Same layout as the Android screen.
struct WeekView: View {
    @AppStorage("prayer.tracker") private var tracker = ""   // "yyyy-MM-dd:fajr,dhuhr;…"

    private struct Row: Identifiable {
        let id: Int
        let date: Date
        let steps: [Double]
        let prayers: Int
    }

    private func rows() -> [Row] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let today = Journey.dayNumber()
        let f = DateFormatter(); f.calendar = cal; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        var logged: [String: Int] = [:]
        for e in tracker.split(separator: ";") {
            let p = e.split(separator: ":", maxSplits: 1)
            guard let k = p.first else { continue }
            logged[String(k)] = p.count > 1 ? p[1].split(separator: ",").count : 0
        }
        return (0..<7).map { back in
            let d = cal.date(byAdding: .day, value: -back, to: Date()) ?? Date()
            let n = today - back
            return Row(id: back, date: d,
                       steps: TodaySlot.allCases.map { HomeDaily.progress($0, dayNum: n, dayDate: d) },
                       prayers: min(logged[f.string(from: d)] ?? 0, 5))
        }
    }

    var body: some View {
        let list = rows()
        let steps = list.reduce(0) { $0 + $1.steps.filter { $0 >= 1 }.count }
        let prayers = list.reduce(0) { $0 + $1.prayers }
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    summary(Num.digits("\(steps)"), "من \(Num.digits("35")) خطوة", "checkmark.circle")
                    summary(Num.digits("\(prayers)"), "من \(Num.digits("35")) صلاة سجلتها", "clock")
                }

                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text("اليوم").frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(TodaySlot.allCases) { s in
                            Image(systemName: HomeDaily.symbol(s)).frame(width: 26).accessibilityLabel(s.title)
                        }
                        Image(systemName: "figure.stand").frame(width: 40).accessibilityLabel("الصلوات")
                    }
                    .font(.ui(.caption, .semibold)).foregroundStyle(Brand.muted)
                    .padding(.bottom, 10)

                    ForEach(list) { r in
                        HStack(spacing: 6) {
                            Text(dayName(r))
                                .font(.ui(.subheadline, r.id == 0 ? .bold : .regular)).foregroundStyle(Brand.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(Array(r.steps.enumerated()), id: \.offset) { _, v in
                                Circle()
                                    .fill(v >= 1 ? Brand.green : (v > 0 ? Brand.tint : Brand.surface2))
                                    .frame(width: 18, height: 18).frame(width: 26)
                            }
                            Text(Num.digits("\(r.prayers)/5"))
                                .font(.ui(.caption, .semibold)).foregroundStyle(r.prayers == 5 ? Brand.green : Brand.muted)
                                .frame(width: 40)
                        }
                        .padding(.vertical, 9)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(dayName(r)): \(r.steps.filter { $0 >= 1 }.count) من خمس خطوات، و\(r.prayers) صلوات")
                        if r.id < 6 { Divider() }
                    }
                }
                .padding(16)
                .surface(.raised, radius: 18)

                Label("هذه الأرقام محفوظة على جهازك فقط ولا ترسل إلى أي جهة", systemImage: "lock")
                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("أسبوعي")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Stats.event("week_opened", "") }
    }

    private func summary(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.ui(.headline)).foregroundStyle(Brand.green)
            Text(value).font(.ui(.title, .bold)).foregroundStyle(Brand.ink)
            Text(label).font(.ui(.caption)).foregroundStyle(Brand.muted)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .surface(.raised, radius: 16)
    }

    private func dayName(_ r: Row) -> String {
        if r.id == 0 { return "اليوم" }
        if r.id == 1 { return "أمس" }
        let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "EEEE"
        return f.string(from: r.date)
    }
}
