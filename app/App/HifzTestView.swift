import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Hifz test (/tools/hifz-test)

/// Hides a share of the words (25٪، 50٪ or all) in a range of ayat; tap a hidden word to reveal it.
struct HifzTestView: View {
    enum Level: Double, CaseIterable, Identifiable {
        case quarter = 0.25, half = 0.5, all = 1
        var id: Double { rawValue }
        var title: String {
            switch self {
            case .quarter: "٢٥٪"
            case .half: "٥٠٪"
            case .all: "الكل"
            }
        }
    }

    @State private var surah = 1
    @State private var from = 1
    @State private var to = 7
    @State private var level = Level.half
    @State private var started = false
    @State private var hidden: Set<String> = []
    private let lib = ContentLibrary.shared

    var body: some View {
        Form {
Group {
            Section("الآيات") {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Stepper("من آية \(Num.int(from))", value: $from, in: 1...ayahCount)
                Stepper("إلى آية \(Num.int(to))", value: $to, in: from...ayahCount)
                Picker("نسبة الإخفاء", selection: $level) { ForEach(Level.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                Button(started ? "اختبار جديد" : "ابدأ الاختبار") { start() }
                    .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
            }
            if started {
                Section {
                    ForEach(ayat, id: \.id) { a in
                        WordFlow(words: Self.words(a.textUthmani), key: a.id, hidden: $hidden, marker: QuranText.marker(a.ayah))
                    }
                    Button("اكشف الكل") { hidden = [] }.frame(maxWidth: .infinity)
                } footer: {
                    Text("اضغط على الكلمة المخفية لكشفها. المخفي الآن: \(Num.int(hidden.count))")
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("اختبار الحفظ")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: surah) { _, s in from = 1; to = min(lib.surah(s)?.ayahCount ?? 1, 7); started = false }
        .onChange(of: from) { _, f in if to < f { to = f } }
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }
    private var ayat: [Ayah] { (try? lib.store?.ayat(surah: surah, from: from, to: to)) ?? [] }

    static func words(_ text: String) -> [String] { text.split(separator: " ").map(String.init) }

    /// Picks which words to hide; pause marks (single characters like ۖ) are never hidden.
    static func pick(_ keys: [String], words: [String], share: Double, seed: Int) -> Set<String> {
        var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: seed))
        let candidates = zip(keys, words).filter { $0.1.unicodeScalars.count > 1 }.map(\.0)
        let n = share >= 1 ? candidates.count : Int((Double(candidates.count) * share).rounded())
        return Set(candidates.shuffled(using: &rng).prefix(n))
    }

    private func start() {
        var keys: [String] = [], words: [String] = []
        for a in ayat { for (i, w) in Self.words(a.textUthmani).enumerated() { keys.append("\(a.id)#\(i)"); words.append(w) } }
        hidden = Self.pick(keys, words: words, share: level.rawValue, seed: Int(Date().timeIntervalSince1970))
        started = true
    }
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Words of one ayah, right to left, wrapping; hidden words show as blanks.
struct WordFlow: View {
    let words: [String]
    let key: String
    @Binding var hidden: Set<String>
    let marker: String

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                let k = "\(key)#\(i)"
                if hidden.contains(k) {
                    Button { hidden.remove(k) } label: {
                        Text(w).font(.custom(ContentLibrary.mushafFont, size: 22)).hidden()
                            .padding(.horizontal, 4)
                            .background(Brand.tint, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Brand.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("كلمة مخفية، اضغط للكشف")
                } else {
                    Text(w).font(.custom(ContentLibrary.mushafFont, size: 22))
                }
            }
            Text(marker).font(.custom(ContentLibrary.mushafFont, size: 22))
        }
        .padding(.vertical, 6)
    }
}
