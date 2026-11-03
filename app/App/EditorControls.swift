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

/// The canvas stage behind an editor preview: soft ivory with the lattice, like a design board.
struct CanvasStage<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
            .padding(Brand.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Brand.surface2
                    IslamicPattern(cell: 40, color: Brand.accent.opacity(0.14))
                }
            }
    }
}
