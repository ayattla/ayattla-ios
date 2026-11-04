import SwiftUI
import AyatDesign

// Visual pickers for the design editors (card, clip, status): choices are shown as what they
// produce — size frames, template labels, background swatches — instead of plain menus.

extension CardOptions.Ratio {
    /// Where each size is used, as the site labels it.
    var useLabel: String {
        switch self {
        case .story: "ريلز وحالة"
        case .portrait: "منشور"
        case .square: "مربع"
        case .wide: "يوتيوب"
        }
    }
}

/// Size picker: a frame drawn at each ratio, with its use underneath.
struct RatioPicker: View {
    @Binding var ratio: CardOptions.Ratio
    /// Order as on the site's maker: 9:16, 4:5, 1:1, 16:9.
    private let order: [CardOptions.Ratio] = [.story, .portrait, .square, .wide]

    var body: some View {
        HStack(spacing: Brand.Space.s) {
            ForEach(order) { r in
                let on = r == ratio
                Button { ratio = r } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(on ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Brand.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(on ? Brand.accent : Brand.lineStrong, lineWidth: 1))
                            .aspectRatio(r.size.width / r.size.height, contentMode: .fit)
                            .frame(height: 38)
                        Text(r.label).font(.ui(.caption, .semibold)).foregroundStyle(on ? Brand.primaryInk : Brand.ink)
                        Text(r.useLabel).font(.ui(.caption2)).foregroundStyle(Brand.muted).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(on ? Brand.tint : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(r.label)، \(r.useLabel)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Dedication templates as labelled tiles.
struct TemplatePicker: View {
    @Binding var template: CardOptions.Template

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.s) {
                ForEach(CardOptions.templates) { t in
                    let on = t == template
                    Button { template = t } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.gradient)
                                if t.id.isEmpty {
                                    Image(systemName: "circle.slash").foregroundStyle(Brand.onDeepAccent.opacity(0.8))
                                } else {
                                    VStack(spacing: 3) {
                                        StarMark().frame(width: 10, height: 10)
                                        Text(t.name).font(.ui(size: 10, .semibold)).foregroundStyle(Brand.onDeepAccent)
                                            .multilineTextAlignment(.center).lineLimit(2)
                                    }
                                    .padding(4)
                                }
                            }
                            .frame(width: 74, height: 74)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Brand.accent : .clear, lineWidth: 2.5))
                            Text(t.name).font(.ui(.caption2, on ? .semibold : .regular))
                                .foregroundStyle(on ? Brand.primaryInk : Brand.muted).lineLimit(1)
                        }
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("القالب \(t.name)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Still backgrounds as named swatches.
struct BackgroundSwatches: View {
    let selected: CardOptions.Background?
    let pick: (CardOptions.Background) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.s) {
                ForEach(CardOptions.backgrounds) { b in
                    let on = b == selected
                    Button { pick(b) } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(b.gradient)
                                .frame(width: 60, height: 60)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? Brand.accent : Brand.line, lineWidth: on ? 3 : 1))
                                .overlay(alignment: .bottomTrailing) {
                                    if on {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                            .foregroundStyle(Brand.accent, Brand.primary).padding(4)
                                    }
                                }
                            Text(b.name).font(.ui(.caption2)).foregroundStyle(on ? Brand.primaryInk : Brand.muted).lineLimit(1)
                        }
                        .frame(width: 68)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(b.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// The board behind an editor preview: mint with a fine dot grid, like a design tool's canvas.
struct CanvasStage<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            .padding(Brand.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Brand.surface2
                    Canvas { ctx, size in
                        let step: CGFloat = 18
                        var y: CGFloat = step / 2
                        while y < size.height {
                            var x: CGFloat = step / 2
                            while x < size.width {
                                ctx.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(Brand.lineStrong))
                                x += step
                            }
                            y += step
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottom) { Divider().overlay(Brand.line) }
    }
}

// MARK: - Moving the text on the canvas

extension CGSize {
    /// Keeps dragged text on the canvas: ±25 % across, ±35 % up and down.
    var clampedTextOffset: CGSize {
        CGSize(width: min(max(width, -0.25), 0.25), height: min(max(height, -0.35), 0.35))
    }
}

/// Lets the person drag the text block on the preview, as in design tools. The offset is a fraction
/// of the canvas, so the exported image and video place it the same way at full size.
struct TextDrag: ViewModifier {
    @Binding var offset: CGSize
    @State private var start: CGSize?

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { g in
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 4)
                        .onChanged { v in
                            let s = start ?? offset
                            if start == nil { start = offset }
                            // Preview and export both draw right-to-left, so the offset means the same in each.
                            offset = CGSize(width: s.width + v.translation.width / max(g.size.width, 1),
                                            height: s.height + v.translation.height / max(g.size.height, 1)).clampedTextOffset
                        }
                        .onEnded { _ in start = nil })
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func textDrag(_ offset: Binding<CGSize>) -> some View { modifier(TextDrag(offset: offset)) }
}

/// Row under the size picker: drag hint, or a way back to the centre.
struct TextPositionRow: View {
    @Binding var offset: CGSize
    var body: some View {
        HStack {
            Label("اسحب النص في المعاينة لتغيير موضعه", systemImage: "hand.draw")
                .font(.ui(.footnote)).foregroundStyle(Brand.muted)
            Spacer()
            if offset != .zero {
                Button("توسيط") { withAnimation(.snappy) { offset = .zero } }.font(.ui(.footnote, .semibold))
            }
        }
    }
}

// MARK: - Ready styles (one tap sets size, background and text size)

struct StylePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let ratio: CardOptions.Ratio
    let backgroundID: String
    let fontScale: Double

    var background: CardOptions.Background { CardOptions.backgrounds.first { $0.id == backgroundID } ?? CardOptions.backgrounds[0] }

    static let all: [StylePreset] = [
        .init(id: "status", name: "حالة زمردية", ratio: .story, backgroundID: "emerald", fontScale: 1.15),
        .init(id: "post-dawn", name: "منشور الفجر", ratio: .portrait, backgroundID: "dawn", fontScale: 1),
        .init(id: "night", name: "مربع ليلي", ratio: .square, backgroundID: "night", fontScale: 1),
        .init(id: "sand", name: "رملي هادئ", ratio: .portrait, backgroundID: "sand", fontScale: 1),
        .init(id: "dusk", name: "حالة الغروب", ratio: .story, backgroundID: "dusk", fontScale: 1),
        .init(id: "youtube", name: "يوتيوب حبر", ratio: .wide, backgroundID: "ink", fontScale: 0.85),
    ]
}

/// Strip of ready styles, each drawn at its size and colours.
struct StylePresetPicker: View {
    let current: (ratio: CardOptions.Ratio, backgroundID: String, fontScale: Double)
    let pick: (StylePreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: Brand.Space.s) {
                ForEach(StylePreset.all) { p in
                    let on = p.ratio == current.ratio && p.backgroundID == current.backgroundID && p.fontScale == current.fontScale
                    Button { pick(p) } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(p.background.gradient)
                                .overlay(StarMark().frame(width: 12, height: 12).opacity(0.9))
                                .aspectRatio(p.ratio.size.width / p.ratio.size.height, contentMode: .fit)
                                .frame(height: 64)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Brand.accent : Brand.line, lineWidth: on ? 2.5 : 1))
                            Text(p.name).font(.ui(.caption2, on ? .semibold : .regular))
                                .foregroundStyle(on ? Brand.primaryInk : Brand.muted).lineLimit(1)
                        }
                        .frame(minWidth: 70)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("نمط \(p.name)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Design editor layout (v3)

/// Editor as a design tool: the board (preview) stays in view — on top on iPhone, beside the steps on
/// iPad — and the steps scroll in site-style cards.
struct DesignEditorLayout<Preview: View, Controls: View>: View {
    @Environment(\.horizontalSizeClass) private var size
    let preview: Preview
    @ViewBuilder let controls: () -> Controls

    init(preview: Preview, @ViewBuilder controls: @escaping () -> Controls) {
        self.preview = preview
        self.controls = controls
    }

    var body: some View {
        if size == .regular {
            HStack(spacing: 0) {
                CanvasStage { preview.padding(24) }
                Divider()
                steps.frame(width: 460)
            }
        } else {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    CanvasStage { preview }
                        .frame(height: min(max(geo.size.height * 0.40, 230), 380))
                    steps
                }
            }
        }
    }

    private var steps: some View {
        ScrollView {
            VStack(spacing: Brand.Space.m) { controls() }
                .padding(Brand.Space.l)
                .padding(.bottom, Brand.Space.xl)
        }
        .background(Brand.background)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// One numbered step of an editor (the site's ① ② ③ cards).
struct EditorStep<Content: View>: View {
    let number: Int
    let title: String
    let detail: String?
    let content: Content
    init(_ number: Int, _ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.number = number; self.title = title; self.detail = detail; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            StepHeader(number, title, detail: detail)
            content
        }
        .padding(Brand.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.raised)
    }
}

/// Labelled field box (the site's inputs: mint fill, fine border, radius 12).
struct EditorField<Content: View>: View {
    let label: String
    let content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ui(.caption, .semibold)).foregroundStyle(Brand.muted)
            HStack { content }
                .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        }
    }
}
