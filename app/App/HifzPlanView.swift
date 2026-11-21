import SwiftUI
import AyatDesign
import AyatContent

// MARK: - Hifz plan with spaced review («خطة الحفظ والمراجعة»)

/// A new portion each day in the chosen order; every memorised portion comes back for review after
/// one day, then at longer gaps as it is rated well, and back to one day when it is hard.
/// Kept on the device (same rules as the Android app).
struct HifzPlan: Codable, Equatable {
    struct Portion: Codable, Hashable { var surah: Int; var from: Int; var to: Int; var count: Int { to - from + 1 } }
    struct Review: Codable, Equatable { var portion: Portion; var interval: Int; var due: Int; var reps: Int }

    var forward: Bool
    var daily: Int
    var nextSurah: Int
    var nextAyah = 1
    var lastNewDay = -1
    var reviews: [Review] = []

    static func today(_ date: Date = .now) -> Int {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let midnight = Calendar(identifier: .gregorian).date(from: c) ?? date
        return Int(midnight.timeIntervalSince1970 / 86_400 + 0.5)
    }

    func next(ayahCount: (Int) -> Int) -> Portion? {
        guard (1...114).contains(nextSurah) else { return nil }
        return Portion(surah: nextSurah, from: nextAyah, to: min(ayahCount(nextSurah), nextAyah + daily - 1))
    }

    var learnedToday: Bool { lastNewDay == Self.today() }
    var memorised: Int { reviews.reduce(0) { $0 + $1.portion.count } }
    var due: [Review] { reviews.filter { $0.due <= Self.today() }.sorted { $0.due < $1.due } }

    mutating func learned(ayahCount: (Int) -> Int) {
        guard let p = next(ayahCount: ayahCount) else { return }
        if p.to < ayahCount(p.surah) { nextAyah = p.to + 1 } else { nextSurah += forward ? 1 : -1; nextAyah = 1 }
        lastNewDay = Self.today()
        reviews.append(Review(portion: p, interval: 1, due: Self.today() + 1, reps: 0))
    }

    /// 0 hard → tomorrow; 1 fair → 1.5× the gap; 2 strong → 2.5× the gap (at most 60 days).
    static func nextInterval(_ interval: Int, grade: Int) -> Int {
        let n: Int
        switch grade {
        case 0: n = 1
        case 1: n = max(2, Int(Double(interval) * 1.5))
        default: n = max(3, Int(Double(interval) * 2.5))
        }
        return min(n, 60)
    }

    mutating func rate(_ r: Review, grade: Int) {
        guard let i = reviews.firstIndex(where: { $0.portion == r.portion }) else { return }
        let n = Self.nextInterval(reviews[i].interval, grade: grade)
        reviews[i].interval = n; reviews[i].due = Self.today() + n; reviews[i].reps += 1
    }

    func encoded() -> String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "" }
    static func decode(_ s: String) -> HifzPlan? { try? JSONDecoder().decode(HifzPlan.self, from: Data(s.utf8)) }
}

struct HifzPlanView: View {
    @AppStorage("hifz.plan") private var stored = ""
    @State private var forward = false
    @State private var daily = 3
    @State private var confirmReset = false
    private let lib = ContentLibrary.shared

    private var plan: HifzPlan? { HifzPlan.decode(stored) }
    private func count(_ s: Int) -> Int { lib.surah(s)?.ayahCount ?? 1 }
    private func update(_ f: (inout HifzPlan) -> Void) {
        guard var p = plan else { return }
        f(&p); stored = p.encoded()
    }

    var body: some View {
        Form {
            ToolHeadSection(id: "hifz-plan")
            if let p = plan { planSections(p) } else { startSection }
        }
        .brandScreen()
        .navigationTitle("خطة الحفظ والمراجعة")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var startSection: some View {
        Section {
            Picker("الترتيب", selection: $forward) {
                Text("من سورة الناس").tag(false)
                Text("من الفاتحة").tag(true)
            }.pickerStyle(.segmented)
            Picker("الحفظ اليومي", selection: $daily) {
                ForEach([1, 3, 5, 10], id: \.self) { Text("\(Num.int($0)) آيات").tag($0) }
            }
            Button("ابدأ الخطة") {
                stored = HifzPlan(forward: forward, daily: daily, nextSurah: forward ? 1 : 114).encoded()
            }
            .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
        }
    }

    @ViewBuilder private func planSections(_ p: HifzPlan) -> some View {
        Section {
            Text("حفظت \(Num.int(p.memorised)) آية").font(.ui(.title3, .bold)).foregroundStyle(Brand.primaryInk)
            ProgressView(value: Double(p.memorised), total: 6236).tint(Brand.accent)
            Text("مراجعات اليوم: \(Num.int(p.due.count))").font(.ui(.subheadline)).foregroundStyle(.secondary)
        }
        Section("حفظ اليوم") {
            if let u = p.next(ayahCount: count) {
                if p.learnedToday {
                    Text("أنجزت حفظ اليوم ✓ المقطع التالي غدا.")
                    portionText(u)
                } else {
                    portionText(u)
                    Button("حفظته") { update { $0.learned(ayahCount: count) }; Journey.shared.hifzDone() }
                        .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
                }
            } else {
                Text("أتممت القرآن كاملا في هذه الخطة. بارك الله فيك.")
            }
        }
        Section("المراجعة") {
            if p.due.isEmpty { Text("لا مراجعة مستحقة اليوم.").foregroundStyle(.secondary) }
            ForEach(p.due, id: \.portion) { r in
                VStack(alignment: .leading, spacing: 8) {
                    portionText(r.portion)
                    HStack {
                        gradeButton("صعب", r, 0)
                        gradeButton("متوسط", r, 1)
                        gradeButton("أتقنته", r, 2)
                    }
                }
            }
        }
        Section {
            Picker("الحفظ اليومي", selection: Binding(get: { p.daily }, set: { v in update { $0.daily = v } })) {
                ForEach([1, 3, 5, 10], id: \.self) { Text("\(Num.int($0)) آيات").tag($0) }
            }
            Button(confirmReset ? "اضغط مرة أخرى لحذف الخطة" : "إعادة بدء الخطة", role: .destructive) {
                if confirmReset { stored = "" } else { confirmReset = true }
            }
        }
    }

    private func gradeButton(_ title: String, _ r: HifzPlan.Review, _ g: Int) -> some View {
        Button(title) { update { $0.rate(r, grade: g) }; Journey.shared.hifzDone() }
            .buttonStyle(.bordered).tint(g == 2 ? Brand.green : Brand.goldInk)
            .frame(maxWidth: .infinity)
    }

    private func portionText(_ u: HifzPlan.Portion) -> some View {
        let ayat = (try? lib.store?.ayat(surah: u.surah, from: u.from, to: u.to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let name = lib.surah(u.surah)?.shortName ?? Num.int(u.surah)
        return VStack(alignment: .leading, spacing: 6) {
            Text("سورة \(name) · \(Num.int(u.from))–\(Num.int(u.to))").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.goldInk)
            Text(text).font(.custom(ContentLibrary.mushafFont, size: 22)).lineSpacing(10)
            NavigationLink { TasmeeView(surah: u.surah, from: u.from, to: min(u.to, u.from + TasmeeView.maxAyat - 1)) } label: {
                Label("سمّع بصوتك", systemImage: "waveform.and.mic").font(.ui(.subheadline, .semibold))
            }
            .buttonStyle(.bordered).tint(Brand.primaryInk)
        }
    }
}

// MARK: - Kids quiz («مسابقة جزء عم»)

/// Questions built only from the mushaf text: «أكمل الآية» and «من أي سورة؟». No wording is generated.
struct KidsQuizQuestion: Equatable {
    let prompt: String
    let surah: Int
    let ayah: Int
    let options: [String]
    let answer: Int
    let completes: Bool

    static func words(_ t: String) -> [String] { t.split(separator: " ").map(String.init) }

    /// Cuts between words, never just before a pause mark (a word without Arabic letters).
    static func cut(_ w: [String]) -> Int {
        var c = w.count / 2
        while c < w.count - 1, !w[c].unicodeScalars.contains(where: { (0x0621...0x064A).contains($0.value) }) { c += 1 }
        return c
    }

    static func make(pool: [Int], lib: ContentLibrary) -> KidsQuizQuestion? {
        let surahs = pool.isEmpty ? KidsProgress.surahs : pool
        func ayat(_ s: Int) -> [Ayah] {
            ((try? lib.store?.ayat(surah: s, from: 1, to: 999)) ?? []).filter { words($0.textUthmani).count >= 4 }
        }
        guard let s = surahs.randomElement(), let a = ayat(s).randomElement() else { return nil }
        if Bool.random() {
            let w = words(a.textUthmani), c = cut(w)
            let right = w[c...].joined(separator: " ")
            var wrong: [String] = []
            for _ in 0..<30 where wrong.count < 2 {
                guard let o = KidsProgress.surahs.randomElement().flatMap({ ayat($0).randomElement() }) else { continue }
                let ow = words(o.textUthmani)
                let tail = ow[cut(ow)...].joined(separator: " ")
                if tail != right, !wrong.contains(tail) { wrong.append(tail) }
            }
            let opts = (wrong + [right]).shuffled()
            return .init(prompt: w[..<c].joined(separator: " ") + " …", surah: s, ayah: a.ayah, options: opts,
                         answer: opts.firstIndex(of: right) ?? 0, completes: true)
        } else {
            let right = lib.surah(s)?.shortName ?? ""
            let wrong = KidsProgress.surahs.filter { $0 != s }.shuffled().prefix(2).map { lib.surah($0)?.shortName ?? "" }
            let opts = (wrong + [right]).shuffled()
            return .init(prompt: a.textUthmani, surah: s, ayah: a.ayah, options: opts,
                         answer: opts.firstIndex(of: right) ?? 0, completes: false)
        }
    }
}

struct KidsQuizView: View {
    @AppStorage("kids.progress") private var stored = ""
    @State private var q: KidsQuizQuestion?
    @State private var picked: Int?
    @State private var score = 0
    @State private var total = 0
    private let lib = ContentLibrary.shared

    private var pool: [Int] { Array(KidsProgress.decode(stored).done) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("النتيجة: \(Num.int(score)) من \(Num.int(total))").font(.ui(.headline)).foregroundStyle(Brand.primaryInk)
                if let q {
                    VStack(spacing: 8) {
                        Text(q.completes ? "أكمل الآية" : "من أي سورة هذه الآية؟").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.goldInk)
                        Text(q.prompt).font(.custom(ContentLibrary.mushafFont, size: 24)).multilineTextAlignment(.center).lineSpacing(10)
                    }
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Brand.surface, in: RoundedRectangle(cornerRadius: Brand.radiusCard))
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, o in
                        Button { choose(i) } label: {
                            Text(o).font(q.completes ? Font.custom(ContentLibrary.mushafFont, size: 20) : Font.ui(.headline))
                                .frame(maxWidth: .infinity, minHeight: Brand.minTap).padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(picked != nil && i == q.answer ? Brand.green : Brand.primaryInk)
                        .disabled(picked != nil && i != q.answer)
                    }
                    if let p = picked {
                        Text(p == q.answer ? "أحسنت! ★" : "الجواب الصحيح مظلل. سورة \(lib.surah(q.surah)?.shortName ?? "") الآية \(Num.int(q.ayah)).")
                            .font(.ui(.headline))
                        Button("السؤال التالي") { next() }
                            .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
                            .background(Brand.goldGradient, in: Capsule()).foregroundStyle(Brand.primary)
                    }
                }
            }
            .padding(16)
        }
        .brandScreen()
        .navigationTitle("مسابقة جزء عم")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if q == nil { next() } }
    }

    private func choose(_ i: Int) {
        guard picked == nil, let q else { return }
        picked = i; total += 1
        if i == q.answer { score += 1 }
    }

    private func next() { q = KidsQuizQuestion.make(pool: pool, lib: lib); picked = nil }
}
