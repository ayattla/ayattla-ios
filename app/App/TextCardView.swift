import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Generic text card (status from dhikr, hadith card)

/// Card for non-Quran text (dhikr, hadith), drawn with Amiri; same sizes and backgrounds as the ayah card.
struct TextCardView: View {
    let title: String
    let text: String
    let reference: String
    @State private var ratio: CardOptions.Ratio
    @State private var background = CardOptions.backgrounds[0]
    @State private var fontScale = 1.0
    @State private var textOffset = CGSize.zero
    @State private var saved = false
    @State private var photo: UIImage?
    @State private var mediaID: String?

    init(title: String, text: String, reference: String, initialRatio: CardOptions.Ratio = .square) {
        self.title = title; self.text = text; self.reference = reference
        _ratio = State(initialValue: initialRatio)
    }

    private var model: CardCanvas.Model {
        .init(text: text, reference: reference, template: nil, name: nil, background: background, fontScale: fontScale,
              ratio: ratio, lightBackground: background.id == "sand", fontName: "Amiri", textOffset: textOffset)
    }

    var body: some View {
        DesignEditorLayout(preview: CardCanvas(model: model, photo: photo)
            .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .textDrag($textOffset)
            .accessibilityLabel("معاينة البطاقة")) {
            EditorStep(1, "النمط", detail: "أنماط جاهزة بلمسة") {
                StylePresetPicker(current: (ratio, background.id, fontScale)) { p in
                    withAnimation(.snappy) { ratio = p.ratio; background = p.background; fontScale = p.fontScale; photo = nil; mediaID = nil }
                }
            }
            EditorStep(2, "الخلفية", detail: "صور حقيقية من المكتبة أو خلفيات الموقع") {
                LibraryStrip(kind: .image, categories: ["mosques", "nature"], selectedID: mediaID) { picked in
                    if case .image(let it, let img) = picked { withAnimation(.snappy) { photo = img; mediaID = it.id } }
                }
                Text("خلفيات الموقع").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).padding(.top, 4)
                BackgroundSwatches(selected: photo == nil ? background : nil) { background = $0; photo = nil; mediaID = nil }
            }
            EditorStep(3, "المقاس والخط") {
                SiteSegmented([CardOptions.Ratio.story, .portrait, .square, .wide].map { (id: $0, title: $0.label, detail: Optional($0.useLabel)) },
                              selection: $ratio)
                Text("حجم الخط").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink).padding(.top, 4)
                SiteSegmented(CardOptions.fontScales.map { (id: $0.1, title: $0.0, detail: String?.none) }, selection: $fontScale)
                TextPositionRow(offset: $textOffset)
            }
            EditorStep(4, "نص متحرك") {
                AnimatedTextButton(model: model, photo: photo, title: title)
                    .font(.ui(.subheadline, .semibold)).tint(Brand.primaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } bar: {
            Button {
                if let img = CardCanvas.render(model, photo: photo) {
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    try? ProjectStore.shared.addImage(img, kind: title == "بطاقة حديث" ? .hadithCard : .status, title: title,
                                                      ratio: ratio.rawValue, settings: nil)
                    saved = true
                }
            } label: { Label("حفظ الصورة", systemImage: "arrow.down.to.line").frame(maxWidth: .infinity) }
            .buttonStyle(.brandDark)
            ShareLink(item: CardImage(model: model, photo: photo), preview: SharePreview(title)) {
                Label("مشاركة", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.brandSecondary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("حفظت الصورة في الصور وفي مكتبتي", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
    }
}
