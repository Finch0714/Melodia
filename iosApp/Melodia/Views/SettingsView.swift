import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var player: PlayerEngine

    @AppStorage(MelodiaSettings.lyricFontSizeKey) private var lyricFontSize = MelodiaSettings.defaultLyricFontSize
    @AppStorage(MelodiaSettings.lyricLineSpacingKey) private var lyricLineSpacing = MelodiaSettings.defaultLyricLineSpacing
    @AppStorage(MelodiaSettings.lyricSecondarySpacingKey) private var lyricSecondarySpacing = MelodiaSettings.defaultLyricSecondarySpacing
    @AppStorage(MelodiaSettings.lyricAlignmentKey) private var lyricAlignmentRaw = LyricAlignmentSetting.center.rawValue
    @AppStorage(MelodiaSettings.lyricSecondaryModeKey) private var lyricSecondaryModeRaw = LyricSecondaryModeSetting.translation.rawValue
    @AppStorage(MelodiaSettings.karaokeStyleKey) private var karaokeStyleRaw = KaraokeEffectStyle.melodia.rawValue
    @AppStorage(MelodiaSettings.karaokeGlowKey) private var karaokeGlow = true
    @AppStorage(MelodiaSettings.lyricShadowKey) private var lyricTextShadow = true
    @AppStorage(MelodiaSettings.showMiniLyricKey) private var showMiniLyric = true
    @AppStorage(MelodiaSettings.backgroundStyleKey) private var backgroundStyleRaw = PlayerBackgroundStyle.cover.rawValue
    @AppStorage(MelodiaSettings.showQualityBadgeKey) private var showQualityBadge = true
    @AppStorage(MelodiaSettings.coverCornerRadiusKey) private var coverCornerRadius = MelodiaSettings.defaultCoverCornerRadius
    @AppStorage(MelodiaSettings.wideLandscapeKey) private var wideLandscape = true
    @AppStorage(MelodiaSettings.keepScreenAwakeKey) private var keepScreenAwake = false
    @AppStorage(MelodiaSettings.mixWithOthersKey) private var mixWithOthers = false
    @AppStorage(MelodiaSettings.autoResumeKey) private var autoResume = true
    @AppStorage(MelodiaSettings.requestTimeoutKey) private var requestTimeout = MelodiaSettings.defaultRequestTimeout

    @State private var showResetConfirm = false
    @State private var cacheSizeText = "计算中…"
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("默认音质", selection: qualityBinding) {
                    ForEach(AudioQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Picker("默认播放模式", selection: playbackModeBinding) {
                    ForEach(PlaybackMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("播放页显示音质标签", isOn: $showQualityBadge)
                Toggle("横屏使用双栏播放页", isOn: $wideLandscape)
                Toggle("保持屏幕常亮", isOn: $keepScreenAwake)
                Toggle("与其他应用同时播放", isOn: $mixWithOthers)
                Toggle("被系统打断后自动恢复", isOn: $autoResume)
            } header: {
                Text("播放与音质")
            } footer: {
                Text("双栏播放页在 iPad 或大屏横屏启用；关闭后统一使用可滚动的单列布局。同时播放会混入其他应用的音频；自动恢复会在来电或语音助手结束后继续播放。")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("歌词字号")
                        Spacer()
                        Text("\(Int(lyricFontSize))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .monospacedDigit()
                    }
                    Slider(value: $lyricFontSize, in: 16...34, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("歌词行间距")
                        Spacer()
                        Text("\(Int(lyricLineSpacing))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .monospacedDigit()
                    }
                    Slider(value: $lyricLineSpacing, in: 8...40, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("主副歌词间距")
                        Spacer()
                        Text("\(Int(lyricSecondarySpacing))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .monospacedDigit()
                    }
                    Slider(value: $lyricSecondarySpacing, in: 0...18, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }

                Picker("歌词对齐", selection: lyricAlignmentBinding) {
                    ForEach(LyricAlignmentSetting.allCases) { alignment in
                        Text(alignment.title).tag(alignment)
                    }
                }

                Picker("副歌词", selection: lyricSecondaryModeBinding) {
                    ForEach(LyricSecondaryModeSetting.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("逐字动效", selection: karaokeStyleBinding) {
                    ForEach(KaraokeEffectStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Toggle("逐字呼吸光效", isOn: $karaokeGlow)
                Toggle("歌词文字阴影", isOn: $lyricTextShadow)
                Toggle("播放页显示单行歌词", isOn: $showMiniLyric)
            } header: {
                Text("歌词")
            } footer: {
                Text("原版光块模式按 Android 端 KaraokeLyricRow 还原：当前字词覆盖白色半透明长方形，并以 0.22×正弦脉冲呼吸。")
            }

            Section {
                Picker("播放页背景", selection: backgroundStyleBinding) {
                    ForEach(PlayerBackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("封面圆角")
                        Spacer()
                        Text("\(Int(coverCornerRadius))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .monospacedDigit()
                    }
                    Slider(value: $coverCornerRadius, in: 0...38, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }
            } header: {
                Text("外观")
            }

            Section {
                Picker("请求超时", selection: $requestTimeout) {
                    Text("15 秒").tag(15.0)
                    Text("20 秒").tag(20.0)
                    Text("30 秒").tag(30.0)
                    Text("60 秒").tag(60.0)
                }
                .onChange(of: requestTimeout) { value in
                    Task {
                        await NeteaseClient.shared.setRequestTimeout(value)
                    }
                }

                HStack {
                    Text("网络与封面缓存")
                    Spacer()
                    Text(cacheSizeText)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }

                Button("清除缓存") {
                    URLCache.shared.removeAllCachedResponses()
                    Task {
                        await RemoteImageCache.shared.clear()
                        updateCacheSize()
                    }
                    statusMessage = "缓存已清除"
                }

                Button("清除搜索历史") {
                    UserDefaults.standard.removeObject(forKey: "melodia.search.history")
                    statusMessage = "搜索历史已清除"
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
            } header: {
                Text("网络与存储")
            } footer: {
                Text("当前版本未移植下载与本地音乐，因此这里提供网络超时和可清理的缓存空间。")
            }

            Section {
                LabeledContent("版本", value: appVersion)
                LabeledContent("构建", value: buildVersion)
                LabeledContent("音频引擎", value: "AVPlayer")

                Link(destination: URL(string: "https://github.com/Finch0714/Melodia")!) {
                    Label("项目地址", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/Finch0714/Melodia/releases")!) {
                    Label("检查更新与下载 IPA", systemImage: "arrow.down.circle")
                }

                Text("Melodia 仅用于个人学习与技术交流。音乐、封面及歌词版权归网易云音乐及原权利人所有。")
                    .font(.caption)
                    .foregroundStyle(MelodiaTheme.textSecondary)
            } header: {
                Text("关于")
            }

            Section {
                Button("恢复默认设置", role: .destructive) {
                    showResetConfirm = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            updateCacheSize()
            Task {
                await NeteaseClient.shared.setRequestTimeout(requestTimeout)
            }
        }
        .onChange(of: mixWithOthers) { _ in
            player.refreshAudioSession()
        }
        .alert("恢复默认设置？", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("歌词、外观和网络设置会恢复默认值，登录状态与播放队列不会受影响。")
        }
    }

    private var qualityBinding: Binding<AudioQuality> {
        Binding(
            get: { player.audioQuality },
            set: { player.selectQuality($0) }
        )
    }

    private var playbackModeBinding: Binding<PlaybackMode> {
        Binding(
            get: { player.playbackMode },
            set: { player.setPlaybackMode($0) }
        )
    }

    private var lyricAlignmentBinding: Binding<LyricAlignmentSetting> {
        Binding(
            get: { LyricAlignmentSetting(rawValue: lyricAlignmentRaw) ?? .center },
            set: { lyricAlignmentRaw = $0.rawValue }
        )
    }

    private var lyricSecondaryModeBinding: Binding<LyricSecondaryModeSetting> {
        Binding(
            get: { LyricSecondaryModeSetting(rawValue: lyricSecondaryModeRaw) ?? .translation },
            set: { lyricSecondaryModeRaw = $0.rawValue }
        )
    }

    private var karaokeStyleBinding: Binding<KaraokeEffectStyle> {
        Binding(
            get: { KaraokeEffectStyle(rawValue: karaokeStyleRaw) ?? .melodia },
            set: { karaokeStyleRaw = $0.rawValue }
        )
    }

    private var backgroundStyleBinding: Binding<PlayerBackgroundStyle> {
        Binding(
            get: { PlayerBackgroundStyle(rawValue: backgroundStyleRaw) ?? .cover },
            set: { backgroundStyleRaw = $0.rawValue }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
    }

    private func updateCacheSize() {
        Task {
            let disk = await RemoteImageCache.shared.diskSize()
            let bytes = Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage) + disk
            cacheSizeText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    private func resetSettings() {
        MelodiaSettings.resetAppearanceAndLyrics()
        lyricFontSize = MelodiaSettings.defaultLyricFontSize
        lyricLineSpacing = MelodiaSettings.defaultLyricLineSpacing
        lyricSecondarySpacing = MelodiaSettings.defaultLyricSecondarySpacing
        lyricAlignmentRaw = LyricAlignmentSetting.center.rawValue
        lyricSecondaryModeRaw = LyricSecondaryModeSetting.translation.rawValue
        karaokeStyleRaw = KaraokeEffectStyle.melodia.rawValue
        karaokeGlow = true
        lyricTextShadow = true
        showMiniLyric = true
        backgroundStyleRaw = PlayerBackgroundStyle.cover.rawValue
        showQualityBadge = true
        coverCornerRadius = MelodiaSettings.defaultCoverCornerRadius
        wideLandscape = true
        keepScreenAwake = false
        mixWithOthers = false
        autoResume = true
        requestTimeout = MelodiaSettings.defaultRequestTimeout
        player.setPlaybackMode(.sequence)
        player.selectQuality(.exhigh)
        player.refreshAudioSession()
        Task {
            await NeteaseClient.shared.setRequestTimeout(MelodiaSettings.defaultRequestTimeout)
        }
        statusMessage = "已恢复默认设置"
    }
}

struct LyricsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(MelodiaSettings.lyricFontSizeKey) private var lyricFontSize = MelodiaSettings.defaultLyricFontSize
    @AppStorage(MelodiaSettings.lyricLineSpacingKey) private var lyricLineSpacing = MelodiaSettings.defaultLyricLineSpacing
    @AppStorage(MelodiaSettings.lyricSecondarySpacingKey) private var lyricSecondarySpacing = MelodiaSettings.defaultLyricSecondarySpacing
    @AppStorage(MelodiaSettings.lyricAlignmentKey) private var lyricAlignmentRaw = LyricAlignmentSetting.center.rawValue
    @AppStorage(MelodiaSettings.lyricSecondaryModeKey) private var lyricSecondaryModeRaw = LyricSecondaryModeSetting.translation.rawValue
    @AppStorage(MelodiaSettings.karaokeStyleKey) private var karaokeStyleRaw = KaraokeEffectStyle.melodia.rawValue
    @AppStorage(MelodiaSettings.karaokeGlowKey) private var karaokeGlow = true
    @AppStorage(MelodiaSettings.lyricShadowKey) private var lyricTextShadow = true

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("歌词字号")
                        Spacer()
                        Text("\(Int(lyricFontSize))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                    Slider(value: $lyricFontSize, in: 16...34, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("行间距")
                        Spacer()
                        Text("\(Int(lyricLineSpacing))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                    Slider(value: $lyricLineSpacing, in: 8...40, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("主副歌词间距")
                        Spacer()
                        Text("\(Int(lyricSecondarySpacing))")
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                    Slider(value: $lyricSecondarySpacing, in: 0...18, step: 1)
                        .tint(MelodiaTheme.accentSoft)
                }
            } header: {
                Text("排版")
            }

            Section {
                Picker("对齐", selection: alignmentBinding) {
                    ForEach(LyricAlignmentSetting.allCases) { alignment in
                        Text(alignment.title).tag(alignment)
                    }
                }

                Picker("副歌词", selection: secondaryBinding) {
                    ForEach(LyricSecondaryModeSetting.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("逐字动效", selection: styleBinding) {
                    ForEach(KaraokeEffectStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Toggle("逐字呼吸光效", isOn: $karaokeGlow)
                Toggle("歌词文字阴影", isOn: $lyricTextShadow)
            } header: {
                Text("逐字效果")
            } footer: {
                Text(KaraokeEffectStyle(rawValue: karaokeStyleRaw)?.subtitle ?? "")
            }
        }
        .scrollContentBackground(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("歌词设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }

    private var alignmentBinding: Binding<LyricAlignmentSetting> {
        Binding(
            get: { LyricAlignmentSetting(rawValue: lyricAlignmentRaw) ?? .center },
            set: { lyricAlignmentRaw = $0.rawValue }
        )
    }

    private var secondaryBinding: Binding<LyricSecondaryModeSetting> {
        Binding(
            get: { LyricSecondaryModeSetting(rawValue: lyricSecondaryModeRaw) ?? .translation },
            set: { lyricSecondaryModeRaw = $0.rawValue }
        )
    }

    private var styleBinding: Binding<KaraokeEffectStyle> {
        Binding(
            get: { KaraokeEffectStyle(rawValue: karaokeStyleRaw) ?? .melodia },
            set: { karaokeStyleRaw = $0.rawValue }
        )
    }
}