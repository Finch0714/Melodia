import CoreText
import SwiftUI
import UIKit

struct ClassicKaraokeText: UIViewRepresentable {
    let text: String
    let words: [LyricWord]
    let time: TimeInterval
    let fallbackProgress: Double
    let fontSize: CGFloat
    let alignment: LyricAlignmentSetting
    let glowEnabled: Bool
    let shadowEnabled: Bool

    func makeUIView(context: Context) -> KaraokeLineUIView {
        let view = KaraokeLineUIView()
        configure(view)
        return view
    }

    func updateUIView(_ uiView: KaraokeLineUIView, context: Context) {
        configure(uiView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: KaraokeLineUIView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width.isFinite, width > 1 else { return nil }
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: measured.height)
    }

    private func configure(_ view: KaraokeLineUIView) {
        view.configure(
            text: text,
            words: words,
            time: time,
            fallbackProgress: fallbackProgress,
            fontSize: fontSize,
            alignment: alignment,
            glowEnabled: glowEnabled,
            shadowEnabled: shadowEnabled
        )
    }
}

final class KaraokeLineUIView: UIView {
    private struct LayoutKey: Equatable {
        let text: String
        let fontSize: CGFloat
        let width: CGFloat
        let alignment: LyricAlignmentSetting
    }

    private struct VisualLine {
        let range: NSRange
        let textRange: NSRange
        let left: CGFloat
        let right: CGFloat
        let top: CGFloat
        let bottom: CGFloat
    }

    private struct TimedWord {
        let start: TimeInterval
        let end: TimeInterval
        let left: CGFloat
        let right: CGFloat
        let lineIndex: Int
    }

    private struct LineLayout {
        let size: CGSize
        let baseFrame: CTFrame
        let highlightFrame: CTFrame
        let lines: [VisualLine]
        let words: [TimedWord]
    }

    private var text = ""
    private var words = [LyricWord]()
    private var time: TimeInterval = 0
    private var fallbackProgress: Double = 0
    private var fontSize: CGFloat = 22
    private var alignment: LyricAlignmentSetting = .center
    private var glowEnabled = true
    private var shadowEnabled = true
    private var cachedLayout: LineLayout?
    private var cachedKey: LayoutKey?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        text: String,
        words: [LyricWord],
        time: TimeInterval,
        fallbackProgress: Double,
        fontSize: CGFloat,
        alignment: LyricAlignmentSetting,
        glowEnabled: Bool,
        shadowEnabled: Bool
    ) {
        let layoutChanged = self.text != text
            || self.fontSize != fontSize
            || self.alignment != alignment
        self.text = text
        self.words = words
        self.time = time
        self.fallbackProgress = fallbackProgress
        self.fontSize = fontSize
        self.alignment = alignment
        self.glowEnabled = glowEnabled
        self.shadowEnabled = shadowEnabled
        accessibilityLabel = text

        if layoutChanged {
            cachedLayout = nil
            cachedKey = nil
            invalidateIntrinsicContentSize()
        }
        setNeedsDisplay()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = max(1, size.width)
        return layout(for: width).size
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), bounds.width > 1 else { return }
        let layout = layout(for: bounds.width)
        let height = layout.size.height

        if shadowEnabled {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.35).cgColor
            )
            draw(frame: layout.baseFrame, context: context, height: height)
            context.restoreGState()
        } else {
            draw(frame: layout.baseFrame, context: context, height: height)
        }

        let clips = highlightClips(in: layout)
        if !clips.isEmpty {
            context.saveGState()
            context.clip(to: clips)
            draw(frame: layout.highlightFrame, context: context, height: height)
            context.restoreGState()
        }

        guard glowEnabled else { return }
        let blocks = activeWordBlocks(in: layout)
        guard !blocks.isEmpty else { return }
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for block in blocks {
            context.setFillColor(UIColor.white.withAlphaComponent(0.22 * block.alpha).cgColor)
            context.fill(block.rect)
        }
        context.restoreGState()
    }

    private func draw(frame: CTFrame, context: CGContext, height: CGFloat) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private func layout(for width: CGFloat) -> LineLayout {
        let roundedWidth = max(1, floor(width * UIScreen.main.scale) / UIScreen.main.scale)
        let key = LayoutKey(
            text: text,
            fontSize: fontSize,
            width: roundedWidth,
            alignment: alignment
        )
        if key == cachedKey, let cachedLayout {
            return cachedLayout
        }

        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let lineHeight = fontSize * 1.35
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = paragraphAlignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.lineSpacing = 0

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.30),
            .paragraphStyle: paragraph
        ]
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        let baseString = NSAttributedString(string: text, attributes: baseAttributes)
        let highlightString = NSAttributedString(string: text, attributes: highlightAttributes)

        let constraint = CGSize(width: roundedWidth, height: .greatestFiniteMagnitude)
        let baseFramesetter = CTFramesetterCreateWithAttributedString(baseString)
        let highlightFramesetter = CTFramesetterCreateWithAttributedString(highlightString)
        var fitRange = CFRange()
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            baseFramesetter,
            CFRange(location: 0, length: 0),
            nil,
            constraint,
            &fitRange
        )
        let height = ceil(max(suggested.height, lineHeight))
        let path = CGPath(
            rect: CGRect(x: 0, y: 0, width: roundedWidth, height: height),
            transform: nil
        )
        let baseFrame = CTFramesetterCreateFrame(
            baseFramesetter,
            CFRange(location: 0, length: 0),
            path,
            nil
        )
        let highlightFrame = CTFramesetterCreateFrame(
            highlightFramesetter,
            CFRange(location: 0, length: 0),
            path,
            nil
        )

        let ctLines = CTFrameGetLines(highlightFrame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: ctLines.count)
        origins.withUnsafeMutableBufferPointer { buffer in
            guard let address = buffer.baseAddress else { return }
            CTFrameGetLineOrigins(
                highlightFrame,
                CFRange(location: 0, length: 0),
                address
            )
        }

        let nsText = text as NSString
        var visualLines = [VisualLine]()
        for (index, line) in ctLines.enumerated() {
            let range = CTLineGetStringRange(line)
            let lineRange = NSRange(location: range.location, length: range.length)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            let originX = origins[index].x
            let baselineY = height - origins[index].y
            let verticalPadding = max(0, (lineHeight - ascent - descent) / 2)
            let textLength = nsText.length
            let textRange = NSIntersectionRange(
                lineRange,
                NSRange(location: 0, length: max(0, textLength))
            )
            let leftIndex = textRange.length > 0 ? textRange.location : lineRange.location
            let rightIndex = textRange.length > 0
                ? textRange.location + textRange.length
                : lineRange.location + lineRange.length
            let left = originX + CGFloat(CTLineGetOffsetForStringIndex(line, leftIndex, nil))
            let right = originX + CGFloat(CTLineGetOffsetForStringIndex(line, rightIndex, nil))

            visualLines.append(
                VisualLine(
                    range: lineRange,
                    textRange: textRange,
                    left: min(left, right),
                    right: max(left, right),
                    top: baselineY - ascent - verticalPadding,
                    bottom: baselineY + descent + verticalPadding
                )
            )
        }

        let timedWords = timedWordLayouts(lines: visualLines, nsText: nsText, ctLines: ctLines)
        let layout = LineLayout(
            size: CGSize(width: roundedWidth, height: height),
            baseFrame: baseFrame,
            highlightFrame: highlightFrame,
            lines: visualLines,
            words: timedWords
        )
        cachedLayout = layout
        cachedKey = key
        return layout
    }

    private var paragraphAlignment: NSTextAlignment {
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    private func timedWordLayouts(
        lines: [VisualLine],
        nsText: NSString,
        ctLines: [CTLine]
    ) -> [TimedWord] {
        guard !words.isEmpty, !lines.isEmpty else { return [] }
        var result = [TimedWord]()
        var cursor = 0

        for word in words {
            let clean = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let searchLocation = min(cursor, nsText.length)
            let searchRange = NSRange(
                location: searchLocation,
                length: max(0, nsText.length - searchLocation)
            )
            var wordRange = nsText.range(of: clean, options: [], range: searchRange)
            if wordRange.location == NSNotFound {
                let length = min(clean.utf16.count, nsText.length - searchLocation)
                guard length > 0 else { continue }
                wordRange = NSRange(location: searchLocation, length: length)
            }
            cursor = wordRange.location + wordRange.length

            let totalLength = max(1, wordRange.length)
            for (lineIndex, line) in lines.enumerated() {
                let intersection = NSIntersectionRange(wordRange, line.textRange)
                guard intersection.length > 0 else { continue }

                let raw = nsText.substring(with: intersection)
                let leading = raw.prefix(while: { $0.isWhitespace }).utf16.count
                let trailing = raw.reversed().prefix(while: { $0.isWhitespace }).count
                let startOffset = intersection.location + leading
                let endOffset = intersection.location + intersection.length - trailing
                guard endOffset > startOffset else { continue }

                let startRatio = Double(intersection.location - wordRange.location) / Double(totalLength)
                let endRatio = Double(intersection.location + intersection.length - wordRange.location)
                    / Double(totalLength)
                let duration = max(0, word.duration)
                let start = word.start + duration * startRatio
                let end = word.start + duration * endRatio
                let ctLine = ctLines[lineIndex]
                let left = line.left + CGFloat(CTLineGetOffsetForStringIndex(
                    ctLine,
                    startOffset,
                    nil
                )) - CGFloat(CTLineGetOffsetForStringIndex(
                    ctLine,
                    line.textRange.location,
                    nil
                ))
                let right = line.left + CGFloat(CTLineGetOffsetForStringIndex(
                    ctLine,
                    endOffset,
                    nil
                )) - CGFloat(CTLineGetOffsetForStringIndex(
                    ctLine,
                    line.textRange.location,
                    nil
                ))

                result.append(
                    TimedWord(
                        start: start,
                        end: end,
                        left: max(line.left, min(left, right)),
                        right: min(line.right, max(left, right)),
                        lineIndex: lineIndex
                    )
                )
            }
        }
        return result
    }

    private func highlightClips(in layout: LineLayout) -> [CGRect] {
        var rects = [CGRect]()
        for (lineIndex, line) in layout.lines.enumerated() {
            let lineWords = layout.words.filter { $0.lineIndex == lineIndex }
            if let last = lineWords.last, time >= last.end {
                rects.append(rect(for: line))
                continue
            }

            var maxRight = line.left
            for word in lineWords {
                if time >= word.end {
                    maxRight = max(maxRight, word.right)
                } else if time >= word.start {
                    let duration = max(word.end - word.start, 0.001)
                    let ratio = min(max((time - word.start) / duration, 0), 1)
                    maxRight = max(maxRight, word.left + (word.right - word.left) * ratio)
                }
            }

            if maxRight > line.left + 0.5 {
                rects.append(CGRect(
                    x: line.left,
                    y: line.top,
                    width: min(maxRight, line.right) - line.left,
                    height: line.bottom - line.top
                ))
            }
        }

        if layout.words.isEmpty, !layout.lines.isEmpty {
            let progress = min(max(fallbackProgress, 0), 1)
            guard progress > 0 else { return [] }
            for line in layout.lines {
                rects.append(CGRect(
                    x: line.left,
                    y: line.top,
                    width: (line.right - line.left) * progress,
                    height: line.bottom - line.top
                ))
            }
        }
        return rects
    }

    private func activeWordBlocks(in layout: LineLayout) -> [(rect: CGRect, alpha: Double)] {
        var blocks = [(CGRect, Double)]()
        for word in layout.words {
            guard time >= word.start, time <= word.end else { continue }
            let duration = max(word.end - word.start, 0.001)
            let ratio = min(max((time - word.start) / duration, 0), 1)
            let pulse = sin(ratio * .pi)
            guard pulse > 0.001 else { continue }
            let line = layout.lines[word.lineIndex]
            let rect = CGRect(
                x: word.left,
                y: line.top,
                width: max(0, word.right - word.left),
                height: max(0, line.bottom - line.top)
            )
            blocks.append((rect, pulse))
        }
        return blocks
    }

    private func rect(for line: VisualLine) -> CGRect {
        CGRect(
            x: line.left,
            y: line.top,
            width: line.right - line.left,
            height: line.bottom - line.top
        )
    }
}