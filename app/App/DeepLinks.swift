import SwiftUI
import UserNotifications
import Observation

/// Deep links (docs/APP_ARCHITECTURE.md): ayattla://ayah/{s}/{a}, ayattla://studio/new?type=video|card&s=&a=&b=,
/// ayattla://tools/{id}, ayattla://azkar/{chapter title}, ayattla://khatma. Reminders carry one in
/// userInfo["link"], so tapping a reminder opens its screen.
enum Route: Equatable, Identifiable {
    case ayah(surah: Int, ayah: Int)
    case newClip(surah: Int, from: Int, to: Int)
    case newCard(surah: Int, from: Int, to: Int)
    case tool(ToolItem)
    case azkar(String)
    case khatma

    var id: String {
        switch self {
        case .ayah(let s, let a): "ayah-\(s)-\(a)"
        case .newClip(let s, let a, let b): "clip-\(s)-\(a)-\(b)"
        case .newCard(let s, let a, let b): "card-\(s)-\(a)-\(b)"
        case .tool(let t): "tool-\(t.rawValue)"
        case .azkar(let c): "azkar-\(c)"
        case .khatma: "khatma"
        }
    }

    static let scheme = "ayattla"

    /// Tool ids as on the site (/tools/{id}) and in the app.
    static let toolIDs: [String: ToolItem] = [
        "azkar": .azkar, "tasbih": .tasbih, "duas": .duas, "prayer-times": .prayer, "qibla": .qibla, "hijri": .hijri,
        "occasions": .occasions, "zakat": .zakat, "qada-salah": .qada, "sawm-tracker": .sawm, "nearby-mosques": .mosques,
        "hadith": .hadith, "hadith-checker": .hadithChecker, "prayer-guide": .prayerGuide,
    ]

    static func parse(_ url: URL) -> Route? {
        guard url.scheme == scheme, let host = url.host() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let q = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .compactMap { i in i.value.map { (i.name, $0) } })
        func int(_ k: String) -> Int? { q[k].flatMap(Int.init) }
        let lib = ContentLibrary.shared
        func valid(_ s: Int, _ a: Int) -> Bool { (lib.surah(s)?.ayahCount ?? (lib.isReady ? 0 : 286)) >= a && a >= 1 && (1...114).contains(s) }

        switch host {
        case "ayah":
            guard parts.count == 2, let s = Int(parts[0]), let a = Int(parts[1]), valid(s, a) else { return nil }
            return .ayah(surah: s, ayah: a)
        case "studio":
            guard parts.first == "new", let s = int("s"), let a = int("a"), valid(s, a) else { return nil }
            let b = max(a, int("b") ?? a)
            switch q["type"] {
            case "card": return .newCard(surah: s, from: a, to: b)
            default: return .newClip(surah: s, from: a, to: b)
            }
        case "tools":
            guard let id = parts.first, let t = toolIDs[id] ?? ToolItem(rawValue: id) else { return nil }
            return .tool(t)
        case "azkar":
            guard let title = parts.first, !title.isEmpty else { return .tool(.azkar) }
            return .azkar(title)
        case "khatma":
            return .khatma
        default:
            return nil
        }
    }

    static func ayahLink(_ s: Int, _ a: Int) -> String { "\(scheme)://ayah/\(s)/\(a)" }
    static func azkarLink(_ title: String) -> String {
        "\(scheme)://azkar/\(title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .ayah(let s, let a):
            let page = (try? ContentLibrary.shared.store?.ayat(surah: s, from: a, to: a))?.first?.page ?? 1
            MushafReader(startPage: page, focus: .init(surah: s, ayah: a))
        case .newClip(let s, let a, let b): ClipMakerView(surah: s, from: a, to: b)
        case .newCard(let s, let a, let b): AyahCardView(surah: s, from: a, to: b)
        case .tool(let t): t.destination
        case .azkar(let title):
            if let c = ContentLibrary.shared.azkarCategories.first(where: { $0.title == title }) {
                AzkarSession(category: c)
            } else {
                AzkarView()
            }
        case .khatma: KhatmaView()
        }
    }
}

/// Holds the route to show; set by onOpenURL and by tapping a reminder.
@Observable
final class Router {
    static let shared = Router()
    var pending: Route?

    func open(_ url: URL) {
        // From the Live Activity: show the full player rather than a screen.
        if url.scheme == Route.scheme, url.host() == "now-playing" {
            if AudioCenter.shared.active != nil { AudioCenter.shared.nowPlayingSheet = true }
            return
        }
        if let r = Route.parse(url) { pending = r }
    }
}

/// Receives reminder taps (and shows reminders while the app is open).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let s = response.notification.request.content.userInfo["link"] as? String, let url = URL(string: s) {
            await MainActor.run { Router.shared.open(url) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Shows a routed screen in a sheet over whatever tab is open.
struct RouteSheet: ViewModifier {
    @Bindable var router = Router.shared

    func body(content: Content) -> some View {
        content
            .onOpenURL { Router.shared.open($0) }
            .sheet(item: $router.pending) { route in
                NavigationStack {
                    route.destination
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { router.pending = nil } }
                        }
                }
            }
    }
}
