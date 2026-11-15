import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import AyatDesign
import AyatContent

// Studio v2 (owner, 15 Nov 2026): layers set on their own, text animation, timing per ayah, several
// runs of ayat in one project, saved templates, card sets, device videos and export quality.
// The Quran text itself is never changed: these settings only place and colour it.

/// The text and the layers around it (the site's card has text, reference and the ayattla.com mark).
struct TextLayerStyle: Codable, Equatable, Hashable {
    /// Space between lines, as a share of the font size (the card's default is 0.36).
    var lineSpacing: Double = 0.36
    /// Text colour; nil keeps the background's own (light on dark, dark on sand).
    var textColor: UInt32? = nil
    var shadow: Bool = false
    var showReference: Bool = true
    var referenceScale: Double = 1
    var referenceColor: UInt32? = nil
    var watermark: Bool = true

    static let swatches: [(UInt32?, String)] = [
        (nil, "تلقائي"), (0xFFFFFF, "أبيض"), (0xF6F2E9, "عاجي"), (0xD9C28E, "ذهبي"), (0xC3A66B, "ذهبي داكن"),
        (0x2E9145, "أخضر"), (0x102D27, "زمردي"), (0x0F1F17, "داكن"),
    ]
}

/// How the text of each ayah enters (and leaves) in a clip.
enum ClipAnimation: String, Codable, CaseIterable, Identifiable {
    case none, fade, slide, zoom, words
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none: "بدون"
        case .fade: "تلاشي"
        case .slide: "انزلاق"
        case .zoom: "تكبير"
        case .words: "كلمة كلمة"
        }
    }
}

struct ClipMotionSettings: Codable, Equatable, Hashable {
    var animation: ClipAnimation = .fade
    /// Seconds for the text to come in (and 60٪ of that to go out before the next ayah).
    var duration: Double = 0.6
    /// Word by word: the share of each ayah's recitation over which its words appear.
    var wordPace: Double = 0.8
}

/// Export size: 720p, 1080p (the 1080-wide design) or 4K. The text is drawn at that size.
enum ExportQuality: String, Codable, CaseIterable, Identifiable {
    case hd720, fhd1080, uhd2160
    var id: String { rawValue }
    var name: String {
        switch self {
        case .hd720: "720p"
        case .fhd1080: "1080p"
        case .uhd2160: "4K"
        }
    }
    var scale: CGFloat {
        switch self {
        case .hd720: 720.0 / 1080.0
        case .fhd1080: 1
        case .uhd2160: 2
        }
    }
    func size(_ ratio: CardOptions.Ratio) -> CGSize {
        let s = ratio.size
        return CGSize(width: (s.width * scale / 2).rounded() * 2, height: (s.height * scale / 2).rounded() * 2)
    }
}

/// One more run of ayat in the same project (another surah or another passage).
struct ExtraRange: Codable, Hashable, Identifiable {
    var id = UUID()
    var surah: Int
    var from: Int
    var to: Int
}

/// A saved look: size of the text, background, layers and motion.
struct StudioTemplate: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var fontScale: Double
    var background: String
    var layer: TextLayerStyle
    var motion: ClipMotionSettings
}

enum StudioTemplates {
    private static let key = "studio.templates"
    static func all() -> [StudioTemplate] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([StudioTemplate].self, from: d)) ?? []
    }
    static func save(_ t: StudioTemplate) {
        var list = all().filter { $0.name != t.name }
        list.append(t)
        if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: key) }
    }
    static func remove(_ name: String) {
        let list = all().filter { $0.name != name }
        if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: key) }
    }
}

/// Photos and videos imported from the device live here (Application Support), not in a temporary
/// folder, so a project keeps its background after the app closes or updates.
enum StudioFiles {
    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudioMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    /// Keeps the 20 newest imports.
    static func trim() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for f in sorted.dropFirst(20) { try? fm.removeItem(at: f) }
    }

    /// First frame of a video, for previews.
    static func poster(_ url: URL) async -> UIImage? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1080, height: 1920)
        guard let (cg, _) = try? await gen.image(at: .zero) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A video picked from Photos, copied into the studio folder.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = StudioFiles.dir.appendingPathComponent(UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            StudioFiles.trim()
            return Self(url: dest)
        }
    }
}

// MARK: - Controls

/// Text and layer controls, shared by the clip maker and the card maker.
struct LayerControls: View {
    @Binding var layer: TextLayerStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sliderRow("تباعد الأسطر", value: $layer.lineSpacing, range: 0.1...1.0, text: String(format: "%.2f", layer.lineSpacing))
            Text("لون النص").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
            ColorSwatchRow(selection: $layer.textColor)
            Toggle("ظل خلف النص", isOn: $layer.shadow).font(.ui(.subheadline)).tint(Brand.green)
            Divider().overlay(Brand.line)
            Toggle("إظهار المرجع (السورة والآية)", isOn: $layer.showReference).font(.ui(.subheadline)).tint(Brand.green)
            if layer.showReference {
                sliderRow("حجم المرجع", value: $layer.referenceScale, range: 0.6...1.6, text: "\(Num.int(Int(layer.referenceScale * 100)))٪")
                Text("لون المرجع").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                ColorSwatchRow(selection: $layer.referenceColor)
            }
            Toggle("العلامة المائية ayattla.com", isOn: $layer.watermark).font(.ui(.subheadline)).tint(Brand.green)
            Text("الخط: خط المصحف، ولا يتغير شيء من حروف الآيات.").font(.ui(.caption)).foregroundStyle(Brand.muted)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.ui(.subheadline)).foregroundStyle(Brand.ink)
                Spacer()
                Text(text).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
            }
            Slider(value: value, in: range).tint(Brand.green)
        }
    }
}

struct ColorSwatchRow: View {
    @Binding var selection: UInt32?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TextLayerStyle.swatches.indices, id: \.self) { i in
                    let s = TextLayerStyle.swatches[i]
                    let on = s.0 == selection
                    Button { selection = s.0 } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(s.0.map { Color(hex: $0) } ?? Brand.surface2)
                                if s.0 == nil { Text("A").font(.ui(.subheadline, .bold)).foregroundStyle(Brand.primaryInk) }
                            }
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(on ? Brand.green : Brand.lineStrong, lineWidth: on ? 3 : 1))
                            Text(s.1).font(.ui(.caption2)).foregroundStyle(Brand.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s.1)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Animation and timing for clips.
struct MotionControls: View {
    @Binding var motion: ClipMotionSettings
    var highlightOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SiteSegmented(ClipAnimation.allCases.map { (id: $0, title: $0.name, detail: String?.none) }, selection: $motion.animation)
            if motion.animation == .fade || motion.animation == .slide || motion.animation == .zoom {
                HStack {
                    Text("مدة الظهور").font(.ui(.subheadline)).foregroundStyle(Brand.ink)
                    Spacer()
                    Text(String(format: "%.1f ث", motion.duration)).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                }
                Slider(value: $motion.duration, in: 0.2...1.5).tint(Brand.green)
            }
            if motion.animation == .words {
                HStack {
                    Text("سرعة ظهور الكلمات").font(.ui(.subheadline)).foregroundStyle(Brand.ink)
                    Spacer()
                    Text("\(Num.int(Int(motion.wordPace * 100)))٪ من مدة الآية").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                }
                Slider(value: $motion.wordPace, in: 0.3...1).tint(Brand.green)
            }
            if highlightOn && motion.animation != .none {
                Text("مع تظليل الكلمات بتوقيتات Quran.com تبقى الآية ثابتة؛ أوقف التظليل لتعمل الحركة والوقفات.")
                    .font(.ui(.caption)).foregroundStyle(Brand.newInk)
            }
        }
    }
}

/// «قوالبي»: apply a saved look, or save the current one under a name.
struct MyTemplatesRow: View {
    let current: StudioTemplate
    let apply: (StudioTemplate) -> Void
    @State private var list = StudioTemplates.all()
    @State private var naming = false
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if list.isEmpty {
                Text("لا قوالب بعد. صمم ثم احفظ التصميم باسم لتستخدمه في مشاريع أخرى.").font(.ui(.footnote)).foregroundStyle(Brand.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(list) { t in
                            Button { apply(t) } label: {
                                Text(t.name).font(.ui(.footnote, .medium)).foregroundStyle(Brand.ink)
                                    .padding(.horizontal, 14).frame(minHeight: 38)
                                    .background(Capsule().fill(Brand.surface))
                                    .overlay(Capsule().strokeBorder(Brand.lineStrong, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("حذف القالب", role: .destructive) { StudioTemplates.remove(t.name); list = StudioTemplates.all() }
                            }
                        }
                    }
                }
            }
            Button { name = ""; naming = true } label: {
                Label("احفظ التصميم كقالب", systemImage: "bookmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.brandSecondary)
        }
        .alert("اسم القالب", isPresented: $naming) {
            TextField("مثال: ليلي ذهبي", text: $name)
            Button("حفظ") {
                let n = name.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty else { return }
                var t = current; t.name = String(n.prefix(30))
                StudioTemplates.save(t); list = StudioTemplates.all()
            }
            Button("إلغاء", role: .cancel) {}
        }
    }
}

/// Extra runs of ayat (another surah or passage) in the same project.
struct ExtraRangesEditor: View {
    @Binding var ranges: [ExtraRange]
    @State private var adding = false
    private let lib = ContentLibrary.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($ranges) { $r in
                let count = lib.surah(r.surah)?.ayahCount ?? 1
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("سورة \(lib.surah(r.surah)?.shortName ?? "")").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                        Spacer()
                        Button { ranges.removeAll { $0.id == r.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.muted) }
                            .accessibilityLabel("حذف المقطع")
                    }
                    HStack(spacing: 10) {
                        EditorField("من آية") { Stepper(Num.int(r.from), value: $r.from, in: 1...count).font(.ui(.subheadline, .semibold)) }
                        EditorField("إلى آية") { Stepper(Num.int(r.to), value: $r.to, in: r.from...max(r.from, min(count, r.from + 29))).font(.ui(.subheadline, .semibold)) }
                    }
                }
                .padding(12)
                .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: r.from) { _, f in if r.to < f { $r.wrappedValue.to = f } }
            }
            Button { adding = true } label: {
                Label("أضف آيات من سورة أخرى", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.brandSecondary)
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                List(lib.surahs) { s in
                    Button("\(Num.int(s.id)). \(s.shortName)") {
                        ranges.append(ExtraRange(surah: s.id, from: 1, to: min(s.ayahCount, 3)))
                        adding = false
                    }
                    .foregroundStyle(Brand.ink)
                }
                .navigationTitle("اختر السورة")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { adding = false } } }
            }
        }
    }
}

/// A pause after an ayah (on top of its recitation), keyed "s:a".
struct PauseControls: View {
    let ayat: [(key: String, title: String)]
    @Binding var pauses: [String: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("وقفة بعد كل آية تضاف بعد انتهاء تلاوتها.").font(.ui(.caption)).foregroundStyle(Brand.muted)
            ForEach(ayat, id: \.key) { a in
                let v = pauses[a.key] ?? 0
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(a.title).font(.ui(.footnote)).foregroundStyle(Brand.ink)
                        Spacer()
                        Text(v == 0 ? "بدون" : String(format: "%.1f ث", v)).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primaryInk)
                    }
                    Slider(value: Binding(get: { v }, set: { pauses[a.key] = ($0 * 10).rounded() / 10 == 0 ? nil : ($0 * 10).rounded() / 10 }), in: 0...3)
                        .tint(Brand.green)
                }
            }
        }
    }
}
