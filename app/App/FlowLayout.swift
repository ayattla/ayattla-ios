import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

/// Simple wrapping layout that respects the layout direction.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var centered = true

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, used: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            used = max(used, x + s.width)
            x += s.width + spacing; row = max(row, s.height)
        }
        // Never wider than offered (a long chip is clipped to the row, not the screen). Centred rows
        // take the whole offered width so they sit in the middle of it.
        let w = centered && proposal.width != nil ? width : min(used, width)
        return CGSize(width: w, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Rows first, so each row can be centred (owner, 13 Nov: content in the middle, not on the side).
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.width, x > 0 { rows.append([]); x = 0 }
            rows[rows.count - 1].append((i, s))
            x += s.width + spacing
        }
        var y: CGFloat = 0
        for r in rows where !r.isEmpty {
            let rowWidth = r.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(r.count - 1)
            let height = r.map(\.1.height).max() ?? 0
            var cx = centered ? max((bounds.width - rowWidth) / 2, 0) : 0
            for (i, s) in r {
                // Placed from the leading edge; SwiftUI mirrors leading/trailing in right-to-left.
                subviews[i].place(at: CGPoint(x: bounds.minX + cx, y: bounds.minY + y + (height - s.height) / 2), proposal: .unspecified)
                cx += s.width + spacing
            }
            y += height + spacing
        }
    }
}
