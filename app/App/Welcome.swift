import Foundation

/// First-run answers («تجربة البداية»): what the user wants from the app, the content they like, how
/// they listen and which reminders they chose. Kept only on the device; used to order the home screen
/// and suggest tools — never to hide or lock any tool. Same ids as Android (data/Welcome.kt).
enum Welcome {
    struct Choice: Identifiable, Hashable {
        let id: String
        let label: String
        let symbol: String
        var tools: [String] = []
    }

    static let uses: [Choice] = [
        .init(id: "quran", label: "قراءة القرآن الكريم", symbol: "book", tools: ["mushaf", "khatma", "journey", "search", "tajweed"]),
        .init(id: "listen", label: "الاستماع إلى القرآن والقراء", symbol: "headphones", tools: ["listen", "radio", "offline", "ruqya"]),
        .init(id: "status", label: "تصميم حالات واتساب", symbol: "sparkles", tools: ["status", "ayah-card", "hadith-card", "occasions"]),
        .init(id: "clips", label: "إنشاء مقاطع قرآنية ومشاركتها", symbol: "play.rectangle", tools: ["clip", "ayah-card", "status"]),
        .init(id: "azkar", label: "الأذكار والأدعية", symbol: "leaf", tools: ["azkar", "hisn-almuslim", "duas", "tasbih"]),
        .init(id: "hadith", label: "الأحاديث النبوية", symbol: "quote.opening", tools: ["hadith", "hadith-card", "hadith-checker"]),
        .init(id: "cards", label: "البطاقات والخلفيات الإسلامية", symbol: "photo.on.rectangle", tools: ["ayah-card", "hadith-card", "status"]),
        .init(id: "gifts", label: "الإهداءات والتهاني بالمناسبات", symbol: "gift", tools: ["status", "occasions", "ayah-card"]),
        .init(id: "tafsir", label: "التفسير والتدبر", symbol: "lightbulb", tools: ["topics", "word-by-word", "ayah-of-the-day", "tajweed"]),
        .init(id: "hifz", label: "الحفظ والتسميع", symbol: "waveform.and.mic", tools: ["hifz-plan", "tasmee", "hifz-test", "listen"]),
        .init(id: "all", label: "استكشاف جميع الأدوات", symbol: "square.grid.2x2"),
    ]

    static let likes: [Choice] = [
        .init(id: "short", label: "آيات قصيرة ومؤثرة", symbol: "quote.opening", tools: ["ayah-of-the-day", "ayah-card"]),
        .init(id: "tafsir", label: "آيات مع التفسير", symbol: "book", tools: ["topics", "word-by-word"]),
        .init(id: "audio", label: "مقاطع قرآنية صوتية", symbol: "waveform", tools: ["clip", "listen"]),
        .init(id: "designs", label: "تصاميم إسلامية جاهزة", symbol: "paintpalette", tools: ["status", "ayah-card"]),
        .init(id: "azkar", label: "أذكار الصباح والمساء", symbol: "sun.horizon", tools: ["azkar"]),
        .init(id: "hadith", label: "أحاديث وأدعية", symbol: "hands.sparkles", tools: ["hadith", "duas"]),
        .init(id: "varied", label: "محتوى متنوع", symbol: "shuffle"),
    ]

    /// Reminders offered at first run: each switches on an existing reminder.
    static let reminders: [Choice] = [
        .init(id: "morning", label: "أذكار الصباح", symbol: "sun.max"),
        .init(id: "evening", label: "أذكار المساء", symbol: "moon.stars"),
        .init(id: "journey", label: "تذكير يومي بقراءة القرآن", symbol: "chart.line.uptrend.xyaxis"),
        .init(id: "khatma", label: "ورد الختمة اليومي", symbol: "bookmark"),
        .init(id: "ayah", label: "آية اليوم كل صباح", symbol: "calendar"),
    ]

    enum Step: String, CaseIterable { case hello, uses, likes, listen, reminders, theme, done }
    static let questions: [Step] = [.uses, .likes, .listen, .reminders, .theme]

    private static var d: UserDefaults { .standard }
    static let stepKey = "welcome.step"

    /// Run once per install: people who set up an older version are not asked (they get the stats note).
    static func migrate() {
        guard d.object(forKey: "welcome.checked") == nil else { return }
        d.set(true, forKey: "welcome.checked")
        if d.bool(forKey: Prefs.onboardingDone) { d.set(true, forKey: "welcome.upgraded") }
    }

    static var upgraded: Bool { d.bool(forKey: "welcome.upgraded") }
    static var statsNoticeDue: Bool { upgraded && !d.bool(forKey: "welcome.statsNotice") }
    static func statsNoticeSeen() { d.set(true, forKey: "welcome.statsNotice") }

    static var step: Step { Step(rawValue: d.string(forKey: stepKey) ?? "") ?? .hello }
    static func save(step: Step) { d.set(step.rawValue, forKey: stepKey) }

    static var uses_: Set<String> { Set(d.stringArray(forKey: "welcome.uses") ?? []) }
    static var likes_: Set<String> { Set(d.stringArray(forKey: "welcome.likes") ?? []) }
    static var reminders_: Set<String> { Set(d.stringArray(forKey: "welcome.reminders") ?? []) }
    static var listen_: String { d.string(forKey: "welcome.listen") ?? "" }
    static func save(uses v: Set<String>) { d.set(Array(v), forKey: "welcome.uses") }
    static func save(likes v: Set<String>) { d.set(Array(v), forKey: "welcome.likes") }
    static func save(reminders v: Set<String>) { d.set(Array(v), forKey: "welcome.reminders") }
    static func save(listen v: String) { d.set(v, forKey: "welcome.listen") }

    /// Tools suggested by the answers, in the order chosen (uses first, then content).
    static var suggested: [String] {
        let u = uses_, l = likes_
        var out: [String] = []
        for id in uses.filter({ u.contains($0.id) }).flatMap(\.tools) + likes.filter({ l.contains($0.id) }).flatMap(\.tools) where !out.contains(id) { out.append(id) }
        return out
    }

    /// Uses the user picked, in the list's order (for the home «مختارات لك» rows).
    static var pickedUses: [Choice] { let u = uses_; return uses.filter { u.contains($0.id) && !$0.tools.isEmpty } }

    /// The home order before any manual arrangement: the original order with the sections matching the
    /// interests moved up after the prayer card. Nothing is hidden; «تخصيص الرئيسية» always replaces it.
    static func homeOrder(_ base: [HomeSectionID]) -> [HomeSectionID] {
        let u = uses_
        var boost: [HomeSectionID] = [.forYou]
        if u.contains("quran") || u.contains("hifz") { boost += [.journey, .wird] }
        if !u.isDisjoint(with: ["status", "clips", "cards", "gifts"]) { boost += [.create, .presets] }
        if u.contains("azkar") { boost.append(.dhikr) }
        if u.contains("cards") || u.contains("status") { boost.append(.gallery) }
        if u.contains("tafsir") { boost.append(.ayah) }
        if u.contains("all") { boost.append(.tools) }
        var out: [HomeSectionID] = [.prayer, .daily]
        for s in boost + base where !out.contains(s) { out.append(s) }
        return out
    }
}

/// Anonymous usage counts, to learn which tools and steps people use and where they stop.
///
/// Privacy by design (privacy policy, «الإحصاءات المجهولة»): only counters of fixed event names with
/// fixed keys (a tool id, a step, an answer id) per day; no user or device identifier, no names,
/// numbers, location, text or content. Summed on the phone, sent in one small batch at most every few
/// hours; the server keeps daily totals and no IP addresses. On by default with a switch in Settings;
/// turning it off deletes anything unsent. Same events as Android (data/Stats.kt).
enum Stats {
    static let endpoint = URL(string: "https://ayattla.com/api/stats")!
    static let enabledKey = "stats.enabled"
    private static let pendingKey = "stats.pending"
    private static let sentKey = "stats.sent"
    private static var d: UserDefaults { .standard }

    static var enabled: Bool { d.object(forKey: enabledKey) == nil ? true : d.bool(forKey: enabledKey) }
    static func setEnabled(_ on: Bool) {
        d.set(on, forKey: enabledKey)
        if !on { d.removeObject(forKey: pendingKey) }
    }

    static func clean(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.lowercased().unicodeScalars where out.count < 48 {
            if ("a"..."z").contains(u) || ("0"..."9").contains(u) || u == "_" || u == ":" || u == "-" { out.append(u) }
        }
        return String(out)
    }

    private static var day: String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Counts one event. [key] must come from the app's own ids (tool, step, choice) — never user text.
    static func event(_ name: String, _ key: String = "") {
        guard enabled else { return }
        var p = (d.dictionary(forKey: pendingKey) as? [String: Int]) ?? [:]
        p["\(day)|\(clean(name))|\(clean(key))", default: 0] += 1
        d.set(p, forKey: pendingKey)
    }

    /// The pending batch: {"v":1,"platform":"ios","version":"x","days":{"date":{"name|key":n}}}.
    static func batch(version: String) -> [String: Any]? {
        let p = (d.dictionary(forKey: pendingKey) as? [String: Int]) ?? [:]
        guard !p.isEmpty else { return nil }
        var days: [String: [String: Int]] = [:]
        for (k, n) in p {
            let parts = k.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { continue }
            days[parts[0], default: [:]][parts[1] + "|" + parts[2]] = n
        }
        return ["v": 1, "platform": "ios", "version": version, "days": days]
    }

    /// Sends what was counted (enabled, at most every 6 hours); subtracted once the server accepts it.
    static func flush(force: Bool = false) async {
        guard enabled, force || Date().timeIntervalSince1970 - d.double(forKey: sentKey) > 6 * 3600 else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let sent = (d.dictionary(forKey: pendingKey) as? [String: Int]) ?? [:]
        guard let body = batch(version: version), let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: endpoint, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
        await MainActor.run {
            var p = (d.dictionary(forKey: pendingKey) as? [String: Int]) ?? [:]
            for (k, n) in sent { let left = (p[k] ?? 0) - n; p[k] = left > 0 ? left : nil }
            d.set(p, forKey: pendingKey)
            d.set(Date().timeIntervalSince1970, forKey: sentKey)
        }
    }
}
