import SwiftUI
import UIKit
import AyatDesign
import AyatContent
import UniformTypeIdentifiers

/// Kids' Juz Amma, matching ayattla.com/tools/kids-juz-amma: the child's name, surahs 114 → 78,
/// listening ayah by ayah with repetition (1/3/5, default 3; default reciter Minshawi murattal),
/// a star per memorised surah, badges at 1/5/10/20/37, and a 1080×1350 certificate image.
/// Text from the content pack (Tanzil), audio streamed from EveryAyah.
struct KidsProgress: Codable, Equatable {
    var name = ""
    var done: Set<Int> = []

    static let surahs = Array((78...114).reversed())   // الناس first, as on the site
    static let nameLimit = 30
    struct Badge: Hashable { let count: Int; let title: String }
    static let badges: [Badge] = [
        .init(count: 1, title: "البداية"), .init(count: 5, title: "المثابر"), .init(count: 10, title: "النجم"),
        .init(count: 20, title: "البطل"), .init(count: 37, title: "حافظ جزء عم"),
    ]

    /// Stars on the certificate: one per 8 surahs, between 1 and 5 (site: ceil(c/8) clamped).
    static func certificateStars(_ count: Int) -> Int { min(5, max(1, Int((Double(count) / 8).rounded(.up)))) }

    func encoded() -> String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "" }
    static func decode(_ s: String) -> KidsProgress {
        (try? JSONDecoder().decode(KidsProgress.self, from: Data(s.utf8))) ?? KidsProgress()
    }
}

struct KidsJuzAmmaView: View {
    @AppStorage("kids.progress") private var stored = ""
    @State private var progress = KidsProgress()
    @State private var loaded = false
    private let lib = ContentLibrary.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("اسم الطفل", text: $progress.name)
                        .textContentType(.givenName)
                        .padding(.horizontal, 14).frame(minHeight: 48)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: progress.name) { _, n in
                            if n.count > KidsProgress.nameLimit { progress.name = String(n.prefix(KidsProgress.nameLimit)) }
                        }
                    Text("حفظ: \(Num.int(progress.done.count)) من \(Num.int(KidsProgress.surahs.count)) سورة")
                        .font(.ui(.headline)).foregroundStyle(Brand.primaryInk)
                    ProgressView(value: Double(progress.done.count), total: Double(KidsProgress.surahs.count))
                        .tint(Brand.accent)
                    badges
                }
                .padding(16)
                .card()

                Text("اختر سورة لتبدأ الاستماع والتكرار.").font(.ui(.subheadline)).foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(KidsProgress.surahs, id: \.self) { n in
                        NavigationLink {
                            KidsSurahView(surah: n, progress: $progress)
                        } label: {
                            tile(n)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ShareLink(item: KidsCertificate(name: progress.name, count: progress.done.count),
                          preview: SharePreview("شهادة تقدير")) {
                    Label("تحميل الشهادة", systemImage: "rosette")
                        .font(.ui(.headline)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Brand.primary, in: Capsule())
                }

                Text("النص: مصحف التنزيل. الصوت: EveryAyah.").font(.ui(.footnote)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(Brand.background)
        .brandScreen()
        .navigationTitle("تحفيظ الأطفال جزء عم")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !loaded { progress = KidsProgress.decode(stored); loaded = true } }
        .onChange(of: progress) { _, p in stored = p.encoded() }
    }

    private var badges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(KidsProgress.badges, id: \.count) { b in
                    let earned = progress.done.count >= b.count
                    Label("وسام \(b.title)", systemImage: earned ? "medal.fill" : "medal")
                        .font(.footnote.weight(earned ? .semibold : .regular))
                        .foregroundStyle(earned ? Brand.primaryInk : Brand.muted)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(earned ? Brand.tint : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                        .accessibilityLabel("وسام \(b.title)، \(earned ? "مكتسب" : "عند حفظ \(Num.int(b.count)) سورة")")
                }
            }
        }
    }

    private func tile(_ n: Int) -> some View {
        let done = progress.done.contains(n)
        return VStack(spacing: 4) {
            Text(lib.surah(n)?.shortName ?? Num.int(n)).font(.ui(.headline)).lineLimit(1).minimumScaleFactor(0.7)
            Text(Num.int(n)).font(.ui(.caption)).foregroundStyle(.secondary)
            Image(systemName: done ? "star.fill" : "star")
                .foregroundStyle(done ? Color(hex: 0xC9A227) : Brand.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("سورة \(lib.surah(n)?.shortName ?? Num.int(n))\(done ? "، محفوظة" : "")")
    }
}

/// One surah: listen and repeat, then mark it memorised.
struct KidsSurahView: View {
    let surah: Int
    @Binding var progress: KidsProgress
    @AppStorage("kids.reciter") private var reciter = "minshawi_murattal"
    @AppStorage("kids.repeat") private var repeatEach = 3
    @State private var player = RecitationPlayer()
    @State private var ayat: [Ayah] = []
    @State private var failed = false
    private let lib = ContentLibrary.shared

    private var title: String { "سورة \(lib.surah(surah)?.shortName ?? Num.int(surah))" }
    private var done: Bool { progress.done.contains(surah) }
    private var folder: String? { (try? lib.store?.reciterFolders())?[reciter] }

    var body: some View {
        List {
Group {
            Section {
                Picker("القارئ", selection: $reciter) {
                    ForEach(Catalog.reciters) { Text($0.name).tag($0.id) }
                }
                Picker("تكرار كل آية", selection: $repeatEach) {
                    Text("مرة").tag(1)
                    Text("٣ مرات").tag(3)
                    Text("٥ مرات").tag(5)
                }
                .pickerStyle(.segmented)
                Button {
                    if player.isPlaying { player.stop() } else { start() }
                } label: {
                    Label(player.isPlaying ? "إيقاف" : "استمع وكرر",
                          systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.ui(.headline)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Brand.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(folder == nil || ayat.isEmpty)
                .listRowBackground(Color.clear)
                if player.failed {
                    Text("تعذر تشغيل التلاوة. تحقق من الاتصال بالإنترنت.").font(.ui(.footnote)).foregroundStyle(.secondary)
                }
            }

            Section {
                if failed {
                    Text("تعذر تحميل السورة الآن").foregroundStyle(.secondary)
                } else {
                    if let b = lib.basmala, lib.surah(surah)?.hasBasmala == true {
                        Text(b).font(.custom(ContentLibrary.mushafFont, size: 24, relativeTo: .title3))
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(ayat) { a in
                        let current = player.current == RecitationPlayer.Position(surah: surah, ayah: a.ayah)
                        Text(a.textUthmani + " " + QuranText.marker(a.ayah))
                            .font(.custom(ContentLibrary.mushafFont, size: 26, relativeTo: .title2))
                            .lineSpacing(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowBackground(current ? Brand.tint : Color.cardSurface)
                            .contentShape(Rectangle())
                            .onTapGesture { start(at: a.ayah) }
                            .accessibilityHint("يشغل التلاوة من هذه الآية")
                    }
                }
            }

            Section {
                Button {
                    if done { progress.done.remove(surah) } else { progress.done.insert(surah) }
                } label: {
                    Text(done ? "إلغاء الحفظ" : "حفظتها ★")
                        .font(.ui(.headline))
                        .foregroundStyle(done ? Brand.primaryInk : Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(done ? Brand.tint : Brand.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: done) { _, now in now }
                .listRowBackground(Color.clear)
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { ayat = try lib.store?.ayat(surah: surah, from: 1, to: lib.surah(surah)?.ayahCount ?? 0) ?? [] }
            catch { failed = true }
            if ayat.isEmpty { failed = true }
        }
        .onChange(of: repeatEach) { _, r in player.repeatEach = r }
        .onChange(of: reciter) { _, _ in if player.isPlaying { start(at: player.current?.ayah ?? 1) } }
    }

    private func start(at ayah: Int = 1) {
        player.folder = folder
        player.repeatEach = repeatEach
        player.stopsAtSurahEnd = true
        player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
        player.play(from: .init(surah: surah, ayah: ayah))
    }
}

/// The site's certificate (cert() in /tools/kids-juz-amma), drawn at 1080×1350 and shared as PNG.
struct KidsCertificate: Transferable {
    let name: String
    let count: Int

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { c in
            guard let data = c.render().pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName("شهادة-آيات-تتلى.png")
    }

    func render() -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(Color(hex: 0x2E9145)).cgColor, UIColor(Color(hex: 0x0F7E86)).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            UIColor.white.setFill()
            cg.fill(CGRect(x: 60, y: 60, width: 960, height: 1230))
            UIColor(Color(hex: 0xC9A227)).setStroke()
            cg.setLineWidth(8)
            cg.stroke(CGRect(x: 90, y: 90, width: 900, height: 1170))

            let ink = UIColor(Color(hex: 0x0F1F17)), muted = UIColor(Color(hex: 0x5A6B61))
            let green = UIColor(Color(hex: 0x2E9145)), gold = UIColor(Color(hex: 0xC9A227))
            let date = Date.now.formatted(.dateTime.day().month(.wide).year()
                .locale(Locale(identifier: "ar@numbers=arab;calendar=gregorian")))
            // Baselines and sizes as on the site's canvas.
            draw("شهادة تقدير", size: 76, weight: .semibold, color: ink, baseline: 300)
            draw("تمنح هذه الشهادة إلى", size: 44, weight: .regular, color: muted, baseline: 420)
            draw(name.isEmpty ? "اسم الطفل" : name, size: 96, weight: .semibold, color: green, baseline: 560)
            draw("لحفظه \(Num.int(count)) سورة من جزء عم", size: 48, weight: .regular, color: ink, baseline: 700)
            draw(String(repeating: "★", count: KidsProgress.certificateStars(count)), size: 90, weight: .regular,
                 color: gold, baseline: 850)
            draw(date, size: 36, weight: .regular, color: muted, baseline: 1000)
            draw("آيات تتلى — ayattla.com", size: 36, weight: .regular, color: muted, baseline: 1180)
        }
    }

    /// Centred on x = 540 with its baseline at `baseline`, like canvas fillText with textAlign center.
    private func draw(_ s: String, size: CGFloat, weight: UIFont.Weight, color: UIColor, baseline: CGFloat) {
        var font = UIFont.systemFont(ofSize: size, weight: weight)
        let maxWidth: CGFloat = 860
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        var w = (s as NSString).size(withAttributes: attrs).width
        if w > maxWidth {   // long names shrink to fit inside the frame
            font = UIFont.systemFont(ofSize: size * maxWidth / w, weight: weight)
            attrs[.font] = font
            w = (s as NSString).size(withAttributes: attrs).width
        }
        (s as NSString).draw(at: CGPoint(x: 540 - w / 2, y: baseline - font.ascender), withAttributes: attrs)
    }
}
