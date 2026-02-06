//
//  RichTextView.swift
//  gym app
//
//  Renders text with colored hashtags and mentions.
//  Hashtags render in accent color, mentions in bold accent.
//

import SwiftUI

struct RichTextView: View {
    let text: String
    let font: Font
    let textColor: Color
    var onHashtagTap: ((String) -> Void)? = nil
    var onMentionTap: ((String) -> Void)? = nil

    init(
        _ text: String,
        font: Font = .body,
        textColor: Color = AppColors.textPrimary,
        onHashtagTap: ((String) -> Void)? = nil,
        onMentionTap: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.onHashtagTap = onHashtagTap
        self.onMentionTap = onMentionTap
    }

    var body: some View {
        if hasTappableContent {
            // Use layout with tappable tokens
            tappableContent
        } else {
            // Simple concatenated Text for non-interactive use
            buildAttributedText()
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    private var hasTappableContent: Bool {
        (onHashtagTap != nil || onMentionTap != nil) &&
        TextParser.containsRichContent(text)
    }

    // MARK: - Simple Attributed Text (no taps)

    private func buildAttributedText() -> Text {
        let tokens = TextParser.parse(text)
        guard !tokens.isEmpty else { return Text("") }

        var result = Text("")
        for token in tokens {
            switch token.type {
            case .text:
                result = result + Text(token.text)
                    .font(font)
                    .foregroundColor(textColor)
            case .hashtag:
                result = result + Text(token.text)
                    .font(font)
                    .foregroundColor(AppColors.dominant)
            case .mention:
                result = result + Text(token.text)
                    .font(font.weight(.semibold))
                    .foregroundColor(AppColors.accent2)
            }
        }
        return result
    }

    // MARK: - Tappable Content

    private var tappableContent: some View {
        let tokens = TextParser.parse(text)

        return WrappingHStack(tokens: tokens, font: font, textColor: textColor) { token in
            switch token.type {
            case .hashtag:
                onHashtagTap?(token.value)
            case .mention:
                onMentionTap?(token.value)
            case .text:
                break
            }
        }
    }
}

// MARK: - Wrapping HStack for Tappable Tokens

/// Displays tokens inline with tap support, using a flow layout
private struct WrappingHStack: View {
    let tokens: [ParsedToken]
    let font: Font
    let textColor: Color
    let onTap: (ParsedToken) -> Void

    var body: some View {
        // For tappable content, split each token into words and render inline
        // This gives a natural text flow while making hashtags/mentions tappable
        let elements = buildElements()

        RichTextFlowLayout(spacing: 0) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                element.view
            }
        }
    }

    private struct Element {
        let view: AnyView
    }

    private func buildElements() -> [Element] {
        var elements: [Element] = []

        for token in tokens {
            switch token.type {
            case .text:
                // Render plain text as non-tappable
                elements.append(Element(view: AnyView(
                    Text(token.text)
                        .font(font)
                        .foregroundColor(textColor)
                        .lineSpacing(4)
                )))
            case .hashtag:
                elements.append(Element(view: AnyView(
                    Button {
                        onTap(token)
                    } label: {
                        Text(token.text)
                            .font(font)
                            .foregroundColor(AppColors.dominant)
                    }
                    .buttonStyle(.plain)
                )))
            case .mention:
                elements.append(Element(view: AnyView(
                    Button {
                        onTap(token)
                    } label: {
                        Text(token.text)
                            .font(font.weight(.semibold))
                            .foregroundColor(AppColors.accent2)
                    }
                    .buttonStyle(.plain)
                )))
            }
        }

        return elements
    }
}

// MARK: - Flow Layout

/// Simple flow layout that wraps content naturally
private struct RichTextFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX)
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}
