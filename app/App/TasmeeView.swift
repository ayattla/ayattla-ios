import SwiftUI
import AyatContent
import AyatDesign

/// «التسميع الذكي»: the ayat are hidden and appear word by word as the user recites them from memory.
/// The device's own speech recognition listens; words skipped or heard differently are marked
/// «راجع هذه الكلمة» (never «خطأ»), because recognition is approximate. The text shown is always the
/// mushaf's own text from the pack.
struct TasmeeView: View {
    static let maxAyat = 30
    /// Short surahs offered first (the trial started with Juz Amma).
    private static let quick = [1, 112, 113, 114, 108, 103, 97, 93]

    @State private var surah: Int
    @State private var from: Int
    @State private var to: Int
    @State private var hidden = true
    @State private var listener = SpeechListener()
    @State private var stream: [String] = []
    @State private var consumed = 0
    @State private var counted = false
    private let lib = ContentLibrary.shared

    init(surah: Int = 112, from: Int = 1, to: Int? = nil) {
        let count = ContentLibrary.shared.surah(surah)?.ayahCount ?? 1
        _surah = State(initialValue: surah)
        _from = State(initialValue: min(max(from, 1), count))
        _to = State(initialValue: min(to ?? min(count, 10), count, from + Self.maxAyat - 1))
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }
    private var ayat: [Ayah] { (try? lib.store?.ayat(surah: surah, from: from, to: min(to, from + Self.maxAyat - 1))) ?? [] }
    /// Recited words of the passage: (ayah index, token index, comparison key).
    private var words: [(Int, Int, String)] {
        ayat.enumerated().flatMap { ai, a in
            let t = Recite.tokens(a.textUthmani)
            return Recite.wordIndexes(t).map { (ai, $0, Recite.key(t[$0])) }
        }
    }
    private var progress: Recite.Progress {
        Recite.align(words.map(\.2), stream + Recite.heardKeys(listener.partial))
    }

    var body: some View {
        let ws = words
        let p = progress
        Form {
            ToolHeadSection(id: "tasmee")
            Section("المقطع") {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.quick, id: \.self) { s in
                            Button(lib.surah(s)?.shortName ?? "") { surah = s }
                                .buttonStyle(.bordered).tint(s == surah ? Brand.primary : Brand.primaryInk)
                        }
                    }
                }
                Stepper("من آية \(Num.int(from))", value: $from, in: 1...ayahCount)
                Stepper("إلى آية \(Num.int(to))", value: $to, in: from...min(ayahCount, from + Self.maxAyat - 1))
            }

            Section {
                Text(passage(ws, p)).font(.custom(ContentLibrary.mushafFont, size: 24)).lineSpacing(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("نص التسميع")
                Text("\(Num.int(p.revealed)) من \(Num.int(ws.count)) كلمة").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                    .frame(maxWidth: .infinity)
            } header: {
                HStack {
                    Text("سورة \(lib.surah(surah)?.shortName ?? "") · \(Num.int(from))–\(Num.int(to))")
                    Spacer()
                    Button(hidden ? "اعرض الآيات" : "أخفِ الآيات") { hidden.toggle() }.font(.ui(.footnote, .semibold))
                }
            }

            if p.done && !ws.isEmpty {
                Section {
                    Text(p.review.isEmpty ? "أتممت التسميع، بارك الله فيك" : "أتممت التسميع")
                        .font(.ui(.headline)).foregroundStyle(Brand.primaryInk).frame(maxWidth: .infinity)
                    if !p.review.isEmpty {
                        Text("راجع هذه الكلمات في المصحف:").font(.ui(.subheadline))
                        ForEach(p.review, id: \.self) { i in
                            let a = ayat[ws[i].0]
                            Text("\(Recite.tokens(a.textUthmani)[ws[i].1])  ·  آية \(Num.int(a.ayah))")
                                .font(.custom(ContentLibrary.mushafFont, size: 20))
                        }
                    }
                    Button("سمّع مرة أخرى") { restart() }.frame(maxWidth: .infinity, minHeight: Brand.minTap)
                    NavigationLink { MushafReader(startPage: ayat.first?.page ?? 1) } label: { Text("افتح في المصحف").frame(maxWidth: .infinity) }
                }
            } else {
                Section {
                    VStack(spacing: 12) {
                        Button { toggle() } label: {
                            Image(systemName: listener.listening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 36, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 84, height: 84)
                                .background(listener.listening ? Color(red: 0.71, green: 0.26, blue: 0.18) : Brand.primary, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(listener.listening ? "إيقاف الاستماع" : "ابدأ التسميع")
                        Text(status(p)).font(.ui(.body)).multilineTextAlignment(.center)
                            .foregroundStyle(listener.problem != nil ? Color(red: 0.71, green: 0.26, blue: 0.18) : Brand.ink)
                        HStack {
                            Button("أظهر الكلمة التالية") { stream.append(Recite.hint(p.revealed)) }
                                .buttonStyle(.bordered).disabled(p.revealed >= ws.count)
                            Button("من البداية") { restart() }.buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }

            Section("قبل أن تبدأ") {
                Text("يستمع التطبيق بخدمة التعرف على الكلام في جهازك، ولا يسجل صوتك ولا يحفظه. التعرف تقريبي، فالكلمة المظللة تعني «راجعها في المصحف» وليست حكما بالخطأ.")
                    .font(.ui(.subheadline))
                if listener.listening || !listener.finals.isEmpty {
                    Text(listener.onDevice ? "يعمل الآن على جهازك دون إنترنت" : "يستخدم خدمة التعرف على الكلام من Apple")
                        .font(.ui(.footnote)).foregroundStyle(Brand.muted)
                }
            }
            .listRowBackground(Brand.surface)
        }
        .brandScreen()
        .navigationTitle("التسميع الذكي")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: surah) { _, s in from = 1; to = min(lib.surah(s)?.ayahCount ?? 1, 10); restart() }
        .onChange(of: from) { _, f in if to < f { to = f }; restart() }
        .onChange(of: to) { _, _ in restart() }
        .onChange(of: listener.finals.count) { _, n in
            while consumed < n { stream += Recite.heardKeys(listener.finals[consumed]); consumed += 1 }
        }
        .onChange(of: p.done) { _, done in
            guard done, !ws.isEmpty else { return }
            listener.stop()
            if !counted { counted = true; Journey.shared.hifzDone() }
        }
        .onDisappear { listener.stop() }
    }

    /// Hidden words keep their place as light bars until recited; words to review are amber.
    private func passage(_ ws: [(Int, Int, String)], _ p: Recite.Progress) -> AttributedString {
        var out = AttributedString()
        var word = -1
        for (ai, a) in ayat.enumerated() {
            for tok in Recite.tokens(a.textUthmani) {
                if !Recite.key(tok).isEmpty { word += 1 }
                var run = AttributedString(tok)
                let shown = !hidden || word < p.revealed
                if !shown {
                    run.foregroundColor = .clear
                    run.backgroundColor = Brand.primary.opacity(0.10)
                } else if word >= 0, word < p.marks.count, p.marks[word] == .review {
                    run.foregroundColor = Color(red: 0.60, green: 0.36, blue: 0.0)
                    run.backgroundColor = Color(red: 0.91, green: 0.64, blue: 0.23).opacity(0.25)
                } else {
                    run.foregroundColor = word < p.revealed ? Brand.ink : Brand.muted
                }
                out += run + AttributedString(" ")
            }
            let end = ws.lastIndex { $0.0 == ai } ?? -1
            var mark = AttributedString(QuranText.marker(a.ayah) + " ")
            mark.foregroundColor = (!hidden || end < p.revealed) ? Brand.goldInk : .clear
            out += mark
        }
        return out
    }

    private func status(_ p: Recite.Progress) -> String {
        if let e = listener.problem { return e }
        if listener.listening { return "أستمع إليك… اقرأ من حفظك" }
        return p.revealed > 0 ? "متوقف، اضغط للمتابعة" : "اضغط وابدأ القراءة من أول المقطع"
    }

    private func toggle() {
        if listener.listening { listener.stop() } else { listener.start() }
    }

    private func restart() {
        listener.stop(); listener.clear(); stream = []; consumed = 0; counted = false
    }
}

/// «البحث بالصوت»: the user recites a few words of an ayah and the app finds it in the mushaf kept on
/// the device (no server). Recognition is the device's own; the results are the pack's own ayat.
struct VoiceSearchView: View {
    @State private var listener = SpeechListener()
    @State private var heard = ""
    @State private var hits: [VoiceSearch.Hit]?
    @State private var busy = false
    private let lib = ContentLibrary.shared

    var body: some View {
        Form {
            ToolHeadSection(id: "voice-search")
            Section {
                VStack(spacing: 12) {
                    Button { toggle() } label: {
                        Image(systemName: listener.listening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(listener.listening ? Color(red: 0.71, green: 0.26, blue: 0.18) : Brand.primary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(listener.listening ? "إيقاف الاستماع" : "ابدأ البحث بالصوت")
                    Text(status).font(.ui(.body)).multilineTextAlignment(.center)
                        .foregroundStyle(listener.problem != nil ? Color(red: 0.71, green: 0.26, blue: 0.18) : Brand.ink)
                    if busy { ProgressView() }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            if let hits {
                if hits.isEmpty {
                    Section { Text("لم أجد آية بهذه الكلمات. جرّب أن تقرأ كلمات أكثر بوضوح، أو ابحث بالكتابة.").font(.ui(.subheadline)) }
                } else {
                    Section(hits.count == 1 ? "وجدت آية واحدة" : "أقرب الآيات") {
                        ForEach(hits) { h in
                            NavigationLink { MushafReader(startPage: h.ayah.page ?? 1) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("سورة \(lib.surah(h.ayah.surah)?.shortName ?? "") · آية \(Num.int(h.ayah.ayah))")
                                        .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.goldInk)
                                    Text(h.ayah.textUthmani + " " + QuranText.marker(h.ayah.ayah))
                                        .font(.custom(ContentLibrary.mushafFont, size: 21)).lineSpacing(8).lineLimit(4)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                Text("يبحث في المصحف المحفوظ على جهازك، ويستمع بخدمة التعرف على الكلام دون تسجيل صوتك.")
                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)
            }
            .listRowBackground(Brand.surface)
        }
        .brandScreen()
        .navigationTitle("البحث بالصوت")
        .navigationBarTitleDisplayMode(.inline)
        // One phrase at a time: the first complete result is searched and listening stops.
        .onChange(of: listener.finals.count) { _, _ in
            guard let t = listener.finals.last, !t.isEmpty else { return }
            listener.stop()
            heard = t
            busy = true
            Task.detached(priority: .userInitiated) {
                let found = VoiceSearch.shared.find(t)
                await MainActor.run { hits = found; busy = false }
            }
        }
        .onDisappear { listener.stop() }
    }

    private var status: String {
        if let e = listener.problem { return e }
        if listener.listening { return listener.partial.isEmpty ? "أستمع… اقرأ كلمات من الآية" : listener.partial }
        if !heard.isEmpty { return "سمعت: \(heard)" }
        return "اضغط واقرأ بضع كلمات من الآية التي تبحث عنها"
    }

    private func toggle() {
        if listener.listening { listener.stop(); return }
        hits = nil; heard = ""
        listener.clear()
        listener.start()
    }
}
