import SwiftUI
import AyatDesign

/// First launch, per design/Onboarding.dc.html and the "أول تشغيل" flow in design/Flows.dc.html:
/// three welcome pages → location (optional) → notifications (optional) → preferred reciter → home.
/// v4 layout: emerald hero with the star lattice, segmented progress, back and skip; the text and
/// actions on the page below.
struct OnboardingView: View {
    enum Step: Int, CaseIterable { case clips, prayer, offline, location, notifications, reciter }

    struct Page {
        let symbol: String
        let title: String
        let body: String
    }

    static let pages: [Step: Page] = [
        .clips: Page(symbol: "book", title: "اصنع مقطعك القرآني",
                     body: "اختر الآيات والقارئ والخلفية، وصدر مقطعا بتظليل الكلمات على جهازك مباشرة"),
        .prayer: Page(symbol: "clock", title: "مواقيت الصلاة والقبلة",
                      body: "مواقيت مدينتك واتجاه القبلة والمساجد القريبة، تحسب كلها على جهازك"),
        .offline: Page(symbol: "arrow.down.circle", title: "معك دون إنترنت",
                       body: "الأدوات ومشاريعك محفوظة على جهازك، بلا حساب ولا تسجيل"),
        .location: Page(symbol: "location", title: "موقعك للمواقيت",
                        body: "نستخدم موقعك على جهازك فقط لحساب المواقيت والقبلة. يمكنك اختيار مدينتك يدويا بدلا من ذلك"),
        .notifications: Page(symbol: "bell", title: "التنبيهات",
                             body: "تذكير بأذكار الصباح والمساء وآية اليوم وورد الختمة. فعل ما تريد منها من الإعدادات بعد تنزيل المحتوى"),
        .reciter: Page(symbol: "waveform", title: "القارئ المفضل",
                       body: "يستخدم في المصحف وصانع المقاطع، ويمكنك تغييره في أي وقت"),
    ]

    @AppStorage(Prefs.onboardingDone) private var done = false
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var step = Step.clips
    @State private var location = LocationService()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let page = Self.pages[step]!
        GeometryReader { geo in
            VStack(spacing: 0) {
                hero(page, top: geo.safeAreaInsets.top, height: heroHeight(geo.size.height) + geo.safeAreaInsets.top)

                ScrollView {
                    VStack(spacing: Brand.Space.m) {
                        Text("الخطوة \(Num.int(step.rawValue + 1)) من \(Num.int(Step.allCases.count))")
                            .font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Brand.tint, in: Capsule())

                        Text(page.title)
                            .font(.ui(.title, .bold))
                            .foregroundStyle(Brand.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text(page.body)
                            .font(.ui(.body))
                            .lineSpacing(6)
                            .foregroundStyle(Brand.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if step == .clips { promises.padding(.top, Brand.Space.s) }

                        if step == .reciter {
                            Picker("القارئ المفضل", selection: $reciter) {
                                ForEach(Catalog.reciters) { Text($0.name).tag($0.id) }
                            }
                            .pickerStyle(.menu)
                            .tint(Brand.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .surface(.raised, radius: 16)
                            .padding(.top, Brand.Space.s)
                        }
                    }
                    .id(step)
                    .transition(textTransition)
                    .padding(.horizontal, 28).padding(.top, Brand.Space.xl)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)

                actions
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 520)
                    .padding(.bottom, Brand.Space.s)
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Brand.background.ignoresSafeArea())
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: step)
        .sensoryFeedback(.selection, trigger: step)
        .gesture(DragGesture(minimumDistance: 30).onEnded { g in
            // RTL: swiping toward the left moves forward.
            if g.translation.width < -30 { advance() } else if g.translation.width > 30 { back() }
        })
    }

    /// Emerald hero with the star lattice: back, progress and skip on top; the step's emblem below.
    private func hero(_ page: Page, top: CGFloat, height: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous)
        return VStack(spacing: 0) {
            HStack(spacing: Brand.Space.s) {
                Button { back() } label: {
                    Image(systemName: "chevron.backward").font(.ui(.headline))
                        .frame(width: Brand.minTap, height: Brand.minTap)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .opacity(step == .clips ? 0 : 1)
                .disabled(step == .clips)
                .accessibilityLabel("السابق")

                Spacer(minLength: 0)
                progress
                Spacer(minLength: 0)

                Button("تخطي") { done = true }
                    .font(.ui(.subheadline, .semibold))
                    .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .buttonStyle(.plain)
            }
            .foregroundStyle(Color(hex: 0xF6F2E9))
            .padding(.horizontal, Brand.Space.l)

            Spacer(minLength: Brand.Space.m)
            emblem(page)
                .id(step)
                .transition(emblemTransition)
            Spacer(minLength: Brand.Space.l)
        }
        .padding(.top, top + Brand.Space.s)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            ZStack {
                Brand.gradient
                IslamicPattern(color: Brand.accent.opacity(0.12))
                RadialGradient(colors: [Brand.green.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.62),
                               startRadius: 0, endRadius: 260)
            }
            .clipShape(shape)
        }
        .overlay(alignment: .bottom) {
            Capsule().fill(Brand.goldGradient).frame(width: 64, height: 4).offset(y: -14)
        }
        .shadow(color: Color(hex: 0x0B211C).opacity(0.22), radius: 18, y: 10)
    }

    /// The step's emblem in a gold-ringed medallion; the first page shows the site's full logo.
    private func emblem(_ page: Page) -> some View {
        let size: CGFloat = typeSize.isAccessibilitySize ? 132 : 164
        return ZStack {
            Circle().strokeBorder(Brand.accent.opacity(0.22), lineWidth: 1).frame(width: size + 44, height: size + 44)
            Circle().strokeBorder(Brand.accent.opacity(0.55), lineWidth: 1.2).frame(width: size + 16, height: size + 16)
            if step == .clips {
                Image("LogoFull").resizable().scaledToFit()
                    .padding(size * 0.16)
                    .frame(width: size, height: size)
                    .background(Color.white, in: Circle())
                    .environment(\.colorScheme, .light)
            } else {
                Image(systemName: page.symbol)
                    .font(.ui(size: size * 0.34, .light))
                    .foregroundStyle(Brand.onDeepAccent)
                    .frame(width: size, height: size)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }

    /// One segment per step; the current one is longer and gold.
    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s == step ? Brand.onDeepAccent : Color.white.opacity(s.rawValue < step.rawValue ? 0.6 : 0.22))
                    .frame(width: s == step ? 26 : 8, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("الصفحة \(Num.int(step.rawValue + 1)) من \(Num.int(Step.allCases.count))")
    }

    /// The site's three promises, under the first page.
    private var promises: some View {
        HStack(spacing: Brand.Space.s) {
            promise("gift", "مجاني بالكامل")
            promise("person.crop.circle.badge.xmark", "بلا حساب")
            promise("wifi.slash", "دون إنترنت")
        }
    }

    private func promise(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.ui(.title3)).foregroundStyle(Brand.primaryInk)
            Text(title).font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .surface(.flat, radius: 16)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button { primary() } label: {
                HStack(spacing: 8) {
                    Text(primaryTitle)
                    Image(systemName: step == .reciter ? "checkmark" : "arrow.forward").font(.ui(.subheadline, .bold))
                }
                .font(.ui(.headline))
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.brandPrimary)

            if step == .location {
                Button("ليس الآن") { advance() }
                    .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                    .frame(minHeight: Brand.minTap)
            } else {
                Text("مجاني بالكامل · بلا حساب · يعمل دون إنترنت")
                    .font(.ui(.caption)).foregroundStyle(Brand.muted)
                    .frame(minHeight: Brand.minTap)
            }
        }
    }

    private var textTransition: AnyTransition {
        reduceMotion ? AnyTransition.opacity
            : AnyTransition.asymmetric(insertion: AnyTransition.opacity.combined(with: AnyTransition.offset(y: 14)),
                                       removal: AnyTransition.opacity)
    }

    private var emblemTransition: AnyTransition {
        reduceMotion ? AnyTransition.opacity : AnyTransition.opacity.combined(with: AnyTransition.scale(scale: 0.9))
    }

    private func heroHeight(_ total: CGFloat) -> CGFloat {
        min(max(total * 0.42, 260), 420)
    }

    private var primaryTitle: String {
        switch step {
        case .location: "السماح"
        case .reciter: "ابدأ"
        default: "التالي"
        }
    }

    private func primary() {
        switch step {
        case .location:
            location.requestLocation()
            advance()
        default:
            advance()
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next } else { done = true }
    }

    private func back() {
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }
}
