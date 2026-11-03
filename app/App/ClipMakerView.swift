import SwiftUI
import AVKit
import AVFoundation
import PhotosUI
import AyatDesign
import AyatContent

/// What to render: one text frame per item, each shown for the length of its recitation.
struct ClipJob {
    struct Item { let model: CardCanvas.Model; let surah: Int; let ayah: Int }
    let items: [Item]
    let ratio: CardOptions.Ratio
    let folder: String
    let title: String
    var photo: UIImage? = nil
    var settings: EditorSettings? = nil
    /// Animated background or a photo with the slow zoom; nil = still background drawn in each frame.
    var motion: MotionBackground? = nil
    /// Word highlighting with Quran.com timings (chapter recitation id and color), as on the site.
    var highlight: (qfID: Int, color: UInt32)? = nil
}

/// Highlight colors on the site's clip maker (--c-hi-gold, --c-hi-green, --c-hi-sky).
enum HighlightColor: UInt32, CaseIterable, Identifiable {
    case gold = 0xF7CD6E, green = 0x7EE0B5, sky = 0x9BD3FF
    var id: UInt32 { rawValue }
    var name: String {
        switch self {
        case .gold: "ذهبي"
        case .green: "أخضر"
        case .sky: "سماوي"
        }
    }
}

/// Background choices for clips: the site's six still and four animated backgrounds, or a photo.
enum ClipBackground: Hashable {
    case still(CardOptions.Background)
    case motion(MotionStyle)
    case photo

    var id: String {
        switch self {
        case .still(let b): b.id
        case .motion(let m): m.rawValue
        case .photo: "photo"
        }
    }

    static func from(id: String) -> ClipBackground {
        if let m = MotionStyle(rawValue: id) { return .motion(m) }
        if id == "photo" { return .photo }
        return .still(CardOptions.backgrounds.first { $0.id == id } ?? CardOptions.backgrounds[0])
    }
}

/// Ayah clip maker (Studio → مقطع قرآني), the on-device version of the site's clip maker.
struct ClipMakerView: View {
    static let maxAyat = 30   // max_ayat on the site

    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var surah: Int
    @State private var from: Int
    @State private var to: Int
    @State private var ratio: CardOptions.Ratio
    @State private var background: ClipBackground
    @State private var fontScale: Double
    @State private var template: CardOptions.Template
    @State private var name: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var slowZoom = true
    @State private var highlight = true
    @State private var hiColor = HighlightColor.gold
    private let lib = ContentLibrary.shared

    init(surah: Int = 1, from: Int = 1, to: Int = 7, ratio: CardOptions.Ratio = .story, backgroundID: String = "emerald",
         fontScale: Double = 1, templateID: String = "", name: String = "") {
        _surah = State(initialValue: surah); _from = State(initialValue: from); _to = State(initialValue: max(from, to))
        _ratio = State(initialValue: ratio)
        _background = State(initialValue: ClipBackground.from(id: backgroundID == "photo" ? "emerald" : backgroundID))
        _fontScale = State(initialValue: fontScale)
        _template = State(initialValue: CardOptions.templates.first { $0.id == templateID } ?? CardOptions.templates[0])
        _name = State(initialValue: name)
    }

    /// Reopens a saved clip with its settings.
    init(settings e: EditorSettings) {
        self.init(surah: e.surah, from: e.from, to: e.to, ratio: CardOptions.Ratio(rawValue: e.ratio) ?? .story,
                  backgroundID: e.background, fontScale: e.fontScale, templateID: e.template, name: e.name)
    }

    var body: some View {
        EditorLayout(preview: preview) {
            Section {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Stepper("من آية \(Num.int(from))", value: $from, in: 1...ayahCount)
                Stepper("إلى آية \(Num.int(to))", value: $to, in: from...min(ayahCount, from + Self.maxAyat - 1))
            } header: { Text("الآيات") } footer: { Text("حتى \(Num.int(Self.maxAyat)) آية في المقطع، كما في الموقع.") }

            Section {
                Picker("القارئ", selection: $reciter) {
                    ForEach(Catalog.reciters) { Text($0.wordHighlight ? "\($0.name) ★" : $0.name).tag($0.id) }
                }
                if qfID != nil {
                    Toggle("تظليل الكلمة", isOn: $highlight)
                    if highlight {
                        Picker("لون التظليل", selection: $hiColor) {
                            ForEach(HighlightColor.allCases) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } header: { Text("القارئ") } footer: {
                Text(qfID != nil ? "تظليل الكلمات بتوقيتات Quran.com وتلاوة السورة منه، كما في الموقع." : "★ القراء الذين يدعمون تظليل الكلمات.")
            }
            Section("الشكل") {
                Picker("المقاس", selection: $ratio) { ForEach(CardOptions.Ratio.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.segmented)
                Picker("حجم الخط", selection: $fontScale) {
                    ForEach(CardOptions.fontScales, id: \.1) { Text($0.0).tag($0.1) }
                }
                .pickerStyle(.segmented)
                Picker("القالب", selection: $template) { ForEach(CardOptions.templates) { Text($0.name).tag($0) } }
                if !template.id.isEmpty { TextField("الاسم أو سطر الإهداء (اختياري)", text: $name) }
            }
            Section("الخلفية") {
                backgroundRow(title: "متحركة", items: MotionStyle.allCases.map { .motion($0) })
                backgroundRow(title: "ثابتة", items: CardOptions.backgrounds.map { .still($0) })
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(background == .photo ? "تغيير الصورة" : "صورة من الجهاز", systemImage: "photo")
                }
                if background == .photo { Toggle("حركة هادئة للخلفية", isOn: $slowZoom) }
            }
            Section {
                if let folder {
                    NavigationLink {
                        ClipExportView(job: job(folder: folder))
                    } label: {
                        Label("أنشئ المقطع", systemImage: "film").font(.ui(.headline))
                    }
                } else {
                    Text("لا يتوفر صوت لهذا القارئ").foregroundStyle(.secondary)
                }
            } footer: {
                Text("يصنع المقطع على جهازك. تجلب التلاوة من EveryAyah عند الإنشاء ثم تحذف. يحفظ المقطع في مكتبتي.")
            }
        }
        .brandScreen()
        .navigationTitle("مقطع قرآني")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: surah) { old, s in if old != s { from = 1; to = min(lib.surah(s)?.ayahCount ?? 1, 7) } }
        .onChange(of: from) { _, f in if to < f || to > f + Self.maxAyat - 1 { to = f } }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    photo = img.uprightForVideo()
                    background = .photo
                }
            }
        }
    }

    private var preview: some View {
        ZStack {
            switch background {
            case .motion(let m):
                Image(uiImage: MotionBackground.style(m).still(size: CGSize(width: 360, height: 360 * ratio.size.height / ratio.size.width)))
                    .resizable()
            case .photo:
                if let photo { Image(uiImage: photo).resizable().scaledToFill(); Color.black.opacity(0.45) }
            case .still:
                EmptyView()
            }
            CardCanvas(model: frames.first?.model ?? emptyModel, photo: nil)
        }
        .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("معاينة أول شاشة")
    }

    private func backgroundRow(title: String, items: [ClipBackground]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.ui(.caption)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.self) { b in
                        let on = background == b
                        Button { background = b } label: {
                            swatch(b)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Brand.primary : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.name(b))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private func swatch(_ b: ClipBackground) -> some View {
        switch b {
        case .still(let s): Rectangle().fill(s.gradient)
        case .motion(let m): Image(uiImage: MotionBackground.style(m).still(size: CGSize(width: 112, height: 112))).resizable()
        case .photo: Color.gray
        }
    }

    static func name(_ b: ClipBackground) -> String {
        switch b {
        case .still(let s): s.name
        case .motion(let m): m.name
        case .photo: "صورة"
        }
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }
    private var qfID: Int? { (try? lib.store?.reciterQuranComIDs())?[reciter] }
    private var folder: String? { (try? lib.store?.reciterFolders())?[reciter] }
    private var reference: String {
        let s = lib.surah(surah)?.shortName ?? ""
        return from == to ? "\(s) \(Num.int(from))" : "\(s) \(Num.int(from))–\(Num.int(to))"
    }

    private var stillBackground: CardOptions.Background {
        if case .still(let b) = background { return b }
        return CardOptions.backgrounds[0]
    }

    /// Text drawn on its own when the background is animated or a photo.
    private var textOnly: Bool {
        switch background {
        case .still: false
        case .motion: true
        case .photo: photo != nil
        }
    }

    private var emptyModel: CardCanvas.Model {
        .init(text: "", reference: "", template: nil, name: nil, background: stillBackground, fontScale: fontScale,
              ratio: ratio, lightBackground: stillBackground.id == "sand", clearBackground: textOnly)
    }

    var settings: EditorSettings {
        EditorSettings(surah: surah, from: from, to: to, ratio: ratio.rawValue, background: background.id,
                       fontScale: fontScale, template: template.id, name: name, reciter: reciter)
    }

    private func job(folder: String) -> ClipJob {
        var motion: MotionBackground?
        switch background {
        case .motion(let m): motion = .style(m)
        case .photo: if let photo { motion = .photo(photo, slowZoom: slowZoom) }
        case .still: motion = nil
        }
        var job = ClipJob(items: frames, ratio: ratio, folder: folder, title: reference, settings: settings, motion: motion)
        if highlight, let id = qfID { job.highlight = (id, hiColor.rawValue) }
        return job
    }

    /// One frame per ayah; a basmala frame first when the clip starts at ayah 1 of a surah that has it
    /// (its audio is the reciter's 1:1 file, as EveryAyah serves it).
    var frames: [ClipJob.Item] {
        let s = lib.surah(surah)
        let short = s?.shortName ?? ""
        let ayat = (try? lib.store?.ayat(surah: surah, from: from, to: to)) ?? []
        func model(_ text: String, _ ref: String) -> CardCanvas.Model {
            .init(text: text, reference: ref, template: template.id.isEmpty ? nil : template.name,
                  name: name.isEmpty ? nil : name, background: stillBackground, fontScale: fontScale,
                  ratio: ratio, lightBackground: stillBackground.id == "sand", clearBackground: textOnly)
        }
        var out: [ClipJob.Item] = []
        if from == 1, s?.hasBasmala == true, let b = lib.basmala {
            out.append(.init(model: model(b, ""), surah: 1, ayah: 1))
        }
        out += ayat.map { a in
            .init(model: model(a.textUthmani + " " + QuranText.marker(a.ayah), "[\(short): \(Num.int(a.ayah))]"),
                  surah: a.surah, ayah: a.ayah)
        }
        return out
    }
}

/// Runs a ClipJob: fetch audio → draw frames → render → preview, save, share. Saved to Library.
struct ClipExportView: View {
    let job: ClipJob

    enum Phase: Equatable { case working(String, Double), done(URL), failed(String) }
    @State private var phase = Phase.working("تجهيز", 0)
    @State private var task: Task<Void, Never>?
    @State private var saved = false

    var body: some View {
        VStack(spacing: 20) {
            switch phase {
            case .working(let step, let p):
                Spacer()
                ProgressView(value: p) { Text(step) } currentValueLabel: { Text("\(Num.int(Int(p * 100)))٪") }
                    .tint(Brand.primary)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: 520)
                Button("إلغاء", role: .cancel) { task?.cancel() }
                Spacer()
            case .done(let url):
                VideoPlayer(player: AVPlayer(url: url))
                    .aspectRatio(job.ratio.size.width / job.ratio.size.height, contentMode: .fit)
                    .frame(maxHeight: 560)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                HStack(spacing: 10) {
                    Button {
                        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                        saved = true
                    } label: { Label("حفظ في الصور", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
                    .buttonStyle(.borderedProminent)
                    ShareLink(item: url) { Label("مشاركة", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 560)
                Text("حفظ في مكتبتي").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                Spacer()
            case .failed(let why):
                ContentUnavailableView {
                    Label("تعذر إنشاء المقطع", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(why)
                } actions: {
                    Button("إعادة المحاولة") { start() }
                }
            }
        }
        .padding(.vertical, 16)
        .brandScreen()
        .navigationTitle(job.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("حفظ المقطع في الصور", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
        .onAppear { if case .working(_, 0) = phase { start() } }
        .onDisappear { task?.cancel() }
    }

    private func start() {
        phase = .working("جلب التلاوة", 0)
        task = Task { @MainActor in
            let fetcher = RecitationFetcher(folder: job.folder)
            defer { fetcher.cleanUp() }
            do {
                if let hi = job.highlight {
                    let out = try await renderHighlighted(qfID: hi.qfID, color: hi.color)
                    let thumb = Self.thumbnail(first: CardCanvas.render(job.items.last!.model, photo: job.motion == nil ? job.photo : nil),
                                               motion: job.motion, size: job.ratio.size)
                    try? ProjectStore.shared.add(kind: .clip, title: job.title, file: out, thumbnail: thumb,
                                                 ratio: job.ratio.rawValue, settings: job.settings)
                    phase = .done(out)
                    return
                }
                let audio = try await fetcher.fetch(job.items.map { ($0.surah, $0.ayah) }) { p in
                    Task { @MainActor in phase = .working("جلب التلاوة", p * 0.3) }
                }
                try Task.checkCancellation()
                phase = .working("رسم الشاشات", 0.3)
                var segments: [VideoEngine.Segment] = []
                let photo = job.motion == nil ? job.photo : nil
                for (i, item) in job.items.enumerated() {
                    guard let img = CardCanvas.render(item.model, photo: photo) else { throw VideoEngine.Failure.writer("frame") }
                    segments.append(.init(frame: img, audio: audio[i]))
                }
                let out = FileManager.default.temporaryDirectory.appendingPathComponent("آيات-تتلى-\(UUID().uuidString.prefix(6)).mp4")
                try await VideoEngine.render(segments, size: job.ratio.size, to: out, background: job.motion) { p in
                    Task { @MainActor in phase = .working("إنشاء المقطع", 0.35 + 0.65 * p) }
                }
                let thumb = Self.thumbnail(first: segments.first?.frame, motion: job.motion, size: job.ratio.size)
                try? ProjectStore.shared.add(kind: .clip, title: job.title, file: out, thumbnail: thumb,
                                             ratio: job.ratio.rawValue, settings: job.settings)
                phase = .done(out)
            } catch is CancellationError {
                phase = .failed("ألغي الإنشاء")
            } catch let e as URLError {
                phase = .failed(e.code == .notConnectedToInternet ? "لا يوجد اتصال بالإنترنت لجلب التلاوة" : "تعذر جلب التلاوة")
            } catch {
                phase = .failed("حدث خطأ أثناء الإنشاء")
            }
        }
    }

    /// Word highlighting as on the site: the reciter's chapter audio and word timings from Quran.com,
    /// cut to the chosen ayat; one text frame per word. Ayat whose word count differs from the timings
    /// are shown without highlighting.
    @MainActor private func renderHighlighted(qfID: Int, color: UInt32) async throws -> URL {
        let clip = job.items.filter { $0.surah == job.items.last!.surah }
        let surah = clip[0].surah
        phase = .working("جلب توقيتات الكلمات", 0.02)
        let rec = try await QF.recitation(qfID, chapter: surah)
        let stamps = Dictionary(rec.audio_file.timestamps.map { ($0.verse_key, $0) }, uniquingKeysWith: { a, _ in a })
        guard let first = stamps["\(surah):\(clip.first!.ayah)"], let last = stamps["\(surah):\(clip.last!.ayah)"],
              let audioURL = URL(string: rec.audio_file.audio_url) else { throw URLError(.cannotParseResponse) }
        phase = .working("جلب التلاوة", 0.05)
        let (tmp, resp) = try await URLSession.shared.download(from: audioURL)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let audio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        try FileManager.default.moveItem(at: tmp, to: audio)
        defer { try? FileManager.default.removeItem(at: audio) }
        try Task.checkCancellation()

        let start = Double(first.timestamp_from) / 1000, end = Double(last.timestamp_to) / 1000
        let photo = job.motion == nil ? job.photo : nil
        var keys: [VideoEngine.Keyframe] = []
        for item in clip {
            guard let st = stamps["\(surah):\(item.ayah)"] else { continue }
            let base = Double(st.timestamp_from) / 1000 - start
            let segs = st.segments.filter { $0.count >= 3 }
            let words = QuranWords.count(item.model.text)
            if !segs.isEmpty, segs.allSatisfy({ Int($0[0]) >= 1 && Int($0[0]) <= words }) {
                for (i, seg) in segs.enumerated() {
                    var m = item.model
                    m.highlightWord = Int(seg[0]) - 1
                    m.highlightColor = color
                    let t = i == 0 ? min(base, seg[1] / 1000 - start) : seg[1] / 1000 - start
                    keys.append(.init(time: max(0, t)) { CardCanvas.render(m, photo: photo) })
                }
            } else {
                let m = item.model
                keys.append(.init(time: max(0, base)) { CardCanvas.render(m, photo: photo) })
            }
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("آيات-تتلى-\(UUID().uuidString.prefix(6)).mp4")
        try await VideoEngine.renderTimeline(audio: audio,
                                             range: CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                                                end: CMTime(seconds: end, preferredTimescale: 600)),
                                             keyframes: keys, size: job.ratio.size, to: out, background: job.motion) { p in
            Task { @MainActor in phase = .working("إنشاء المقطع", 0.1 + 0.9 * p) }
        }
        return out
    }

    /// First frame for Library: the text over the background it was rendered on.
    static func thumbnail(first: UIImage?, motion: MotionBackground?, size: CGSize) -> UIImage? {
        guard let first else { return nil }
        guard let motion else { return first }
        let small = CGSize(width: size.width / 3, height: size.height / 3)
        let bg = motion.still(size: small, t: 0)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: small, format: f).image { _ in
            bg.draw(in: CGRect(origin: .zero, size: small))
            first.draw(in: CGRect(origin: .zero, size: small))
        }
    }
}
