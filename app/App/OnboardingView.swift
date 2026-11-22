import SwiftUI
import UserNotifications
import AyatDesign
import AyatCalc

/// «تجربة البداية»: a short welcome, five optional questions and a done screen, the same flow as Android.
/// Every question can be skipped, «ادخل مباشرة» leaves at once, answers are saved as they are given
/// (closing the app resumes at the same step) and nothing is asked again after it ends. No permission is
/// requested unless the user turns on a reminder, and then only notifications; location is never asked
/// here (adhkar reminders follow the chosen city). [editing]: opened from Settings to change answers.
struct OnboardingView: View {
    typealias Step = Welcome.Step
    var editing = false
    var onClose: (() -> Void)? = nil

    @AppStorage(Prefs.onboardingDone) private var done = false
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @AppStorage(Prefs.appearance) private var appearance = Appearance.light.rawValue
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name
    @State private var step: Step = .hello
    @State private var forward = true
    @State private var uses = Welcome.uses_
    @State private var likes = Welcome.likes_
    @State private var reminders = Welcome.reminders_
    @State private var listen = Welcome.listen_
    @State private var notifyDenied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()
            switch step {
            case .hello: hello.transition(.opacity)
            case .done: finished.transition(.opacity)
            default: question(step).id(step).transition(moveTransition)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88), value: step)
        .sensoryFeedback(.selection, trigger: step)
        .onAppear {
            if editing { step = .uses } else {
                step = Welcome.step
                if step == .hello { Stats.event("onboarding_started") }
            }
        }
        .toolbar(editing ? .hidden : .automatic, for: .navigationBar)
    }

    private var moveTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        // RTL: forward enters from the leading (left) edge.
        return .asymmetric(insertion: .move(edge: forward ? .leading : .trailing).combined(with: .opacity),
                           removal: .opacity)
    }

    // MARK: Navigation

    private func go(_ to: Step, forward f: Bool = true) {
        forward = f
        step = to
        if !editing { Welcome.save(step: to) }
    }

    private func next(skipped: Bool = false) {
        Stats.event(skipped ? "onboarding_skipped" : "onboarding_step_completed", step.rawValue)
        let all = Step.allCases
        if let i = all.firstIndex(of: step), i + 1 < all.count { go(all[i + 1]) }
    }

    private func back() {
        let all = Step.allCases
        guard let i = all.firstIndex(of: step), i > (editing ? 1 : 0) else { return }
        go(all[i - 1], forward: false)
    }

    private func finish(leftEarly: Bool) {
        Stats.event(leftEarly ? "onboarding_skipped" : "onboarding_completed", leftEarly ? step.rawValue : "")
        UserDefaults.standard.removeObject(forKey: Welcome.stepKey)
        if editing { onClose?() ?? dismiss() } else { done = true }
    }

    private func submit() {
        switch step {
        case .uses: Welcome.save(uses: uses); uses.forEach { Stats.event("interests_selected", $0) }; next()
        case .likes: Welcome.save(likes: likes); likes.forEach { Stats.event("content_selected", $0) }; next()
        case .listen:
            Welcome.save(listen: listen)
            Stats.event("listen_choice", listen.split(separator: ":").first.map(String.init) ?? "none")
            next()
        case .reminders:
            Welcome.save(reminders: reminders)
            reminders.forEach { Stats.event("notification_preferences_saved", $0) }
            guard !reminders.isEmpty else { next(); return }
            Task {
                let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                if ok { applyReminders() }
                await MainActor.run { notifyDenied = !ok; next() }
            }
        case .theme: Stats.event("theme_selected", appearance); next()
        default: next()
        }
    }

    /// Turns on the chosen reminders in the alerts centre (the same settings as «مركز التنبيهات»).
    private func applyReminders() {
        var c = NotifyConfig.load()
        if reminders.contains("morning") { c.morning = true }
        if reminders.contains("evening") { c.evening = true }
        if reminders.contains("khatma") { c.khatma = true }
        if reminders.contains("ayah") { c.ayah = true }
        c.save()
        if reminders.contains("journey") {
            UserDefaults.standard.set(true, forKey: JourneyReminder.key)
            JourneyReminder.reschedule()
        }
        Task { await Reminders.reschedule() }
    }

    // MARK: Welcome

    private var hello: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack {
                    Brand.gradient
                    IslamicPattern(color: Brand.accent.opacity(0.12))
                    RadialGradient(colors: [Brand.green.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.6), startRadius: 0, endRadius: 260)
                    medallion { Image("LogoFull").resizable().scaledToFit().padding(26).environment(\.colorScheme, .light) }
                        .padding(.top, geo.safeAreaInsets.top)
                }
                .frame(height: min(max(geo.size.height * 0.46, 280), 440) + geo.safeAreaInsets.top)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
                .overlay(alignment: .bottom) { Capsule().fill(Brand.goldGradient).frame(width: 64, height: 4).offset(y: -14) }
                .shadow(color: Color(hex: 0x0B211C).opacity(0.22), radius: 18, y: 10)

                ScrollView {
                    VStack(spacing: Brand.Space.m) {
                        Text("رفيقك للقرآن والذكر وصناعة الخير")
                            .font(.ui(.title, .bold)).foregroundStyle(Brand.ink)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("مصحف وتلاوات وأذكار ومواقيت، وصانع حالات ومقاطع وبطاقات إسلامية، في تطبيق واحد يعمل حتى دون إنترنت.")
                            .font(.ui(.body)).lineSpacing(6).foregroundStyle(Brand.muted)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28).padding(.top, Brand.Space.xl)
                    .frame(maxWidth: 520).frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 6) {
                    Button { next() } label: {
                        Text("ابدأ رحلتك").font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.brandPrimary)
                    Button("ادخل مباشرة") { finish(leftEarly: true) }
                        .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                        .frame(minHeight: Brand.minTap)
                    Text("مجاني بالكامل · بلا إعلانات · بلا تسجيل").font(.ui(.caption)).foregroundStyle(Brand.muted)
                }
                .padding(.horizontal, 28).frame(maxWidth: 520).padding(.bottom, Brand.Space.s)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func medallion<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        let size: CGFloat = typeSize.isAccessibilitySize ? 132 : 164
        return ZStack {
            Circle().strokeBorder(Brand.accent.opacity(0.22), lineWidth: 1).frame(width: size + 44, height: size + 44)
            Circle().strokeBorder(Brand.accent.opacity(0.55), lineWidth: 1.2).frame(width: size + 16, height: size + 16)
            content().frame(width: size, height: size).background(Color.white, in: Circle())
        }
        .accessibilityHidden(true)
    }

    // MARK: A question

    private func title(_ s: Step) -> (String, String) {
        switch s {
        case .uses: ("ما الذي تريد استخدام آيات تتلى من أجله؟", "اختر ما يهمك، وسنقدمه لك في الرئيسية")
        case .likes: ("ما نوع المحتوى الذي تفضله؟", "يساعدنا في اقتراح ما يناسبك")
        case .listen: ("كيف تفضل الاستماع إلى القرآن؟", "يستخدم في المصحف المسموع وصانع المقاطع")
        case .reminders: ("ما التذكيرات التي ترغب فيها؟", "تذكيرات لطيفة، وتستطيع تغييرها في أي وقت")
        default: ("كيف تفضل عرض التطبيق؟", "يتغير المظهر فورا لترى الفرق")
        }
    }

    private func question(_ s: Step) -> some View {
        let index = Welcome.questions.firstIndex(of: s) ?? 0
        let (t, sub) = title(s)
        return VStack(spacing: 0) {
            HStack(spacing: Brand.Space.s) {
                Button { back() } label: {
                    Image(systemName: "chevron.backward").font(.ui(.headline)).foregroundStyle(Brand.ink)
                        .frame(width: Brand.minTap, height: Brand.minTap)
                }
                .buttonStyle(.plain)
                .opacity(index == 0 && editing ? 0 : 1)
                .accessibilityLabel("رجوع")
                HStack(spacing: 6) {
                    ForEach(Welcome.questions.indices, id: \.self) { i in
                        Capsule().fill(i <= index ? Brand.green : Brand.line).frame(height: 5)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("السؤال \(Num.int(index + 1)) من \(Num.int(Welcome.questions.count))")
                Button("تخطي") {
                    if s == .reminders { reminders = []; Welcome.save(reminders: []) }
                    next(skipped: true)
                }
                .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                .padding(.horizontal, 12).frame(minHeight: Brand.minTap)
            }
            .padding(.horizontal, Brand.Space.m)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Num.int(index + 1)) من \(Num.int(Welcome.questions.count))").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.goldInk)
                    Text(t).font(.ui(.title2, .bold)).foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(sub).font(.ui(.subheadline)).foregroundStyle(Brand.muted).padding(.bottom, Brand.Space.m)
                    switch s {
                    case .uses: grid(Welcome.uses, $uses)
                    case .likes: grid(Welcome.likes, $likes)
                    case .listen: listenStep
                    case .reminders: remindStep
                    default: themeStep
                    }
                }
                .padding(.horizontal, 20).padding(.top, Brand.Space.s).padding(.bottom, Brand.Space.l)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button { submit() } label: {
                Text(s == .theme ? "إنهاء" : "التالي").font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.brandPrimary)
            .padding(.horizontal, 20).frame(maxWidth: 640).padding(.bottom, Brand.Space.s)
        }
    }

    /// Multi-select cards: two columns on phones, three on iPad (one at the largest text sizes).
    private func grid(_ choices: [Welcome.Choice], _ selection: Binding<Set<String>>) -> some View {
        let n = typeSize.isAccessibilitySize ? 1 : (UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: n), spacing: 10) {
            ForEach(choices) { c in
                let on = selection.wrappedValue.contains(c.id)
                Button {
                    if on { selection.wrappedValue.remove(c.id) } else { selection.wrappedValue.insert(c.id) }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Image(systemName: c.symbol).font(.ui(.headline)).foregroundStyle(on ? .white : Brand.primaryInk)
                                .frame(width: 36, height: 36)
                                .background(on ? Brand.green : Brand.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            Spacer(minLength: 0)
                            if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.green) }
                        }
                        Text(c.label).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(14)
                    .background(on ? Brand.tint : Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Brand.green : Brand.line, lineWidth: on ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// One wide option with a radio mark (single choice) or a check mark.
    private func row(_ title: String, _ subtitle: String?, _ symbol: String, on: Bool, check: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.ui(.headline)).foregroundStyle(on ? .white : Brand.primaryInk)
                    .frame(width: 36, height: 36)
                    .background(on ? Brand.green : Brand.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                    if let subtitle { Text(subtitle).font(.ui(.caption)).foregroundStyle(Brand.muted) }
                }
                Spacer(minLength: 0)
                Image(systemName: check ? (on ? "checkmark.square.fill" : "square") : (on ? "largecircle.fill.circle" : "circle"))
                    .font(.ui(.title3)).foregroundStyle(on ? Brand.green : Brand.line)
            }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 64)
            .background(on ? Brand.tint : Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Brand.green : Brand.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var listenStep: some View {
        VStack(spacing: 10) {
            row("قارئ مفضل", "اختر من القراء المتاحين في التطبيق", "headphones", on: listen.hasPrefix("reciter")) { listen = "reciter:" + reciter }
            if listen.hasPrefix("reciter") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Catalog.reciters) { r in
                            let on = reciter == r.id
                            Button(r.name) { reciter = r.id; listen = "reciter:" + r.id }
                                .font(.ui(.subheadline)).foregroundStyle(on ? .white : Brand.ink)
                                .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                                .background(on ? Brand.green : Brand.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(on ? Brand.green : Brand.line, lineWidth: 1))
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            row("قراء متنوعون", "أتنقل بين القراء", "shuffle", on: listen == "various") { listen = "various" }
            row("لا أفضل خيارا الآن", nil, "clock", on: listen == "later") { listen = "later" }
        }
    }

    private var remindStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Welcome.reminders) { r in
                let on = reminders.contains(r.id)
                let sub = switch r.id {
                case "morning": "بعد الفجر بنصف ساعة"
                case "evening": "بعد العصر بنصف ساعة"
                case "journey": "التاسعة مساء، ولا يصلك إن أكملت هدفك"
                case "khatma": "حين تنشئ خطة ختمتك"
                default: "التاسعة صباحا"
                }
                row(r.label, sub, r.symbol, on: on, check: true) { if on { reminders.remove(r.id) } else { reminders.insert(r.id) } }
            }
            Text("أوقات الأذكار حسب مدينة \(cityName)، ولا نحتاج موقعك. إن اخترت تذكيرا نطلب إذن الإشعارات حين تتابع.")
                .font(.ui(.caption)).foregroundStyle(Brand.muted).padding(.top, 4)
        }
    }

    private var themeStep: some View {
        VStack(spacing: 10) {
            row("الوضع الفاتح", "الأخضر والأبيض، المظهر الأصلي", "sun.max", on: appearance == Appearance.light.rawValue) { appearance = Appearance.light.rawValue }
            row("الوضع الداكن", "مريح للقراءة ليلا", "moon", on: appearance == Appearance.dark.rawValue) { appearance = Appearance.dark.rawValue }
            row("حسب إعدادات الجهاز", "يتبدل تلقائيا مع جهازك", "iphone", on: appearance == Appearance.system.rawValue) { appearance = Appearance.system.rawValue }
        }
    }

    // MARK: Done

    private var finished: some View {
        ScrollView {
            VStack(spacing: Brand.Space.m) {
                Image(systemName: "checkmark").font(.ui(size: 40, .bold)).foregroundStyle(.white)
                    .frame(width: 88, height: 88).background(Brand.green, in: Circle())
                    .padding(.top, 72).accessibilityHidden(true)
                Text("أهلا بك في آيات تتلى").font(.ui(.title2, .bold)).foregroundStyle(Brand.ink).multilineTextAlignment(.center)
                Text("جهزنا لك تجربة تناسب اهتماماتك").font(.ui(.body)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
                let picked = Welcome.uses.filter { uses.contains($0.id) }
                if !picked.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(picked) { u in
                            Text(u.label).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                                .padding(.horizontal, 12).padding(.vertical, 7).background(Brand.tint, in: Capsule())
                        }
                    }
                    .padding(.top, Brand.Space.s)
                }
                if notifyDenied {
                    Text("لم تفعل التذكيرات لأن إذن الإشعارات لم يمنح، ويمكنك تفعيلها لاحقا من مركز التنبيهات.")
                        .font(.ui(.footnote)).foregroundStyle(Brand.goldInk).multilineTextAlignment(.center)
                }
                Button { finish(leftEarly: false) } label: {
                    Text("ابدأ الآن").font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.brandPrimary).padding(.top, Brand.Space.xl)
                Text("نرسل إحصاءات استخدام مجهولة بلا أي بيانات شخصية لنحسن التطبيق، ويمكنك إيقافها من الإعدادات.")
                    .font(.ui(.caption)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Home «مختارات لك»

/// A greeting by the time of day and, for each interest chosen at first run, a row of the real tools it
/// covers. With no interests, one card invites the user to pick some. Every tool stays reachable from
/// «أقسام الأدوات» whatever is chosen here.
struct HomeForYou: View {
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4...11: "صباح الخير"
        case 12...16: "طاب يومك"
        default: "مساء الخير"
        }
    }

    var body: some View {
        let picked = Array(Welcome.pickedUses.prefix(4))
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            VStack(spacing: 2) {
                Text(greeting).font(.ui(.title2, .bold)).foregroundStyle(Brand.ink)
                Text(picked.isEmpty ? "اختر اهتماماتك لنقدم لك ما يناسبك أولا" : "مختارات تناسب اهتماماتك")
                    .font(.ui(.subheadline)).foregroundStyle(Brand.muted)
            }
            .frame(maxWidth: .infinity)
            if picked.isEmpty {
                NavigationLink { OnboardingView(editing: true) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(Brand.primaryInk)
                        Text("اختر اهتماماتك").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                        Spacer(minLength: 0)
                        Text("دقيقة واحدة").font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk)
                    }
                    .padding(16).frame(minHeight: 56).surface(.raised, radius: 18)
                }
                .buttonStyle(.plain)
            }
            ForEach(picked) { u in
                let tools = u.tools.compactMap(SiteTool.tool)
                if !tools.isEmpty {
                    Text(u.label).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tools) { t in
                                NavigationLink { t.destination.onAppear { ToolUsage.record(t.id); Stats.event("home_shortcut_opened", t.id) } } label: {
                                    VStack(spacing: 8) {
                                        IconTile(t.symbol, style: .accent(t.accent), size: 50)
                                        Text(t.title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                                            .multilineTextAlignment(.center).lineLimit(2)
                                        Text(t.subtitle).font(.ui(.caption)).foregroundStyle(Brand.muted)
                                            .multilineTextAlignment(.center).lineLimit(3)
                                    }
                                    .padding(14).frame(width: 158, alignment: .top)
                                    .frame(minHeight: 170, maxHeight: .infinity, alignment: .top)
                                    .surface(.raised, radius: 18)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        // One height for every card in the row.
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                    }
                    // Edge to edge, and the soft shadows are never cut into a band at the row's edges.
                    .scrollClipDisabled()
                    .contentMargins(.horizontal, Brand.Space.l, for: .scrollContent)
                    .padding(.horizontal, -Brand.Space.l)
                }
            }
        }
    }
}

/// One-time note for people who updated (they never saw the first-run screens): what the anonymous
/// stats are, and how to turn them off.
struct StatsNoticeCard: View {
    var onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ساعدنا في تحسين آيات تتلى").font(.ui(.headline)).foregroundStyle(Brand.ink)
            Text("نجمع أعدادا مجهولة لاستخدام الأدوات والخطوات، بلا اسم ولا رقم ولا موقع ولا أي معرف لجهازك. يمكنك إيقافها الآن أو من الإعدادات.")
                .font(.ui(.footnote)).foregroundStyle(Brand.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { Welcome.statsNoticeSeen(); onClose() } label: { Text("حسنا").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.brandPrimary)
                Button { Stats.setEnabled(false); Welcome.statsNoticeSeen(); onClose() } label: { Text("إيقافها").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.bordered).tint(Brand.primaryInk)
            }
        }
        .padding(16).surface(.raised, radius: 18)
    }
}
