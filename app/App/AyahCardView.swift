import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AyatDesign
import AyatContent

/// Card options from the site (docs/site_snapshot_2026-11-02.json: ratios, templates, still backgrounds).
enum CardOptions {
    enum Ratio: String, CaseIterable, Identifiable {
        case square = "1:1", portrait = "4:5", story = "9:16", wide = "16:9"
        var id: String { rawValue }
        var size: CGSize {
            switch self {
            case .square: CGSize(width: 1080, height: 1080)
            case .portrait: CGSize(width: 1080, height: 1350)
            case .story: CGSize(width: 1080, height: 1920)
            case .wide: CGSize(width: 1920, height: 1080)
            }
        }
        var label: String { Num.digits(rawValue) }
    }

    struct Template: Identifiable, Hashable { let id: String; let name: String }
    static let templates: [Template] = [
        .init(id: "", name: "بدون"), .init(id: "sadaqa", name: "صدقة جارية"), .init(id: "ihdaa", name: "إهداء"),
        .init(id: "ramadan", name: "رمضان مبارك"), .init(id: "eid", name: "عيد مبارك"), .init(id: "jumuah", name: "جمعة مباركة"),
    ]

    /// The site's still backgrounds, drawn here as gradients.
    struct Background: Identifiable, Hashable {
        let id: String; let name: String; let top: UInt32; let bottom: UInt32
        var gradient: LinearGradient {
            LinearGradient(colors: [Color(hex: top), Color(hex: bottom)], startPoint: .top, endPoint: .bottom)
        }
    }
    static let backgrounds: [Background] = [
        .init(id: "emerald", name: "زمردي", top: 0x2F6B3B, bottom: 0x14301C),
        .init(id: "night", name: "ليل هادئ", top: 0x1B2433, bottom: 0x0A0F17),
        .init(id: "dusk", name: "غروب الصحراء", top: 0x8A4B2A, bottom: 0x2B1A16),
        .init(id: "dawn", name: "فجر", top: 0x3C5A7A, bottom: 0xC9A27A),
        .init(id: "sand", name: "رملي", top: 0xE9DCC2, bottom: 0xC8B48E),
        .init(id: "ink", name: "حبر", top: 0x1C1C1E, bottom: 0x000000),
    ]

    static let fontScales: [(String, Double)] = [("صغير", 0.85), ("متوسط", 1.0), ("كبير", 1.15)]
    static let maxAyat = 10
}

/// Lazily rendered PNG for ShareLink, so the full-size image is drawn only when sharing.
struct CardImage: Transferable {
    let model: CardCanvas.Model
    let photo: UIImage?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await MainActor.run {
                guard let data = CardCanvas.render(card.model, photo: card.photo)?.pngData() else { throw CocoaError(.fileWriteUnknown) }
                return data
            }
        }
    }
}

/// Ayah card editor, per design/Card.dc.html and /tools/ayah-card.
struct AyahCardView: View {
    @State private var surah: Int
    @State private var from: Int
    @State private var to: Int
    @State private var ratio = CardOptions.Ratio.square
    @State private var template = CardOptions.templates[0]
    @State private var name = ""
    @State private var background = CardOptions.backgrounds[0]
    @State private var fontScale = 1.0
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var saved = false
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    private let lib = ContentLibrary.shared

    init(surah: Int = 2, from: Int = 255, to: Int? = nil) {
        _surah = State(initialValue: surah)
        _from = State(initialValue: from)
        _to = State(initialValue: to ?? from)
    }

    var body: some View {
        Form {
            Section {
                CardCanvas(model: model, photo: photo)
                    .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("معاينة البطاقة")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section("الآيات") {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Stepper("من آية \(Num.int(from))", value: $from, in: 1...ayahCount)
                Stepper("إلى آية \(Num.int(to))", value: $to, in: from...min(ayahCount, from + CardOptions.maxAyat - 1))
            }
            Section("القالب") {
                Picker("القالب", selection: $template) { ForEach(CardOptions.templates) { Text($0.name).tag($0) } }
                if !template.id.isEmpty { TextField("الاسم (اختياري)", text: $name) }
            }
            Section("المقاس") {
                Picker("المقاس", selection: $ratio) { ForEach(CardOptions.Ratio.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.segmented)
            }
            Section("حجم الخط") {
                Picker("حجم الخط", selection: $fontScale) {
                    ForEach(CardOptions.fontScales, id: \.1) { Text($0.0).tag($0.1) }
                }
                .pickerStyle(.segmented)
            }
            Section("الخلفية") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CardOptions.backgrounds) { b in
                            let on = photo == nil && background == b
                            Button { background = b; photo = nil; photoItem = nil } label: {
                                RoundedRectangle(cornerRadius: 10).fill(b.gradient)
                                    .frame(width: 56, height: 56)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Brand.primary : .clear, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(b.name)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                PhotosPicker(selection: $photoItem, matching: .images) { Label("صورة من الجهاز", systemImage: "photo") }
            }
            Section {
                Button {
                    if let image = CardCanvas.render(model, photo: photo) {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        saved = true
                    }
                } label: { Label("حفظ في الصور", systemImage: "square.and.arrow.down") }
                ShareLink(item: CardImage(model: model, photo: photo),
                          preview: SharePreview(model.reference)) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                if let folder = (try? lib.store?.reciterFolders())?[reciter] {
                    NavigationLink {
                        ClipExportView(job: ClipJob(items: (from...to).map { .init(model: model, surah: surah, ayah: $0) },
                                                    ratio: ratio, folder: folder, title: model.reference, photo: photo))
                    } label: { Label("حولها إلى فيديو بالتلاوة", systemImage: "film") }
                }
            }
        }
        .navigationTitle("بطاقة آية")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            Task { if let data = try? await item?.loadTransferable(type: Data.self) { photo = UIImage(data: data) } }
        }
        .onChange(of: surah) { _, _ in from = 1; to = 1 }
        .onChange(of: from) { _, f in if to < f || to > f + CardOptions.maxAyat - 1 { to = f } }
        .alert("حفظت البطاقة في الصور", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }

    private var model: CardCanvas.Model {
        let ayat = (try? lib.store?.ayat(surah: surah, from: from, to: to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let s = lib.surah(surah)?.shortName ?? ""
        let ref = from == to ? "[\(s): \(Num.int(from))]" : "[\(s): \(Num.int(from))–\(Num.int(to))]"
        return .init(text: text, reference: ref, template: template.id.isEmpty ? nil : template.name,
                     name: name.isEmpty ? nil : name, background: background, fontScale: fontScale,
                     ratio: ratio, lightBackground: background.id == "sand")
    }
}

struct CardCanvas: View {
    struct Model {
        let text: String
        let reference: String
        let template: String?
        let name: String?
        let background: CardOptions.Background
        let fontScale: Double
        let ratio: CardOptions.Ratio
        let lightBackground: Bool
    }

    let model: Model
    let photo: UIImage?

    /// Full-resolution image (1080 px on the short side), drawn on the device.
    @MainActor static func render(_ model: Model, photo: UIImage?) -> UIImage? {
        let size = model.ratio.size
        let r = ImageRenderer(content: CardCanvas(model: model, photo: photo)
            .frame(width: size.width / 3, height: size.height / 3)
            .environment(\.layoutDirection, .rightToLeft))
        r.scale = 3
        return r.uiImage
    }

    /// Taller frames have room for larger text; long passages still shrink to fit.
    private var baseSize: CGFloat {
        switch model.ratio {
        case .story: 30
        case .portrait: 26
        default: 22
        }
    }

    var body: some View {
        GeometryReader { g in
            let unit = min(g.size.width, g.size.height) / 360
            let ink: Color = (model.lightBackground && photo == nil) ? Color(hex: 0x2B2418) : .white
            ZStack {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: g.size.width, height: g.size.height).clipped()
                    Color.black.opacity(0.45)
                } else {
                    model.background.gradient
                }
                VStack(spacing: 14 * unit) {
                    if let t = model.template {
                        VStack(spacing: 2 * unit) {
                            Text(t).font(.system(size: 15 * unit, weight: .semibold))
                            if let n = model.name { Text(n).font(.system(size: 12 * unit)) }
                        }
                        .opacity(0.9)
                    }
                    Spacer(minLength: 0)
                    Text(model.text)
                        .font(.custom(ContentLibrary.mushafFont, size: baseSize * unit * model.fontScale))
                        .lineSpacing(baseSize * 0.36 * unit * model.fontScale)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                    Text(model.reference).font(.system(size: 12 * unit, weight: .medium)).opacity(0.85)
                    Spacer(minLength: 0)
                    Text("ayattla.com").font(.system(size: 10 * unit)).opacity(0.7)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 26 * unit)
                .padding(.vertical, 22 * unit)
            }
        }
    }
}
