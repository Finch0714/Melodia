import SwiftUI

enum MelodiaSettings {
    static let lyricFontSizeKey = "melodia.lyrics.fontSize"
    static let lyricLineSpacingKey = "melodia.lyrics.lineSpacing"
    static let lyricSecondarySpacingKey = "melodia.lyrics.secondarySpacing"
    static let lyricAlignmentKey = "melodia.lyrics.alignment"
    static let lyricSecondaryModeKey = "melodia.lyrics.secondaryMode"
    static let karaokeStyleKey = "melodia.lyrics.karaokeStyle"
    static let karaokeGlowKey = "melodia.lyrics.karaokeGlow"
    static let lyricShadowKey = "melodia.lyrics.textShadow"
    static let showMiniLyricKey = "melodia.player.showMiniLyric"
    static let backgroundStyleKey = "melodia.player.backgroundStyle"
    static let showQualityBadgeKey = "melodia.player.showQualityBadge"
    static let coverCornerRadiusKey = "melodia.player.coverCornerRadius"
    static let wideLandscapeKey = "melodia.player.wideLandscape"
    static let keepScreenAwakeKey = "melodia.system.keepScreenAwake"
    static let mixWithOthersKey = "melodia.audio.mixWithOthers"
    static let autoResumeKey = "melodia.audio.autoResume"
    static let requestTimeoutKey = "melodia.network.requestTimeout"

    static let defaultLyricFontSize = 22.0
    static let defaultLyricLineSpacing = 24.0
    static let defaultLyricSecondarySpacing = 6.0
    static let defaultCoverCornerRadius = 28.0
    static let defaultRequestTimeout = 20.0

    static let allKeys = [
        lyricFontSizeKey,
        lyricLineSpacingKey,
        lyricSecondarySpacingKey,
        lyricAlignmentKey,
        lyricSecondaryModeKey,
        karaokeStyleKey,
        karaokeGlowKey,
        lyricShadowKey,
        showMiniLyricKey,
        backgroundStyleKey,
        showQualityBadgeKey,
        coverCornerRadiusKey,
        wideLandscapeKey,
        keepScreenAwakeKey,
        mixWithOthersKey,
        autoResumeKey,
        requestTimeoutKey
    ]

    static func resetAppearanceAndLyrics() {
        for key in allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

enum LyricAlignmentSetting: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "左对齐"
        case .center: return "居中"
        case .right: return "右对齐"
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

enum LyricSecondaryModeSetting: String, CaseIterable, Identifiable {
    case translation
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translation: return "显示翻译"
        case .hidden: return "关闭副歌词"
        }
    }
}

enum KaraokeEffectStyle: String, CaseIterable, Identifiable {
    case melodia
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .melodia: return "Melodia 流光"
        case .classic: return "原版光块"
        }
    }

    var subtitle: String {
        switch self {
        case .melodia: return "羽化扫光、强调色渐变与辉光"
        case .classic: return "白色半透明长方形逐字脉冲，还原原版"
        }
    }
}

enum PlayerBackgroundStyle: String, CaseIterable, Identifiable {
    case cover
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cover: return "封面模糊背景"
        case .solid: return "纯色背景"
        }
    }
}