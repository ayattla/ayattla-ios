import SwiftUI
import AVKit
import AyatDesign
import AyatContent

/// What to render: one frame per item, each shown for the length of its recitation.
struct ClipJob {
    struct Item { let model: CardCanvas.Model; let surah: Int; let ayah: Int }
    let items: [Item]
    let ratio: CardOptions.Ratio
    let folder: String
    let title: String
    var photo: UIImage? = nil
}

/// Ayah clip maker (Studio → مقطع قرآني), the on-device version of the site's clip maker.
struct ClipMakerView: View {
    static let maxAyat = 30   // max_ayat on the site

    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var surah = 1
    @State private var from = 1
    @State private var to = 7
    @State private var ratio = CardOptions.Ratio.story
    @State private var background = CardOptions.backgrounds[0]
    @State private var fontScale = 1.0
    @State private var template = CardOptions.templates[0]
    @State private var name = ""
    private let lib = ContentLibrary.shared

    var body: some View {
        Form {
            Section {
                CardCanvas(model: frames.first?.model ?? emptyModel, photo: nil)
                    .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("معاينة أول شاشة")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                Picker("السورة", selection: $surah) {
                    ForEach(lib.surahs) { Text("\(Num.int($0.id)). \($0.shortName)").tag($0.id) }
                }
                Stepper("من آية \(Num.int(from))", value: $from, in: 1...ayahCount)
                Stepper("إلى آية \(Num.int(to))", value: $to, in: from...min(ayahCount, from + Self.maxAyat - 1))
            } header: { Text("الآيات") } footer: { Text("حتى \(Num.int(Self.maxAyat)) آية في المقطع، كما في الموقع.") }

            Section("القارئ") {
                Picker("القارئ", selection: $reciter) {
                    ForEach(Catalog.reciters) { Text($0.name).tag($0.id) }
                }
            }
            Section("الشكل") {
                Picker("المقاس", selection: $ratio) { ForEach(CardOptions.Ratio.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.segmented)
                Picker("حجم الخط", selection: $fontScale) {
                    ForEach(CardOptions.fontScales, id: \.1) { Text($0.0).tag($0.1) }
                }
                .pickerStyle(.segmented)
                Picker("الخلفية", selection: $background) { ForEach(CardOptions.backgrounds) { Text($0.name).tag($0) } }
                Picker("القالب", selection: $template) { ForEach(CardOptions.templates) { Text($0.name).tag($0) } }
                if !template.id.isEmpty { TextField("الاسم أو سطر الإهداء (اختياري)", text: $name) }
            }
            Section {
                if let folder {
                    NavigationLink {
                        ClipExportView(job: ClipJob(items: frames, ratio: ratio, folder: folder, title: reference))
                    } label: {
                        Label("أنشئ المقطع", systemImage: "film").font(.headline)
                    }
                } else {
                    Text("لا يتوفر صوت لهذا القارئ").foregroundStyle(.secondary)
                }
            } footer: {
                Text("يصنع المقطع على جهازك. تجلب التلاوة من EveryAyah عند الإنشاء ثم تحذف.")
            }
        }
        .navigationTitle("مقطع قرآني")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: surah) { _, s in from = 1; to = min(lib.surah(s)?.ayahCount ?? 1, 7) }
        .onChange(of: from) { _, f in if to < f || to > f + Self.maxAyat - 1 { to = f } }
    }

    private var ayahCount: Int { lib.surah(surah)?.ayahCount ?? 1 }
    private var folder: String? { (try? lib.store?.reciterFolders())?[reciter] }
    private var reference: String {
        let s = lib.surah(surah)?.shortName ?? ""
        return from == to ? "\(s) \(Num.int(from))" : "\(s) \(Num.int(from))–\(Num.int(to))"
    }

    private var emptyModel: CardCanvas.Model {
        .init(text: "", reference: "", template: nil, name: nil, background: background, fontScale: fontScale,
              ratio: ratio, lightBackground: background.id == "sand")
    }

    /// One frame per ayah; a basmala frame first when the clip starts at ayah 1 of a surah that has it
    /// (its audio is the reciter's 1:1 file, as EveryAyah serves it).
    var frames: [ClipJob.Item] {
        let s = lib.surah(surah)
        let short = s?.shortName ?? ""
        let ayat = (try? lib.store?.ayat(surah: surah, from: from, to: to)) ?? []
        func model(_ text: String, _ ref: String) -> CardCanvas.Model {
            .init(text: text, reference: ref, template: template.id.isEmpty ? nil : template.name,
                  name: name.isEmpty ? nil : name, background: background, fontScale: fontScale,
                  ratio: ratio, lightBackground: background.id == "sand")
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

/// Runs a ClipJob: fetch audio → draw frames → render → preview, save, share.
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
                Button("إلغاء", role: .cancel) { task?.cancel() }
                Spacer()
            case .done(let url):
                VideoPlayer(player: AVPlayer(url: url))
                    .aspectRatio(job.ratio.size.width / job.ratio.size.height, contentMode: .fit)
                    .frame(maxHeight: 460)
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
                let audio = try await fetcher.fetch(job.items.map { ($0.surah, $0.ayah) }) { p in
                    Task { @MainActor in phase = .working("جلب التلاوة", p * 0.3) }
                }
                try Task.checkCancellation()
                phase = .working("رسم الشاشات", 0.3)
                var segments: [VideoEngine.Segment] = []
                for (i, item) in job.items.enumerated() {
                    guard let img = CardCanvas.render(item.model, photo: job.photo) else { throw VideoEngine.Failure.writer("frame") }
                    segments.append(.init(frame: img, audio: audio[i]))
                }
                let out = FileManager.default.temporaryDirectory.appendingPathComponent("آيات-تتلى-\(UUID().uuidString.prefix(6)).mp4")
                try await VideoEngine.render(segments, size: job.ratio.size, to: out) { p in
                    Task { @MainActor in phase = .working("إنشاء المقطع", 0.35 + 0.65 * p) }
                }
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
}
