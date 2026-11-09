import SwiftUI
import AyatDesign

@main
struct AyatTutlaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase

    init() {
        _ = ContentLibrary.shared      // registers the bundled fonts before the first frame
        BrandAppearance.apply()
        // Media library previews and site reads go through URLSession.shared; the default cache
        // (a few MB) let thumbnails reload on every visit. Respects the servers' cache headers.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
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
/// The mushaf with a recitation playing (for the player screenshots): ayah 1:1, repeat 3, speed 1.25.
struct DebugPlayingReader: View {
    @State private var ready = false
    var body: some View {
        Group { if ready { MushafReader(startPage: 1) } else { Color.clear } }
            .onAppear {
                let lib = ContentLibrary.shared
                let p = RecitationPlayer()
                p.folder = (try? lib.store?.reciterFolders())?[Prefs.defaultReciter]
                p.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
                p.repeatEach = 3
                p.speed = 1.25
                p.play(from: .init(surah: 1, ayah: 1))
                ready = true
            }
    }
}

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
            if let c = ContentLibrary.shared.azkarCategories.first { AzkarSession(category: c) }
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
        case "home-mid": ScrollView { VStack(spacing: 32) { HomeCreateBento(); HomeMediaGallery() }.padding(16) }.brandScreen()
        case "home-low": ScrollView { HomeToolLauncher().padding(16) }.brandScreen()
        case "about": AboutAppView()
        case "faq": FAQView()
        case "media": MediaLibrarySheet(kinds: [.video, .image], initial: .video) { _ in }
        case "media-image": MediaLibrarySheet(kinds: [.image]) { _ in }
        case "clip-video": ClipMakerView(media: MediaLibrary.Ref(provider: "pixabay", mediaId: "128406", type: .video))
        case "card-photo": AyahCardView(media: MediaLibrary.Ref(provider: "pixabay", mediaId: "6604492", type: .image))
        case "text-card":
            // A dua from the content pack (never typed in), on the text card editor.
            if let c = ContentLibrary.shared.duas?.needs.first?.chapters.first, let it = c.items.first {
                TextCardView(title: "حالة", text: it.text, reference: c.name, initialRatio: .story)
            } else { DuasView() }
        case "reader-playing": DebugPlayingReader()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var pill

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                let on = t == selection
                Button {
                    guard t != selection else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) { selection = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: on ? t.symbol + ".fill" : t.symbol)
                            .font(.system(size: 18, weight: on ? .semibold : .medium))
                            .symbolEffect(.bounce, value: on && !reduceMotion)
                        if !typeSize.isAccessibilitySize {
                            Text(t.title).font(.ui(size: 11, on ? .semibold : .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(on ? Color.white : Brand.muted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Brand.siteGradient)
                                .shadow(color: Color(hex: 0x1F8A62).opacity(0.35), radius: 8, y: 4)
                                .matchedGeometryEffect(id: "selected", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.longTitle)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(6)
        .background {
            if reduceTransparency {
                shape.fill(Brand.surface)
            } else {
                shape.fill(.regularMaterial)
                shape.fill(Brand.surface.opacity(0.55))
            }
        }
        .overlay(shape.strokeBorder(Brand.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x0F1F17).opacity(0.14), radius: 18, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: 560)
        .accessibilityElement(children: .contain)
    }
}
