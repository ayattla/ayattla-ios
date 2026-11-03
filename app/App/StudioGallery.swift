import SwiftUI
import AyatDesign
import AyatContent

/// Ready-made designs («قوالب جاهزة»): each is a full set of editor settings (ayat from the site's
/// quick picks, a site background, a site dedication template, a size), shown as a live preview drawn
/// from the verified pack. Tapping one opens the card editor with everything filled in.
struct StudioPreset: Identifiable {
    let id: String
    let title: String
    let settings: EditorSettings

    static let all: [StudioPreset] = [
        .init(id: "kursi", title: "آية الكرسي", settings: .init(surah: 2, from: 255, to: 255, ratio: "4:5", background: "emerald", fontScale: 1, template: "", name: "")),
        .init(id: "sharh", title: "إن مع العسر يسرا", settings: .init(surah: 94, from: 5, to: 6, ratio: "9:16", background: "dawn", fontScale: 1.15, template: "", name: "")),
        .init(id: "raad", title: "طمأنينة القلوب", settings: .init(surah: 13, from: 28, to: 28, ratio: "1:1", background: "night", fontScale: 1, template: "", name: "")),
        .init(id: "sadaqa", title: "صدقة جارية", settings: .init(surah: 2, from: 201, to: 201, ratio: "9:16", background: "emerald", fontScale: 1, template: "sadaqa", name: "")),
        .init(id: "jumuah", title: "جمعة مباركة", settings: .init(surah: 112, from: 1, to: 4, ratio: "4:5", background: "sand", fontScale: 1, template: "jumuah", name: "")),
        .init(id: "ramadan", title: "رمضان مبارك", settings: .init(surah: 2, from: 285, to: 286, ratio: "9:16", background: "dusk", fontScale: 0.85, template: "ramadan", name: "")),
        .init(id: "ikhlas", title: "سورة الإخلاص", settings: .init(surah: 112, from: 1, to: 4, ratio: "16:9", background: "ink", fontScale: 1, template: "", name: "")),
        .init(id: "eid", title: "عيد مبارك", settings: .init(surah: 1, from: 1, to: 7, ratio: "1:1", background: "dawn", fontScale: 0.85, template: "eid", name: "")),
        // Status-sized (9:16) designs for the status screen.
        .init(id: "st-kursi", title: "حالة آية الكرسي", settings: .init(surah: 2, from: 255, to: 255, ratio: "9:16", background: "night", fontScale: 1, template: "", name: "")),
        .init(id: "st-jumuah", title: "حالة الجمعة", settings: .init(surah: 112, from: 1, to: 4, ratio: "9:16", background: "emerald", fontScale: 1.15, template: "jumuah", name: "")),
        .init(id: "st-eid", title: "حالة العيد", settings: .init(surah: 94, from: 5, to: 6, ratio: "9:16", background: "sand", fontScale: 1.15, template: "eid", name: "")),
    ]

    /// The ready designs at status size (9:16).
    static var statuses: [StudioPreset] { all.filter { $0.settings.ratio == "9:16" } }
    /// Ready designs for the studio and home (statuses have their own screen).
    static var general: [StudioPreset] { all.filter { !$0.id.hasPrefix("st-") } }

    /// The canvas model for the live preview, built the same way as the card editor's.
    var model: CardCanvas.Model {
        let lib = ContentLibrary.shared
        let e = settings
        let ayat = (try? lib.store?.ayat(surah: e.surah, from: e.from, to: e.to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let s = lib.surah(e.surah)?.shortName ?? ""
        let ref = e.from == e.to ? "[\(s): \(Num.int(e.from))]" : "[\(s): \(Num.int(e.from))–\(Num.int(e.to))]"
        let template = CardOptions.templates.first { $0.id == e.template && !e.template.isEmpty }
        let bg = CardOptions.backgrounds.first { $0.id == e.background } ?? CardOptions.backgrounds[0]
        return .init(text: text, reference: ref, template: template?.name, name: nil, background: bg,
                     fontScale: e.fontScale, ratio: CardOptions.Ratio(rawValue: e.ratio) ?? .square,
                     lightBackground: bg.id == "sand")
    }
}

/// One live template preview with its name and size.
struct PresetTile: View {
    let preset: StudioPreset
    var height: CGFloat = 190

    var body: some View {
        let m = preset.model
        VStack(alignment: .leading, spacing: Brand.Space.s) {
            CardCanvas(model: m, photo: nil)
                .aspectRatio(m.ratio.size.width / m.ratio.size.height, contentMode: .fit)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .frame(maxWidth: .infinity)
            HStack {
                Text(preset.title).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.ink).lineLimit(1)
                Spacer(minLength: 4)
                Badge(m.ratio.label)
            }
        }
        .padding(Brand.Space.s + 2)
        .frame(width: max(140, height * m.ratio.size.width / m.ratio.size.height + 20))
        .surface(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("قالب \(preset.title)، مقاس \(m.ratio.label)")
    }
}

/// Horizontal strip of ready-made designs.
struct PresetStrip: View {
    var title = "قوالب جاهزة"
    var subtitle = "ابدأ من تصميم جاهز ثم غير الآية والخلفية والمقاس"
    var presets: [StudioPreset] = StudioPreset.general

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            SectionHeader(title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Brand.Space.m) {
                    ForEach(presets) { p in
                        NavigationLink { AyahCardView(settings: p.settings) } label: { PresetTile(preset: p) }
                            .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Brand.Space.l)
                .padding(.vertical, Brand.Space.s)
            }
            .padding(.horizontal, -Brand.Space.l)
        }
    }
}
