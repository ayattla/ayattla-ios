import SwiftUI
import AyatDesign

/// First launch, per design/Onboarding.dc.html and the "أول تشغيل" flow in design/Flows.dc.html:
/// three welcome pages → location (optional) → notifications (optional) → preferred reciter → home.
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
                             body: "تذكير بأذكار الصباح والمساء وآية اليوم وورد الختمة، وتختار ما تريد منها في الإعدادات"),
        .reciter: Page(symbol: "waveform", title: "القارئ المفضل",
                       body: "يستخدم في المصحف وصانع المقاطع، ويمكنك تغييره في أي وقت"),
    ]

    @AppStorage(Prefs.onboardingDone) private var done = false
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var step = Step.clips
    @State private var location = LocationService()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let page = Self.pages[step]!
        VStack(spacing: 0) {
            HStack {
                Button("تخطي") { done = true }
                    .font(.subheadline).foregroundStyle(Brand.primaryInk)
                    .frame(minHeight: Brand.minTap)
                Spacer()
            }
            .padding(.top, 8)

            Spacer(minLength: 24)

            Image(systemName: page.symbol)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 132, height: 132)
                .background(LinearGradient(colors: [Brand.g0, Brand.accent], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                .accessibilityHidden(true)

            Text(page.title)
                .font(.title.weight(.semibold))
                .foregroundStyle(scheme == .dark ? Brand.accent : Brand.g0)
                .multilineTextAlignment(.center)
                .padding(.top, 44)
                .accessibilityAddTraits(.isHeader)

            Text(page.body)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            if step == .reciter {
                Picker("القارئ المفضل", selection: $reciter) {
                    ForEach(Catalog.reciters) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 52)
                .card()
                .padding(.top, 24)
            }

            if step.rawValue <= Step.offline.rawValue {
                HStack(spacing: 8) {
                    ForEach(0...Step.offline.rawValue, id: \.self) { i in
                        Capsule().fill(i == step.rawValue ? Brand.primary : Brand.dotOff)
                            .frame(width: i == step.rawValue ? 24 : 8, height: 8)
                    }
                }
                .padding(.top, 36)
                .accessibilityElement()
                .accessibilityLabel("الصفحة \(Num.int(step.rawValue + 1)) من \(Num.int(3))")
            }

            Spacer()

            VStack(spacing: 10) {
                Button(primaryTitle) { primary() }
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Brand.primary, in: Capsule())
                    .buttonStyle(.plain)
                if step == .location || step == .notifications {
                    Button("ليس الآن") { advance() }
                        .font(.subheadline).foregroundStyle(Brand.primaryInk)
                        .frame(minHeight: Brand.minTap)
                } else {
                    Text("مجاني بالكامل · بلا حساب · يعمل دون إنترنت")
                        .font(.caption).foregroundStyle(Brand.muted)
                        .frame(minHeight: Brand.minTap)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(stops: [.init(color: scheme == .dark ? Brand.g0.opacity(0.35) : Brand.tint, location: 0), .init(color: Color(.systemBackground), location: 0.55)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
        .gesture(DragGesture(minimumDistance: 30).onEnded { g in
            // RTL: swiping toward the left moves forward.
            if g.translation.width < -30 { advance() } else if g.translation.width > 30, let p = Step(rawValue: step.rawValue - 1) { step = p }
        })
    }

    private var primaryTitle: String {
        switch step {
        case .location, .notifications: "السماح"
        case .reciter: "ابدأ"
        default: "التالي"
        }
    }

    private func primary() {
        switch step {
        case .location:
            location.requestLocation()
            advance()
        case .notifications:
            Task { @MainActor in
                _ = await SettingsView.requestNotifications()
                advance()
            }
        default:
            advance()
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next } else { done = true }
    }
}
