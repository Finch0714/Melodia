import SwiftUI
import UIKit

struct LyricFlowLine: View {
    let line: LyricLine
    let nextLineTime: TimeInterval
    let playbackTime: Double
    let isPlaying: Bool
    let fontSize: CGFloat
    var alignment: LyricAlignmentSetting = .center
    var style: KaraokeEffectStyle = .melodia
    var glowEnabled: Bool = true

    @AppStorage(MelodiaSettings.lyricShadowKey) private var lyricTextShadow = true

    @State private var referenceTime: Double = 0
    @State private var referenceDate = Date()

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                MelodiaTheme.accentSoft,
                Color.white.opacity(0.94)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var textFont: Font {
        .system(size: fontSize, weight: .bold)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            let time = displayTime(at: context.date)
            let progress = flowProgress(at: time)
            let pulse = 0.5 + 0.5 * sin(time * 3.4)

            ZStack(alignment: .center) {
                Text(line.text)
                    .font(textFont)
                    .foregroundStyle(Color.white.opacity(0.30))
                    .multilineTextAlignment(alignment.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                    .shadow(color: lyricTextShadow ? .black.opacity(0.32) : .clear, radius: 2, y: 1)

                if style == .melodia {
                    melodiaHighlightedText(progress: progress, pulse: pulse)
                } else {
                    classicHighlightedText(progress: progress)
                    classicWordBlock(at: time, pulse: pulse)
                }
            }
            .frame(maxWidth: .infinity)
            .compositingGroup()
        }
        .onAppear {
            syncReference()
        }
        .onChange(of: playbackTime) { _ in
            syncReference()
        }
        .onChange(of: line.id) { _ in
            syncReference()
        }
    }

    @ViewBuilder
    private func melodiaHighlightedText(progress: Double, pulse: Double) -> some View {
        Text(line.text)
            .font(textFont)
            .foregroundStyle(activeGradient)
            .multilineTextAlignment(alignment.textAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .mask(alignment: .leading) {
                flowMask(progress: progress)
            }
            .shadow(
                color: glowEnabled
                    ? MelodiaTheme.accentSoft.opacity(0.34 + 0.32 * pulse)
                    : .clear,
                radius: glowEnabled ? CGFloat(9 + 3 * pulse) : 0
            )

        if glowEnabled && progress > 0.001 && progress < 0.999 {
            GeometryReader { geometry in
                let x = geometry.size.width * progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.92),
                                MelodiaTheme.accentSoft.opacity(0.72),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 34, height: max(18, fontSize * 1.45))
                    .blur(radius: 5)
                    .position(x: x, y: geometry.size.height / 2)
                    .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func classicHighlightedText(progress: Double) -> some View {
        Text(line.text)
            .font(textFont)
            .foregroundStyle(Color.white)
            .multilineTextAlignment(alignment.textAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .mask(alignment: .leading) {
                GeometryReader { geometry in
                    let containerWidth = max(geometry.size.width, 1)
                    let textWidth = measuredTextWidth(limit: containerWidth)
                    let originX = textOriginX(containerWidth: containerWidth, textWidth: textWidth)
                    let front = originX + textWidth * min(max(progress, 0), 1)

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: max(0, front))
                        Spacer(minLength: 0)
                    }
                }
            }
            .shadow(color: lyricTextShadow ? .black.opacity(0.35) : .clear, radius: 2, y: 1)
    }

    @ViewBuilder
    private func classicWordBlock(at time: Double, pulse: Double) -> some View {
        if glowEnabled, let block = activeWordBlock(at: time) {
            GeometryReader { geometry in
                let containerWidth = max(geometry.size.width, 1)
                let textWidth = measuredTextWidth(limit: containerWidth)
                let originX = textOriginX(containerWidth: containerWidth, textWidth: textWidth)
                let startX = originX + textWidth * block.start
                let endX = originX + textWidth * block.end
                let width = max(10, endX - startX)
                let height = max(20, fontSize * 1.45)

                Rectangle()
                    .fill(Color.white.opacity(0.22 * block.pulse))
                    .frame(width: width, height: height)
                    .position(x: (startX + endX) / 2, y: geometry.size.height / 2)
                    .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)
        }
    }

    private func syncReference() {
        referenceTime = playbackTime
        referenceDate = Date()
    }

    private func displayTime(at date: Date) -> Double {
        guard isPlaying else { return max(0, playbackTime) }
        let elapsed = min(max(date.timeIntervalSince(referenceDate), 0), 0.6)
        return max(0, referenceTime + elapsed)
    }

    private func flowProgress(at time: Double) -> Double {
        if !line.words.isEmpty {
            let weights = line.words.map { max(1, $0.text.count) }
            let total = max(1, weights.reduce(0, +))
            var consumed = 0.0

            for (index, word) in line.words.enumerated() {
                if time >= word.end {
                    consumed += Double(weights[index])
                } else if time > word.start {
                    let duration = max(word.end - word.start, 0.001)
                    consumed += Double(weights[index]) * ((time - word.start) / duration)
                    break
                } else {
                    break
                }
            }
            return min(max(consumed / Double(total), 0), 1)
        }

        let span = max(nextLineTime - line.time, 0.45)
        return min(max((time - line.time) / span, 0), 1)
    }

    private func activeWordBlock(at time: Double) -> (start: Double, end: Double, pulse: Double)? {
        guard !line.words.isEmpty else { return nil }
        let weights = line.words.map { max(1, $0.text.count) }
        let total = max(1, weights.reduce(0, +))
        var consumed = 0

        for word in line.words {
            let weight = max(1, word.text.count)
            let start = Double(consumed) / Double(total)
            let end = Double(consumed + weight) / Double(total)
            consumed += weight

            guard time >= word.start, time < word.end else { continue }
            let duration = max(word.end - word.start, 0.001)
            let ratio = min(max((time - word.start) / duration, 0), 1)
            return (start, end, sin(ratio * .pi))
        }
        return nil
    }

    private func measuredTextWidth(limit: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (line.text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
        return min(limit, max(1, ceil(rect.width)))
    }

    private func textOriginX(containerWidth: CGFloat, textWidth: CGFloat) -> CGFloat {
        switch alignment {
        case .left: return 0
        case .center: return max(0, (containerWidth - textWidth) / 2)
        case .right: return max(0, containerWidth - textWidth)
        }
    }

    @ViewBuilder
    private func flowMask(progress: Double) -> some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let clamped = min(max(progress, 0), 1)

            if clamped >= 0.999 {
                Rectangle().fill(Color.white)
            } else {
                let front = width * clamped
                let feather = max(8, width * 0.055)
                let solid = min(max((front - feather) / width, 0), 1)
                let fade = min(max(front / width, 0), 1)

                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: solid),
                                .init(color: .clear, location: max(solid, fade)),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
}