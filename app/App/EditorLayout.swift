import SwiftUI
import AyatDesign

/// Editors on iPhone: the preview on top of the options form. On iPad (regular width): two
/// columns, a large preview beside the options (docs/APP_ARCHITECTURE.md §1).
struct EditorLayout<Preview: View, Controls: View>: View {
    @Environment(\.horizontalSizeClass) private var size
    let preview: Preview
    @ViewBuilder let controls: () -> Controls

    init(preview: Preview, @ViewBuilder controls: @escaping () -> Controls) {
        self.preview = preview
        self.controls = controls
    }

    /// Like a design tool: the preview stays on a canvas stage while the options scroll —
    /// pinned above them on iPhone, beside them on iPad.
    var body: some View {
        if size == .regular {
            HStack(spacing: 0) {
                CanvasStage { preview.padding(16) }
                Divider()
                Form {
Group { controls()
}.listRowBackground(Brand.surface)
}
                    .scrollContentBackground(.hidden)
                    .background(Brand.background)
                    .frame(width: 420)
            }
        } else {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    CanvasStage { preview }
                        .frame(height: min(max(geo.size.height * 0.40, 220), 380))
                    Divider()
                    Form {
Group { controls()
}.listRowBackground(Brand.surface)
}
                        .scrollContentBackground(.hidden)
                        .background(Brand.background)
                }
            }
        }
    }
}
