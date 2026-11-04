import SwiftUI
import AyatDesign

@main
struct AyatTutlaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase

    init() {
        _ = ContentLibrary.shared      // registers the bundled fonts before the first frame
        BrandAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            // Right to left in both SwiftUI (here) and UIKit (BrandAppearance): when the two disagree,
            // iOS 17 mirrors the text inside List and Form cells.
            StartView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Num.locale)
                .font(.ui(.body))
                .tint(Brand.primaryInk)
        }
        .onChange(of: phase) { _, p in
            if p == .active {
                QF.purgeOld()
                Task { await Reminders.reschedule() }
            }
        }
    }
}

/// The five sections of the bottom bar (master prompt §4): home, Quran, content making, azkar and
/// hadith, and more (every tool and «مكتبتي»). Labels stay short so none is cut on small iPhones.
enum Tab: String, CaseIterable, Identifiable {
    case home, quran, studio, azkar, more
    var id: String { rawValue }
    /// Bar label.
    var title: String {
        switch self {
        case .home: "الرئيسية"
        case .quran: "القرآن"
        case .studio: "اصنع"
        case .azkar: "الأذكار"
        case .more: "المزيد"
        }
    }
    /// Full name, used in the iPad sidebar.
    var longTitle: String {
        switch self {
        case .home: "الرئيسية"
        case .quran: "القرآن الكريم"
        case .studio: "صناعة المحتوى"
        case .azkar: "الأذكار والحديث"
        case .more: "المزيد والأدوات"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .quran: "book"
        case .studio: "play.rectangle"
        case .azkar: "sun.max"
        case .more: "square.grid.2x2"
        }
    }
}

/// iPhone: the fixed bottom bar (TabView, each section keeps its own navigation state).
/// iPad: a sidebar with the same sections. The mini player sits above the bar on both.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var size
    @State private var tab: Tab = .home
    @State private var audio = AudioCenter.shared

    var body: some View {
        Group {
            if size == .regular {
                NavigationSplitView {
                    List(Tab.allCases, selection: Binding(get: { tab }, set: { tab = $0 ?? .home })) { t in
                        Label(t.longTitle, systemImage: t.symbol).tag(t)
                    }
                    .brandScreen()
                    .navigationTitle("آيات تتلى")
                } detail: {
                    NavigationStack { screen(tab) }
                        .safeAreaInset(edge: .bottom) { MiniPlayerBar() }
                }
            } else {
                // The system tab bar is hidden; the site's floating bar (FloatingTabBar) replaces it.
                // TabView still holds each section's navigation state.
                TabView(selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        NavigationStack { screen(t) }
                            .toolbar(.hidden, for: .tabBar)
                            .tag(t)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 6) {
                        MiniPlayerBar()
                        FloatingTabBar(selection: $tab)
                    }
                }
            }
        }
        .sheet(isPresented: $audio.nowPlayingSheet) { NowPlayingSheet() }
    }

    @ViewBuilder private func screen(_ t: Tab) -> some View {
        switch t {
        case .home: HomeView()
        case .quran: QuranView()
        case .studio: StudioView()
        case .azkar: AzkarHadithView()
        case .more: ToolsView()
        }
    }
}

struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text("قيد البناء"))
            .brandScreen()
            .navigationTitle(title)
    }
}

/// Applies the appearance preference and shows onboarding on first launch.
/// Debug builds accept `-screen <name>` (used by CI to screenshot each screen).
struct StartView: View {
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(Prefs.onboardingDone) private var onboardingDone = false

    var body: some View {
        content
            .modifier(RouteSheet())
            #if DEBUG
            // CI: `-link <url>` follows a deep link at launch (simctl openurl shows a system prompt).
            .task {
                if let s = UserDefaults.standard.string(forKey: "link"), let url = URL(string: s) {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    Router.shared.open(url)
                }
            }
            #endif
            .preferredColorScheme(Appearance(rawValue: appearance)?.scheme)
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        if let s = UserDefaults.standard.string(forKey: "screen") {
            if s == "home" { RootView() } else { NavigationStack { DebugScreen.view(s) } }
        } else {
            normal
        }
        #else
        normal
        #endif
    }

    @ViewBuilder private var normal: some View {
        if onboardingDone { RootView() } else { OnboardingView() }
    }
}

#if DEBUG
enum DebugScreen {
    static let all = ["home", "tools", "prayer", "qibla", "zakat", "hijri", "occasions", "mosques", "settings", "onboarding", "quran", "reader", "azkar", "azkar-session", "tasbih", "library", "home-feed", "khatma", "card", "studio", "qada", "sawm", "clip", "duas", "hadith", "checker", "guide", "radio", "hifz", "kids"]

    @ViewBuilder static func view(_ name: String) -> some View {
        switch name {
        case "prayer": PrayerTimesView()
        case "qibla": QiblaView()
        case "zakat": ZakatView()
        case "kids": KidsJuzAmmaView()
        case "hijri": HijriView()
        case "occasions": OccasionsView()
        case "mosques": MosquesView()
        case "settings": SettingsView()
        case "onboarding": OnboardingView()
        case "quran": QuranView()
        case "reader": MushafReader(startPage: 2)
        case "azkar": AzkarView()
        case "azkar-session":
            if let c = (try? ContentLibrary.shared.store?.azkarCategories())?.first { AzkarSession(category: c) }
        case "tasbih": TasbihView()
        case "library": LibraryView()
        case "home-feed": HomeView()
        case "khatma": KhatmaView()
        case "card": AyahCardView()
        case "studio": StudioView()
        case "qada": QadaView()
        case "sawm": SawmView()
        case "clip": ClipMakerView()
        case "duas": DuasView()
        case "hadith": HadithView()
        case "checker": HadithCheckerView()
        case "guide": PrayerGuideView()
        case "radio": RadioView()
        case "hifz": HifzTestView()
        case "tajweed": TajweedView()
        case "wbw": WordByWordView()
        case "ruqya": RuqyaView()
        case "asma": AsmaView()
        case "downloads": DownloadsView().navigationTitle("التنزيلات")
        case "azkar-hub": AzkarHadithView()
        case "topics": TopicsView()
        case "juz": JuzListView()
        case "status": StatusSourceView()
        case "home-mid": ScrollView { VStack(spacing: 32) { HomeProducts(); HomeSources(); HomeSteps() }.padding(16) }.brandScreen()
        case "home-low": ScrollView { VStack(spacing: 32) { HomeFeatures(); HomeStats(); HomeClosing() }.padding(16) }.brandScreen()
        case "topic": if let t = ContentLibrary.shared.topics.first { TopicView(topic: t) } else { TopicsView() }
        case "now-playing": NowPlayingSheet()
        default: ToolsView()
        }
    }
}
#endif

/// The site's mobile bar (.foot-tabbar, floating variant): a white rounded card with a fine border
/// and soft shadow; the current section is filled with the green gradient.
struct FloatingTabBar: View {
    @Binding var selection: Tab
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                let on = t == selection
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selection = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: on ? t.symbol + ".fill" : t.symbol)
                            .font(.system(size: 18, weight: .medium))
                        if !typeSize.isAccessibilitySize {
                            Text(t.title).font(.ui(size: 11, on ? .semibold : .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(on ? Color.white : Brand.muted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if on { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Brand.siteGradient) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.longTitle)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(5)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x0F1F17).opacity(0.14), radius: 18, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: 560)
        .accessibilityElement(children: .contain)
    }
}
