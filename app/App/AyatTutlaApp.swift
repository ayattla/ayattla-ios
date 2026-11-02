import SwiftUI
import AyatDesign

@main
struct AyatTutlaApp: App {
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            StartView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Num.locale)
                .tint(Brand.primary)
        }
        .onChange(of: phase) { _, p in
            if p == .active { Task { await Reminders.reschedule() } }
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case home, quran, studio, library, tools
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "الرئيسية"
        case .quran: "القرآن"
        case .studio: "الاستوديو"
        case .library: "مكتبتي"
        case .tools: "الأدوات"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .quran: "book"
        case .studio: "play.rectangle"
        case .library: "books.vertical"
        case .tools: "square.grid.2x2"
        }
    }
}

/// iPhone: TabView. iPad: NavigationSplitView with the same sections (see docs/APP_ARCHITECTURE.md).
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var size
    @State private var tab: Tab = .home

    var body: some View {
        if size == .regular {
            NavigationSplitView {
                List(Tab.allCases, selection: Binding(get: { tab }, set: { tab = $0 ?? .home })) { t in
                    Label(t.title, systemImage: t.symbol).tag(t)
                }
                .navigationTitle("آيات تتلى")
            } detail: {
                NavigationStack { screen(tab) }
            }
        } else {
            TabView(selection: $tab) {
                ForEach(Tab.allCases) { t in
                    NavigationStack { screen(t) }
                        .tabItem { Label(t.title, systemImage: t.symbol) }
                        .tag(t)
                }
            }
        }
    }

    @ViewBuilder private func screen(_ t: Tab) -> some View {
        switch t {
        case .tools: ToolsView()
        case .home: HomeView()
        case .quran: QuranView()
        case .library: LibraryView()
        case .studio: StudioView()
        }
    }
}

struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text("قيد البناء"))
            .navigationTitle(title)
    }
}

/// Applies the appearance preference and shows onboarding on first launch.
/// Debug builds accept `-screen <name>` (used by CI to screenshot each screen).
struct StartView: View {
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(Prefs.onboardingDone) private var onboardingDone = false

    var body: some View {
        content.preferredColorScheme(Appearance(rawValue: appearance)?.scheme)
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
    static let all = ["home", "tools", "prayer", "qibla", "zakat", "hijri", "occasions", "mosques", "settings", "onboarding", "quran", "reader", "azkar", "azkar-session", "tasbih", "library", "home-feed", "khatma", "card", "studio", "qada", "sawm", "clip"]

    @ViewBuilder static func view(_ name: String) -> some View {
        switch name {
        case "prayer": PrayerTimesView()
        case "qibla": QiblaView()
        case "zakat": ZakatView()
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
        default: ToolsView()
        }
    }
}
#endif
