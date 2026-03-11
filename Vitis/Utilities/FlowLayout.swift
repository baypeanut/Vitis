//
//  FlowLayout.swift
//  Pari
//
//  Reusable wrapping flow layout for tag chips.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (i, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[i].minX, y: bounds.minY + result.frames[i].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            for subview in subviews {
                let s = subview.sizeThatFits(.unspecified)
                if x + s.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(x: x, y: y, width: s.width, height: s.height))
                lineHeight = max(lineHeight, s.height)
                x += s.width + spacing
            }
            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
