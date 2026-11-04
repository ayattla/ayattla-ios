import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

/// Simple wrapping layout that respects the layout direction.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, used: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            used = max(used, x + s.width)
            x += s.width + spacing; row = max(row, s.height)
        }
        // Never wider than offered (a long chip is clipped to the row, not the screen).
        return CGSize(width: min(used, width), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.width, x > 0 { x = 0; y += row + spacing; row = 0 }
            // Placed from the leading edge; SwiftUI mirrors leading/trailing in right-to-left.
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += s.width + spacing; row = max(row, s.height)
        }
    }
}
