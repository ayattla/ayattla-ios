import SwiftUI

// STATUS: skeleton written without Xcode; not compiled yet.
@main
struct AyatTutlaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
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
