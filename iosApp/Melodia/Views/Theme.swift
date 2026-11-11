import SwiftUI

enum MelodiaTheme {
    static let background = Color(red: 0.045, green: 0.048, blue: 0.058)
    static let backgroundRaised = Color(red: 0.075, green: 0.079, blue: 0.094)
    static let surface = Color(red: 0.105, green: 0.110, blue: 0.128)
    static let surfaceLight = Color(red: 0.155, green: 0.160, blue: 0.184)
    static let accent = Color(red: 0.910, green: 0.278, blue: 0.220)
    static let accentSoft = Color(red: 0.980, green: 0.365, blue: 0.285)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
    static let divider = Color.white.opacity(0.08)

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.35, green: 0.06, blue: 0.05).opacity(0.72),
            background
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coverPlaceholder = LinearGradient(
        colors: [surfaceLight, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum MelodiaMotion {
    static let spring = Animation.spring(response: 0.46, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.86)
    static let gentle = Animation.easeInOut(duration: 0.32)
    static let fade = Animation.easeOut(duration: 0.24)
}

struct MelodiaPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var pressedOpacity: Double = 0.86

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(MelodiaMotion.snappy, value: configuration.isPressed)
    }
}

struct MelodiaRevealModifier: ViewModifier {
    var delay: Double
    var offset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : offset)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(MelodiaMotion.gentle.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    func melodiaScreen() -> some View {
        self
            .background(MelodiaTheme.background.ignoresSafeArea())
            .tint(MelodiaTheme.accent)
    }
}

struct MelodiaCardModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(MelodiaTheme.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func melodiaCard(radius: CGFloat = 20) -> some View {
        modifier(MelodiaCardModifier(radius: radius))
    }

    func melodiaPressable(scale: CGFloat = 0.96) -> some View {
        buttonStyle(MelodiaPressStyle(scale: scale))
    }

    func melodiaReveal(delay: Double = 0, offset: CGFloat = 10) -> some View {
        modifier(MelodiaRevealModifier(delay: delay, offset: offset))
    }
}
