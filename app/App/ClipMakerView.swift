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
    /// A real video from the site's library: its temporary file and a poster; read frame by frame at export.
    var video: (url: URL, poster: UIImage?)? = nil
    /// Word highlighting with Quran.com timings (chapter recitation id and color), as on the site.
    var highlight: (qfID: Int, color: UInt32)? = nil
    /// Studio v2: text animation, a pause after each item (seconds), export size.
    var animation = ClipMotionSettings(animation: .none)
    var pauses: [Double] = []
    var quality = ExportQuality.fhd1080
    /// The colour background is light (dark text over it when the text is drawn on its own).
    var lightPlain = false

    /// Animated text, pauses or a size other than 1080p go through the frame-by-frame engine.
    var usesAnimatedEngine: Bool { animation.animation != .none || pauses.contains { $0 > 0 } || quality != .fhd1080 }
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

/// Background choices for clips: the site's six still and four animated backgrounds, a photo from
/// the device, or a real photo or video from the site's library (Pixabay/Pexels).
enum ClipBackground: Hashable {
    case still(CardOptions.Background)
    case motion(MotionStyle)
    case photo
    case media
    /// A video from the device (copied into the studio folder).
    case device

    var id: String {
        switch self {
        case .still(let b): b.id
        case .motion(let m): m.rawValue
        case .photo: "photo"
        case .media: "media"
        case .device: "device"
        }
    }

    static func from(id: String) -> ClipBackground {
        if let m = MotionStyle(rawValue: id) { return .motion(m) }
        if id == "photo" { return .photo }
        return .still(CardOptions.backgrounds.first { $0.id == id } ?? CardOptions.backgrounds[0])
    }
}

/// Ayah clip maker (Studio → مقطع قرآني), the on-device version of the site's clip maker.
/// v3 layout: the preview stays in view on top; the options are the site's numbered steps;
/// «أنشئ المقطع» stays fixed under them.
struct ClipMakerView: View {
    static let maxAyat = 30   // max_ayat on the site

    enum BgTab: String, CaseIterable, Identifiable {
        case video, image, motion, still
        var id: String { rawValue }
        var title: String {
            switch self {
            case .video: "فيديو"
            case .image: "صور"
            case .motion: "متحركة"
            case .still: "ألوان"
            }
        }
    }

    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var surah: Int
    @State private var from: Int
    @State private var to: Int
    @State private var ratio: CardOptions.Ratio
    @State private var background: ClipBackground
    @State private var fontScale: Double
    @State private var ornament = CardOrnament.none
    @State private var template: CardOptions.Template
    @State private var name: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var media: PickedMedia?
    @State private var pendingRef: MediaLibrary.Ref?
    @State private var bgTab: BgTab
    @State private var slowZoom = true
    @State private var highlight = true
    @State private var hiColor = HighlightColor.gold
    @State private var jumping = false
    // Studio v2.
    @State private var layer = TextLayerStyle()
    @State private var motionSettings = ClipMotionSettings(animation: .none)
    @State private var quality = ExportQuality.fhd1080
    @State private var extras: [ExtraRange] = []
    @State private var pauses: [String: Double] = [:]
    @State private var movieItem: PhotosPickerItem?
    @State private var deviceVideo: URL?
    @State private var devicePoster: UIImage?
    @State private var importingMovie = false
    private let lib = ContentLibrary.shared

    init(surah: Int = 1, from: Int = 1, to: Int = 7, ratio: CardOptions.Ratio = .story, backgroundID: String = "emerald",
         fontScale: Double = 1, templateID: String = "", name: String = "", media: MediaLibrary.Ref? = nil) {
        _surah = State(initialValue: surah); _from = State(initialValue: from); _to = State(initialValue: max(from, to))
        _ratio = State(initialValue: ratio)
        let ref = media ?? (backgroundID.hasPrefix("media:") ? MediaLibrary.Ref(key: String(backgroundID.dropFirst(6))) : nil)
        _pendingRef = State(initialValue: ref)
        let bg = ClipBackground.from(id: backgroundID == "photo" || ref != nil ? "emerald" : backgroundID)
        _background = State(initialValue: bg)
        switch bg {
        case .motion: _bgTab = State(initialValue: .motion)
        default: _bgTab = State(initialValue: ref?.type == .image ? .image : ref != nil ? .video : .still)
        }
        _fontScale = State(initialValue: fontScale)
        _template = State(initialValue: CardOptions.templates.first { $0.id == templateID } ?? CardOptions.templates[0])
        _name = State(initialValue: name)
    }

    /// Reopens a saved clip with its settings.
    init(settings e: EditorSettings) {
        self.init(surah: e.surah, from: e.from, to: e.to, ratio: CardOptions.Ratio(rawValue: e.ratio) ?? .story,
                  backgroundID: e.background, fontScale: e.fontScale, templateID: e.template, name: e.name)
        if let l = e.layer { _layer = State(initialValue: l) }
        if let m = e.motion { _motionSettings = State(initialValue: m) }
        if let q = e.quality { _quality = State(initialValue: q) }
        if let x = e.extras { _extras = State(initialValue: x) }
        if let p = e.pauses { _pauses = State(initialValue: p) }
        if let o = e.ornament.flatMap(CardOrnament.init(rawValue:)) { _ornament = State(initialValue: o) }
    }

    var body: some View {
        DesignEditorLayout(preview: preview) {
            EditorStep(1, "الآيات", detail: "حتى \(Num.int(Self.maxAyat)) آية في المقطع، كما في الموقع") {
                FlowLayout(spacing: 8) {
                    ForEach(AyahCardView.quickPicks.indices, id: \.self) { i in
                        let q = AyahCardView.quickPicks[i]
                        let on = surah == q.1 && from == q.2 && to == q.3
                        Button {
                            jumping = surah != q.1
                            surah = q.1; from = q.2; to = q.3
                        } label: {
                            Text(q.0).font(.ui(.footnote, .medium))
                                .foregroundStyle(on ? Color.white : Brand.ink)
                                .padding(.horizontal, 14).frame(minHeight: 38)
                                .background { if on { Capsule().fill(Brand.siteGradient) } else { Capsule().fill(Brand.surface) } }
                                .overlay(Capsule().strokeBorder(on ? Color.clear : Brand.lineStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                EditorField("السورة") {
                    Picker("السورة", selection: $surah) {
                        ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                    }
                    .labelsHidden().tint(Brand.ink)
                }
                HStack(spacing: 10) {
                    EditorField("من آية") {
                        Stepper(Num.int(from), value: $from, in: 1...ayahCount).font(.ui(.subheadline, .semibold))
                    }
                    EditorField("إلى آية") {
                        Stepper(Num.int(to), value: $to, in: from...min(ayahCount, from + Self.maxAyat - 1)).font(.ui(.subheadline, .semibold))
                    }
                }
                ExtraRangesEditor(ranges: $extras)
                if frames.count > Self.maxAyat + 1 {
                    Text("حد المقطع \(Num.int(Self.maxAyat)) آية؛ يصدر أولها.").font(.ui(.caption)).foregroundStyle(Brand.newInk)
                }
            }

            EditorStep(2, "القارئ", detail: qfID != nil ? "تظليل الكلمات بتوقيتات Quran.com" : "★ القراء الذين يدعمون تظليل الكلمات") {
                // Full name on its own line (a menu value is cut in the middle on small iPhones).
                NavigationLink {
                    ReciterChoice(selection: $reciter)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("القارئ").font(.ui(.caption, .semibold)).foregroundStyle(Brand.muted)
                            Text(Catalog.reciter(reciter).map { $0.wordHighlight ? "\($0.name) ★" : $0.name } ?? "")
                                .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.left").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.muted)
                    }
                    .padding(12)
                    .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                if qfID != nil {
                    Toggle("تظليل الكلمة مع التلاوة", isOn: $highlight).font(.ui(.subheadline)).tint(Brand.green)
                    if highlight {
                        SiteSegmented(HighlightColor.allCases.map { (id: $0, title: $0.name, detail: String?.none) }, selection: $hiColor)
                    }
                }
            }

            EditorStep(3, "الخلفية", detail: "مقاطع وصور حقيقية من المكتبة، أو خلفيات الموقع") {
                SiteSegmented(BgTab.allCases.map { (id: $0, title: $0.title, detail: String?.none) }, selection: $bgTab)
                switch bgTab {
                case .video:
                    LibraryStrip(kind: .video, kinds: [.video, .image], categories: ["mosques", "sky"], selectedID: mediaID, onPick: picked)
                    PhotosPicker(selection: $movieItem, matching: .videos) {
                        Label(importingMovie ? "جار الاستيراد…" : (background == .device ? "غير فيديو الجهاز" : "أو فيديو من جهازك"), systemImage: "video.badge.plus")
                            .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5])).foregroundStyle(Brand.lineStrong))
                    }
                    .disabled(importingMovie)
                case .image:
                    LibraryStrip(kind: .image, kinds: [.image, .video], categories: ["mosques", "night"], selectedID: mediaID, onPick: picked)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(background == .photo ? "غير صورة الجهاز" : "أو صورة من جهازك", systemImage: "photo.badge.plus")
                            .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5])).foregroundStyle(Brand.lineStrong))
                    }
                case .motion:
                    backgroundRow(items: MotionStyle.allCases.map { .motion($0) })
                case .still:
                    backgroundRow(items: CardOptions.backgrounds.map { .still($0) })
                }
                if usesPhoto {
                    Toggle("حركة هادئة للصورة", isOn: $slowZoom).font(.ui(.subheadline)).tint(Brand.green)
                }
            }

            EditorStep(4, "الشكل", detail: "المقاس وحجم الخط والقالب") {
                Text("المقاس").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                SiteSegmented([CardOptions.Ratio.story, .portrait, .square, .wide].map { (id: $0, title: $0.label, detail: Optional($0.useLabel)) },
                              selection: $ratio)
                Text("حجم خط الآية").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).padding(.top, 4)
                SiteSegmented(CardOptions.fontScales.map { (id: $0.1, title: $0.0, detail: String?.none) }, selection: $fontScale)
                Text("الزخرفة والإطار").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).padding(.top, 4)
                OrnamentSwatches(selected: ornament, background: stillBackground) { o in withAnimation(.snappy) { ornament = o } }
                Divider().overlay(Brand.line)
                TemplatePicker(template: $template)
                if !template.id.isEmpty {
                    EditorField("الاسم أو سطر الإهداء (اختياري)") { TextField("مثال: إهداء إلى والدي", text: $name).font(.ui(.subheadline)) }
                }
            }

            EditorStep(5, "النص والطبقات", detail: "التباعد واللون والظل والمرجع والعلامة") {
                LayerControls(layer: $layer)
            }

            EditorStep(6, "الحركة والتوقيت", detail: "ظهور الآيات ووقفة بعد كل آية") {
                MotionControls(motion: $motionSettings, highlightOn: highlight && qfID != nil)
                PauseControls(ayat: pauseList, pauses: $pauses)
            }

            EditorStep(7, "القوالب والجودة", detail: "قوالبك المحفوظة ودقة التصدير") {
                MyTemplatesRow(current: currentTemplate) { t in
                    withAnimation(.snappy) {
                        fontScale = t.fontScale; layer = t.layer; motionSettings = t.motion
                        let b = ClipBackground.from(id: t.background)
                        if case .still = b { background = b; bgTab = .still } else if case .motion = b { background = b; bgTab = .motion }
                    }
                }
                Text("دقة التصدير").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).padding(.top, 4)
                SiteSegmented(ExportQuality.allCases.map { (id: $0, title: $0.name, detail: String?.none) }, selection: $quality)
                let px = quality.size(ratio)
                Text("\(Int(px.width))×\(Int(px.height)) بكسل. يرسم النص القرآني بهذه الدقة.\(quality == .uhd2160 ? " 4K أبطأ وأكبر حجما." : "")")
                    .font(.ui(.caption)).foregroundStyle(Brand.muted)
            }

            Text("يحفظ المقطع في مكتبتي.")
                .font(.ui(.caption)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } bar: {
            if let folder {
                NavigationLink {
                    ClipExportView(job: job(folder: folder))
                } label: {
                    Label("أنشئ المقطع", systemImage: "film").frame(maxWidth: .infinity)
                }
                .buttonStyle(.brandGold)
                .disabled(waitingForMedia)
            } else {
                Text("لا يتوفر صوت لهذا القارئ").font(.ui(.footnote)).foregroundStyle(Brand.muted).frame(maxWidth: .infinity, minHeight: 50)
            }
        }
        .navigationTitle("صانع المقاطع القرآنية")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: surah) { old, s in
            if jumping { jumping = false } else if old != s { from = 1; to = min(lib.surah(s)?.ayahCount ?? 1, 7) }
        }
        .onChange(of: from) { _, f in if to < f || to > f + Self.maxAyat - 1 { to = f } }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage.downsampled(data) {
                    photo = img.uprightForVideo()
                    media = nil
                    background = .photo
                }
            }
        }
        .onChange(of: movieItem) { _, item in
            guard let item else { return }
            importingMovie = true
            Task {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    deviceVideo = movie.url
                    devicePoster = await StudioFiles.poster(movie.url)
                    media = nil
                    withAnimation(.snappy) { background = .device }
                }
                importingMovie = false
            }
        }
        .task {
            // A saved clip or the home gallery: load that library item again (only its id was kept).
            guard let r = pendingRef, let it = try? await MediaLibrary.item(r) else { pendingRef = nil; return }
            switch it.type {
            case .image: if let img = try? await MediaLibrary.image(it) { picked(.image(it, img)) }
            case .video:
                if let url = try? await MediaLibrary.video(it) {
                    var poster: UIImage?
                    if let t = it.thumbUrl, let d = try? await URLSession.shared.data(from: t).0 { poster = UIImage(data: d) }
                    picked(.video(it, url, poster: poster))
                }
            }
            pendingRef = nil
        }
    }

    private func picked(_ m: PickedMedia) {
        withAnimation(.snappy) {
            media = m
            background = .media
            if case .image(_, let img) = m { photo = img } else { photo = nil }
        }
    }

    private var mediaID: String? {
        guard background == .media, let media else { return nil }
        switch media {
        case .image(let it, _), .video(let it, _, _): return it.id
        }
    }

    private var waitingForMedia: Bool { pendingRef != nil }

    private var usesPhoto: Bool {
        switch background {
        case .photo: photo != nil
        case .media: if case .image? = media { true } else { false }
        default: false
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
            case .media:
                switch media {
                case .video(_, let url, let poster)?:
                    if let poster { Image(uiImage: poster).resizable().scaledToFill() }
                    LoopingVideo(url: url)
                    Color.black.opacity(0.42)
                case .image(_, let img)?:
                    Image(uiImage: img).resizable().scaledToFill(); Color.black.opacity(0.45)
                case nil:
                    Brand.primary
                }
            case .device:
                if let devicePoster { Image(uiImage: devicePoster).resizable().scaledToFill() }
                if let deviceVideo { LoopingVideo(url: deviceVideo) }
                Color.black.opacity(0.42)
            case .still:
                EmptyView()
            }
            CardCanvas(model: frames.first?.model ?? emptyModel, photo: nil)
            if waitingForMedia { ProgressView().tint(.white) }
        }
        .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("معاينة أول شاشة")
    }

    private func backgroundRow(items: [ClipBackground]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { b in
                    let on = background == b
                    Button { withAnimation(.snappy) { background = b } } label: {
                        VStack(spacing: 6) {
                            swatch(b)
                                .frame(width: 72, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(on ? Brand.green : Brand.line, lineWidth: on ? 3 : 1))
                            Text(Self.name(b)).font(.ui(.caption2, on ? .semibold : .regular))
                                .foregroundStyle(on ? Brand.primaryInk : Brand.muted).lineLimit(1)
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Self.name(b))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder private func swatch(_ b: ClipBackground) -> some View {
        switch b {
        case .still(let s): Rectangle().fill(s.gradient)
        case .motion(let m): Image(uiImage: MotionBackground.style(m).still(size: CGSize(width: 144, height: 192))).resizable()
        case .photo, .media, .device: Color.gray
        }
    }

    static func name(_ b: ClipBackground) -> String {
        switch b {
        case .still(let s): s.name
        case .motion(let m): m.name
        case .photo: "صورة"
        case .media: "من المكتبة"
        case .device: "فيديو من جهازك"
        }
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }
    private var qfID: Int? { (try? lib.store?.reciterQuranComIDs())?[reciter] }
    private var folder: String? { lib.reciterFolders[reciter] }
    private var reference: String {
        let s = lib.surah(surah)?.shortName ?? ""
        return from == to ? "\(s) \(Num.int(from))" : "\(s) \(Num.int(from))–\(Num.int(to))"
    }

    private var mediaRefKey: String? {
        switch media {
        case .image(let it, _)?, .video(let it, _, _)?: it.ref.key
        case nil: nil
        }
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
        case .media: media != nil
        case .device: deviceVideo != nil
        }
    }

    private var emptyModel: CardCanvas.Model {
        .init(text: "", reference: "", template: nil, name: nil, background: stillBackground, fontScale: fontScale,
              ratio: ratio, lightBackground: stillBackground.light, clearBackground: textOnly, layer: layer, ornament: ornament)
    }

    private var currentTemplate: StudioTemplate {
        StudioTemplate(name: "", fontScale: fontScale, background: background.id, layer: layer, motion: motionSettings)
    }

    /// Items with a pause slider: every ayah of the project (the basmala as «البسملة»).
    private var pauseList: [(key: String, title: String)] {
        frames.prefix(Self.maxAyat + 1 + extras.count).map { item in
            let isBasmala = item.model.reference.isEmpty
            return (key: "\(item.surah):\(item.ayah)", title: isBasmala ? "البسملة" : item.model.reference)
        }
    }

    var settings: EditorSettings {
        EditorSettings(surah: surah, from: from, to: to, ratio: ratio.rawValue,
                       background: mediaID.flatMap { _ in mediaRefKey.map { "media:" + $0 } } ?? background.id,
                       fontScale: fontScale, template: template.id, name: name, reciter: reciter,
                       layer: layer, motion: motionSettings, quality: quality, extras: extras, pauses: pauses, ornament: ornament.rawValue)
    }

    private func job(folder: String) -> ClipJob {
        var motion: MotionBackground?
        switch background {
        case .motion(let m): motion = .style(m)
        case .photo: if let photo { motion = .photo(photo, slowZoom: slowZoom) }
        case .media:
            if case .image(_, let img)? = media { motion = .photo(img, slowZoom: slowZoom) }
        case .still, .device: motion = nil
        }
        let items = Array(frames.prefix(Self.maxAyat + 1 + extras.count))
        var job = ClipJob(items: items, ratio: ratio, folder: folder, title: reference, settings: settings, motion: motion)
        if case .video(_, let url, let poster)? = media, background == .media { job.video = (url, poster) }
        if background == .device, let deviceVideo { job.video = (deviceVideo, devicePoster) }
        job.animation = motionSettings
        job.pauses = items.map { pauses["\($0.surah):\($0.ayah)"] ?? 0 }
        job.quality = quality
        job.lightPlain = !textOnly && stillBackground.light
        if highlight, let id = qfID, !job.usesAnimatedEngine { job.highlight = (id, hiColor.rawValue) }
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
                  ratio: ratio, lightBackground: stillBackground.light, clearBackground: textOnly, layer: layer, ornament: ornament)
        }
        var out: [ClipJob.Item] = []
        if from == 1, s?.hasBasmala == true, let b = lib.basmala {
            out.append(.init(model: model(b, ""), surah: 1, ayah: 1))
        }
        out += ayat.map { a in
            .init(model: model(a.textUthmani + " " + QuranText.marker(a.ayah), "[\(short): \(Num.int(a.ayah))]"),
                  surah: a.surah, ayah: a.ayah)
        }
        // More runs of ayat in the same project.
        for r in extras {
            let rs = lib.surah(r.surah)
            let rShort = rs?.shortName ?? ""
            if r.from == 1, rs?.hasBasmala == true, let b = lib.basmala {
                out.append(.init(model: model(b, ""), surah: 1, ayah: 1))
            }
            let more = (try? lib.store?.ayat(surah: r.surah, from: r.from, to: max(r.from, r.to))) ?? []
            out += more.map { a in
                .init(model: model(a.textUthmani + " " + QuranText.marker(a.ayah), "[\(rShort): \(Num.int(a.ayah))]"),
                      surah: a.surah, ayah: a.ayah)
            }
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
    @State private var motion: MotionBackground?
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
        // Every path below reads job.items.last; an empty job fails cleanly instead of crashing.
        guard !job.items.isEmpty else { phase = .failed("اختر آية واحدة على الأقل"); return }
        phase = .working("جلب التلاوة", 0)
        task = Task { @MainActor in
            motion = job.motion
            if let v = job.video {
                phase = .working("تجهيز الخلفية", 0)
                if let frames = await VideoFrames(url: v.url) { motion = .video(frames, poster: v.poster) }
                else if let p = v.poster { motion = .photo(p, slowZoom: true) }
            }
            let fetcher = RecitationFetcher(folder: job.folder)
            defer { fetcher.cleanUp() }
            do {
                if job.usesAnimatedEngine {
                    let out = try await renderAnimated(fetcher: fetcher)
                    let thumb = Self.thumbnail(first: CardCanvas.render(job.items.first!.model, photo: motion == nil ? job.photo : nil),
                                               motion: motion, size: job.ratio.size)
                    try? ProjectStore.shared.add(kind: .clip, title: job.title, file: out, thumbnail: thumb,
                                                 ratio: job.ratio.rawValue, settings: job.settings)
                    phase = .done(out)
                    return
                }
                if let hi = job.highlight {
                    let out = try await renderHighlighted(qfID: hi.qfID, color: hi.color)
                    let thumb = Self.thumbnail(first: CardCanvas.render(job.items.last!.model, photo: motion == nil ? job.photo : nil),
                                               motion: motion, size: job.ratio.size)
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
                let photo = motion == nil ? job.photo : nil
                for (i, item) in job.items.enumerated() {
                    guard let img = CardCanvas.render(item.model, photo: photo) else { throw VideoEngine.Failure.writer("frame") }
                    segments.append(.init(frame: img, audio: audio[i]))
                }
                let out = FileManager.default.temporaryDirectory.appendingPathComponent("آيات-تتلى-\(UUID().uuidString.prefix(6)).mp4")
                try await VideoEngine.render(segments, size: job.ratio.size, to: out, background: motion) { p in
                    Task { @MainActor in phase = .working("إنشاء المقطع", 0.35 + 0.65 * p) }
                }
                let thumb = Self.thumbnail(first: segments.first?.frame, motion: motion, size: job.ratio.size)
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
        guard let lastSurah = job.items.last?.surah else { throw URLError(.cannotParseResponse) }
        let clip = job.items.filter { $0.surah == lastSurah }
        let surah = lastSurah
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
        let photo = motion == nil ? job.photo : nil
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
                                             keyframes: keys, size: job.ratio.size, to: out, background: motion) { p in
            Task { @MainActor in phase = .working("إنشاء المقطع", 0.1 + 0.9 * p) }
        }
        return out
    }

    /// Studio v2: the text moves over the background, each ayah holds for its recitation plus its
    /// pause, at the chosen size (720p, 1080p or 4K; the text is drawn at that size).
    @MainActor private func renderAnimated(fetcher: RecitationFetcher) async throws -> URL {
        let audio = try await fetcher.fetch(job.items.map { ($0.surah, $0.ayah) }) { p in
            Task { @MainActor in phase = .working("جلب التلاوة", p * 0.3) }
        }
        try Task.checkCancellation()
        phase = .working("تجهيز الطبقات", 0.3)
        let scale = job.quality.scale
        let size = job.quality.size(job.ratio)
        // The background on its own: video, photo, animated style, or the colour drawn once.
        let bg: MotionBackground
        if let motion { bg = motion }
        else if let p = job.photo { bg = .photo(p, slowZoom: false) }
        else {
            var m = job.items[0].model
            m.backgroundOnly = true; m.clearBackground = false
            bg = .plain(CardCanvas.render(m, photo: nil, scale: scale) ?? UIImage())
        }
        let light = job.lightPlain
        let segments: [VideoEngine.AnimatedSegment] = job.items.enumerated().map { i, item in
            var m = item.model
            m.clearBackground = true
            if light && m.layer.textColor == nil { m.layer.textColor = 0x2B2418 }
            let model = m
            return .init(audio: audio[i], words: QuranWords.revealCount(item.model.text)) { k in
                var mm = model
                mm.visibleWords = k
                return CardCanvas.render(mm, photo: nil, scale: scale)
            }
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("آيات-تتلى-\(UUID().uuidString.prefix(6)).mp4")
        try await VideoEngine.renderAnimated(segments, pauses: job.pauses, motion: job.animation, size: size, to: out, background: bg) { p in
            Task { @MainActor in phase = .working("إنشاء المقطع", 0.35 + 0.65 * p) }
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

/// Reciter list for the editors: word-highlight reciters (★) first, then the rest.
struct ReciterChoice: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("يدعمون تظليل الكلمة ★") { rows(Catalog.reciters.filter(\.wordHighlight)) }
            Section("كل القراء") { rows(Catalog.reciters.filter { !$0.wordHighlight }) }
        }
        .brandScreen()
        .navigationTitle("القارئ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rows(_ list: [Catalog.Reciter]) -> some View {
        ForEach(list) { r in
            Button { selection = r.id; dismiss() } label: {
                HStack {
                    Text(r.name).foregroundStyle(Brand.ink)
                    Spacer()
                    if r.id == selection { Image(systemName: "checkmark").foregroundStyle(Brand.primaryInk) }
                }
                .frame(minHeight: Brand.minTap)
            }
            .listRowBackground(Brand.surface)
            .accessibilityAddTraits(r.id == selection ? .isSelected : [])
        }
    }
}
