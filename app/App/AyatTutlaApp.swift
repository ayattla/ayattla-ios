import SwiftUI

@main
struct AyatTutlaApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Num.locale)
                .tint(Brand.primary)
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
        default: PlaceholderScreen(title: t.title)
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

/// Debug builds accept `-screen <name>` (used by CI to screenshot each screen).
struct StartView: View {
    var body: some View {
        #if DEBUG
        if let s = UserDefaults.standard.string(forKey: "screen"), s != "home" {
            NavigationStack { DebugScreen.view(s) }
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }
}

#if DEBUG
enum DebugScreen {
    static let all = ["home", "tools", "prayer", "qibla", "zakat", "hijri", "occasions"]

    @ViewBuilder static func view(_ name: String) -> some View {
        switch name {
        case "prayer": PrayerTimesView()
        case "qibla": QiblaView()
        case "zakat": ZakatView()
        case "hijri": HijriView()
        case "occasions": OccasionsView()
        default: ToolsView()
        }
    }
}
#endif
