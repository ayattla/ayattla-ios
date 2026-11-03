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

    init(title: String, text: String, reference: String, initialRatio: CardOptions.Ratio = .square) {
        self.title = title; self.text = text; self.reference = reference
        _ratio = State(initialValue: initialRatio)
    }

    private var model: CardCanvas.Model {
        .init(text: text, reference: reference, template: nil, name: nil, background: background, fontScale: fontScale,
              ratio: ratio, lightBackground: background.id == "sand", fontName: "Amiri", textOffset: textOffset)
    }

    var body: some View {
        EditorLayout(preview: CardCanvas(model: model, photo: nil)
            .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .textDrag($textOffset)) {
            Section("أنماط جاهزة") {
                StylePresetPicker(current: (ratio, background.id, fontScale)) { p in
                    withAnimation(.snappy) { ratio = p.ratio; background = p.background; fontScale = p.fontScale }
                }
            }
            Section("الشكل") {
                RatioPicker(ratio: $ratio)
                TextPositionRow(offset: $textOffset)
                Picker("حجم الخط", selection: $fontScale) { ForEach(CardOptions.fontScales, id: \.1) { Text($0.0).tag($0.1) } }
                    .pickerStyle(.segmented)
            }
            Section("الخلفية") {
                BackgroundSwatches(selected: background) { background = $0 }
            }
            Section {
                Button {
                    if let img = CardCanvas.render(model, photo: nil) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        try? ProjectStore.shared.addImage(img, kind: title == "بطاقة حديث" ? .hadithCard : .status, title: title,
                                                          ratio: ratio.rawValue, settings: nil)
                        saved = true
                    }
                } label: { Label("حفظ في الصور ومكتبتي", systemImage: "square.and.arrow.down") }
                ShareLink(item: CardImage(model: model, photo: nil), preview: SharePreview(title)) {
                    Label("مشاركة", systemImage: "square.and.arrow.up")
                }
                AnimatedTextButton(model: model, photo: nil, title: title)
            }
        }
        .brandScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("حفظت الصورة في الصور وفي مكتبتي", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
    }
}
