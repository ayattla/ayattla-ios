import SwiftUI
import UserNotifications
import AyatDesign

/// Evening reminder when today's pages goal is not met: one request per day for the next week,
/// and today's is withdrawn as soon as the goal is reached.
enum JourneyReminder {
    static let key = "journey.reminder"
    static let hour = 21
    static var enabled: Bool { UserDefaults.standard.bool(forKey: key) }

    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        let j = Journey.shared
        let ids = (0..<8).map { "journey.\(j.today + $0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled else { return }
        for offset in 0..<7 {
            let day = j.today + offset
            if offset == 0 && j.goalMet() { continue }
            var c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Journey.date(of: day))
            c.hour = hour; c.minute = 0
            guard let fire = Calendar(identifier: .gregorian).date(from: c), fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "وردك اليوم"
            let s = j.streak()
            content.body = "هدفك \(Journey.goalLabel(j.goal)) اليوم" + (s > 1 ? " · حافظ على سلسلتك: \(Journey.streakLabel(s))" : "")
            content.sound = .default
            content.userInfo = ["link": "ayattla://tools/journey"]
            center.add(UNNotificationRequest(identifier: "journey.\(day)", content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
        }
    }

    /// Called after reading: once today's goal is met, today's reminder is withdrawn.
    static func goalCheck() {
        guard enabled, Journey.shared.goalMet() else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["journey.\(Journey.shared.today)"])
    }
}

/// «رحلتي مع القرآن»: today's goal, the run of days, this week and this month, and the shortcuts to continue.
struct JourneyView: View {
    @State private var j = Journey.shared
    @AppStorage("quran.lastPage") private var lastPage = 0
    @AppStorage(JourneyReminder.key) private var remind = false
    @AppStorage(PrayerLive.key) private var live = false

    var body: some View {
        let today = j.day()
        let streak = j.streak()
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    GoalRing(done: today.pages.count, goal: j.goal, size: 132, ink: .white, track: .white.opacity(0.18), fill: Color(red: 0.91, green: 0.77, blue: 0.42))
                    Text(j.goalMet() ? "أتممت هدفك اليوم، بارك الله فيك" : "بقي \(Journey.goalLabel(max(j.goal - today.pages.count, 1))) من هدفك اليوم")
                        .font(.ui(.headline, .bold)).foregroundStyle(.white)
                    Label(streak > 0 ? "سلسلتك: \(Journey.streakLabel(streak))" : "ابدأ سلسلتك اليوم", systemImage: "flame.fill")
                        .font(.ui(.body)).foregroundStyle(.white)
                    if j.best > streak { Text("أطول سلسلة: \(Journey.streakLabel(j.best))").font(.ui(.footnote)).foregroundStyle(.white.opacity(0.75)) }
                    NavigationLink { MushafReader(startPage: max(lastPage, 1)) } label: {
                        Text("تابع القراءة").font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent).tint(Brand.goldInk)
                }
                .padding(20).frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color(red: 0.07, green: 0.30, blue: 0.21), Color(red: 0.04, green: 0.18, blue: 0.13)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                SectionHeader("هدفي اليومي", subtitle: "تحتسب كل صفحة تبقى أمامك ثانيتين في المصحف")
                card {
                    HStack(spacing: 6) {
                        ForEach(Journey.goals, id: \.self) { g in
                            Button { j.setGoal(g); JourneyReminder.reschedule() } label: {
                                Text(Journey.goalLabel(g)).font(.ui(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 40)
                                    .foregroundStyle(g == j.goal ? .white : Brand.ink)
                                    .background(g == j.goal ? Brand.primary : Brand.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("بهذا الهدف تختم القرآن في نحو \(Num.int((604 + j.goal - 1) / j.goal)) يوما.").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                }

                SectionHeader("هذا الأسبوع", subtitle: "الصفحات المقروءة كل يوم")
                card { WeekBars(week: j.week(), goal: j.goal) }

                SectionHeader("هذا الشهر")
                card {
                    MonthGrid(j: j)
                    HStack {
                        stat(j.monthPages, "صفحة هذا الشهر"); stat(j.totalAyat, "آية استمعت إليها"); stat(j.totalHifz, "مقطع حفظ ومراجعة")
                    }
                    .padding(.top, 8)
                }

                SectionHeader("أكمل يومك")
                card {
                    NavigationLink { HifzPlanView() } label: { wide("مراجعة الحفظ") }.buttonStyle(.bordered).tint(Brand.primaryInk)
                    NavigationLink { StatusSourceView() } label: { wide("حالة اليوم للواتساب") }.buttonStyle(.bordered).tint(Brand.primaryInk)
                }

                SectionHeader("التذكير وشاشة القفل")
                card {
                    Toggle(isOn: $remind) { setting("ذكّرني إن لم أكمل هدفي", "الساعة 9 مساء، ولا يصلك إن أكملت هدفك") }
                        .tint(Brand.primary)
                        .onChange(of: remind) { _, on in
                            if on { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in JourneyReminder.reschedule() } }
                            else { JourneyReminder.reschedule() }
                        }
                    Toggle(isOn: $live) { setting("الصلاة القادمة على شاشة القفل", "عدّ تنازلي في شاشة القفل والجزيرة التفاعلية، يتجدد عند فتح التطبيق") }
                        .tint(Brand.primary)
                        .onChange(of: live) { _, on in PrayerLive.setEnabled(on) }
                }
            }
            .multilineTextAlignment(.center)
            .padding(16)
        }
        .brandScreen()
        .navigationTitle("رحلتي مع القرآن")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 10, content: c)
            .padding(16).frame(maxWidth: .infinity)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
    }
    private func wide(_ t: String) -> some View { Text(t).font(.ui(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 44) }
    private func stat(_ v: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(Num.int(v)).font(.ui(.title3, .bold)).foregroundStyle(Brand.primaryInk)
            Text(label).font(.ui(.caption2)).foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity)
    }
    private func setting(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.ui(.subheadline)).foregroundStyle(Brand.ink)
            Text(sub).font(.ui(.footnote)).foregroundStyle(Brand.muted)
        }
        .multilineTextAlignment(.leading)
    }
}

/// Pages today against the goal.
struct GoalRing: View {
    let done: Int, goal: Int, size: CGFloat
    var ink: Color = Brand.primaryInk, track: Color = Brand.primary.opacity(0.12), fill: Color = Brand.primary
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: size / 12)
            Circle().trim(from: 0, to: min(Double(done) / Double(max(goal, 1)), 1))
                .stroke(fill, style: StrokeStyle(lineWidth: size / 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: done)
            VStack(spacing: 0) {
                Text(Num.int(done)).font(.ui(size: size > 100 ? 34 : 20, .bold)).foregroundStyle(ink)
                Text("من \(Journey.goalLabel(goal))").font(.ui(.caption2)).foregroundStyle(ink.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("قرأت \(done) من \(Journey.goalLabel(goal))")
    }
}

private struct WeekBars: View {
    let week: [(day: Int, value: Journey.Day)]
    let goal: Int
    var body: some View {
        let mx = max(goal, week.map { $0.value.pages.count }.max() ?? 0, 1)
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(week.reversed(), id: \.day) { d in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6).fill(Brand.primary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 6).fill(d.value.pages.count >= goal ? Brand.primary : Brand.primary.opacity(0.55))
                                .frame(height: 110 * CGFloat(d.value.pages.count) / CGFloat(mx))
                        }
                        .frame(height: 110)
                        Text(Num.int(d.value.pages.count)).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                        Text(d.day == Journey.shared.today ? "اليوم" : Self.dayName(d.day)).font(.ui(.caption2)).foregroundStyle(Brand.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("الأخضر الداكن: يوم أكملت فيه هدفك").font(.ui(.caption2)).foregroundStyle(Brand.muted)
        }
    }
    static func dayName(_ d: Int) -> String {
        let w = Calendar(identifier: .gregorian).component(.weekday, from: Journey.date(of: d))
        return ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"][w - 1]
    }
}

private struct MonthGrid: View {
    let j: Journey
    var body: some View {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let first = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let count = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let lead = cal.component(.weekday, from: first) % 7 // Saturday first: Sat=7→0
        let cells: [Int?] = Array(repeating: nil, count: lead) + (0..<count).map { Journey.dayNumber(first) + $0 }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(["سبت", "أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة"], id: \.self) { Text(String($0.prefix(2))).font(.ui(.caption2)).foregroundStyle(Brand.muted) }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                if let d {
                    let day = j.day(d), met = day.pages.count >= j.goal
                    Text(Num.int(d - Journey.dayNumber(first) + 1))
                        .font(.ui(.caption2, d == j.today ? .bold : .regular))
                        .foregroundStyle(met ? .white : Brand.ink)
                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .background(met ? Brand.primary : (day.active ? Brand.primary.opacity(0.3) : Brand.primary.opacity(0.06)), in: Circle())
                } else { Color.clear.aspectRatio(1, contentMode: .fit) }
            }
        }
    }
}

/// Home: today's goal ring, the run of days, and one tap to continue reading.
struct HomeJourneyCard: View {
    @State private var j = Journey.shared
    var body: some View {
        let streak = j.streak()
        VStack(spacing: 12) {
            CenteredHead("رحلتي مع القرآن")
            NavigationLink { JourneyView() } label: {
                HStack(spacing: 14) {
                    GoalRing(done: j.pagesToday, goal: j.goal, size: 78)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(j.goalMet() ? "أتممت هدفك اليوم" : "هدفك اليوم: \(Journey.goalLabel(j.goal))").font(.ui(.headline, .bold)).foregroundStyle(Brand.ink)
                        Text(streak > 0 ? "سلسلتك: \(Journey.streakLabel(streak))" : "اقرأ صفحة لتبدأ سلسلتك").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.left").foregroundStyle(Brand.muted)
                }
                .padding(16)
                .background(Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}
