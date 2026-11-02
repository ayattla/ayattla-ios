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

    var body: some View {
        if size == .regular {
            HStack(spacing: 0) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                    .background(Color(.systemGroupedBackground))
                Divider()
                Form { controls() }
                    .frame(width: 420)
            }
        } else {
            Form {
                Section {
                    preview.frame(maxWidth: .infinity, maxHeight: 400)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                controls()
            }
        }
    }
}
