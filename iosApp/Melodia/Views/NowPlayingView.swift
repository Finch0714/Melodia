import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = false
    @State private var showComments = false
    @State private var showQueue = false
    @State private var showLyricSettings = false
    @State private var seekValue: Double?

    @AppStorage(MelodiaSettings.lyricFontSizeKey) private var lyricFontSize = MelodiaSettings.defaultLyricFontSize
    @AppStorage(MelodiaSettings.lyricLineSpacingKey) private var lyricLineSpacing = MelodiaSettings.defaultLyricLineSpacing
    @AppStorage(MelodiaSettings.lyricSecondarySpacingKey) private var lyricSecondarySpacing = MelodiaSettings.defaultLyricSecondarySpacing
    @AppStorage(MelodiaSettings.lyricAlignmentKey) private var lyricAlignmentRaw = LyricAlignmentSetting.center.rawValue
    @AppStorage(MelodiaSettings.lyricSecondaryModeKey) private var lyricSecondaryModeRaw = LyricSecondaryModeSetting.translation.rawValue
    @AppStorage(MelodiaSettings.karaokeStyleKey) private var karaokeStyleRaw = KaraokeEffectStyle.melodia.rawValue
    @AppStorage(MelodiaSettings.karaokeGlowKey) private var karaokeGlow = true
    @AppStorage(MelodiaSettings.showMiniLyricKey) private var showMiniLyric = true
    @AppStorage(MelodiaSettings.backgroundStyleKey) private var backgroundStyleRaw = PlayerBackgroundStyle.cover.rawValue
    @AppStorage(MelodiaSettings.showQualityBadgeKey) private var showQualityBadge = true
    @AppStorage(MelodiaSettings.coverCornerRadiusKey) private var coverCornerRadius = MelodiaSettings.defaultCoverCornerRadius
    @AppStorage(MelodiaSettings.wideLandscapeKey) private var wideLandscape = true

    private var lyricAlignment: LyricAlignmentSetting {
        LyricAlignmentSetting(rawValue: lyricAlignmentRaw) ?? .center
    }

    private var lyricSecondaryMode: LyricSecondaryModeSetting {
        LyricSecondaryModeSetting(rawValue: lyricSecondaryModeRaw) ?? .translation
    }

    private var karaokeStyle: KaraokeEffectStyle {
        KaraokeEffectStyle(rawValue: karaokeStyleRaw) ?? .melodia
    }

    private var backgroundStyle: PlayerBackgroundStyle {
        PlayerBackgroundStyle(rawValue: backgroundStyleRaw) ?? .cover
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = max(geometry.size.height, 1)
            let size = CGSize(width: width, height: height)
            let wide = wideLandscape && width >= 720 && height >= 500 && width > height * 1.05

            ZStack {
                playerBackground(blurred: backgroundStyle == .cover)
                    .frame(width: width, height: height)

                if showLyrics {
                    lyricsScreen(size: size, wide: wide)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                } else {
                    playerContent(size: size, wide: wide)
                        .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .animation(.easeInOut(duration: 0.24), value: showLyrics)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showComments) {
            if let track = player.currentTrack {
                CommentsView(track: track)
                    .environmentObject(player)
                    .environmentObject(appModel)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environmentObject(player)
                .environmentObject(appModel)
        }
        .sheet(isPresented: $showLyricSettings) {
            NavigationStack {
                LyricsSettingsSheet()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func playerContent(size: CGSize, wide: Bool) -> some View {
        if wide {
            widePlayer(size: size)
        } else {
            compactPlayer(size: size)
        }
    }

    private func compactPlayer(size: CGSize) -> some View {
        let availableWidth = max(120, size.width - 48)
        let coverSide = min(availableWidth, 460)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                coverSection(side: coverSide)
                songInfo
                    .padding(.top, 12)
                miniLyric
                progressSection
                    .padding(.top, 8)
                playbackControls
                    .padding(.top, 4)
                actionRow
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func widePlayer(size: CGSize) -> some View {
        let leftWidth = min(420, max(300, size.width * 0.40))
        let coverSide = min(leftWidth, max(140, size.height - 300))

        return VStack(spacing: 0) {
            sourceBar
                .padding(.horizontal, 24)
                .padding(.top, 16)

            HStack(alignment: .top, spacing: 56) {
                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    coverArt(side: coverSide)

                    Spacer()
                        .frame(height: 16)

                    songInfo
                    miniLyric
                    progressSection
                        .padding(.top, 8)
                    playbackControls
                        .padding(.top, 4)
                    actionRow
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    Spacer(minLength: 8)
                }
                .frame(width: leftWidth)
                .frame(maxHeight: .infinity)

                wideLyricsPanel(size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.leading, 48)
            .padding(.trailing, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func coverSection(side: CGFloat) -> some View {
        VStack(spacing: 0) {
            sourceBar

            coverArt(side: side)
                .padding(.top, 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func coverArt(side: CGFloat) -> some View {
        CoverImage(
            url: player.currentTrack?.coverURL,
            size: side,
            cornerRadius: coverCornerRadius
        )
        .shadow(color: Color.black.opacity(0.28), radius: 16, y: 8)
    }

    private var sourceBar: some View {
        ZStack {
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起播放页")

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Button {
                        showLyrics = true
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("歌词")

                    Menu {
                        Button {
                            showLyrics = true
                        } label: {
                            Label("歌词", systemImage: "text.quote")
                        }
                        Button {
                            showComments = true
                        } label: {
                            Label("评论", systemImage: "bubble.left")
                        }
                        Button {
                            showQueue = true
                        } label: {
                            Label("播放队列", systemImage: "list.bullet")
                        }
                        Button {
                            showLyricSettings = true
                        } label: {
                            Label("歌词设置", systemImage: "slider.horizontal.3")
                        }
                        Divider()
                        if let shareURL {
                            ShareLink(item: shareURL) {
                                Label("分享歌曲", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("更多")
                }
            }

            VStack(spacing: 1) {
                Text("正在播放")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(MelodiaTheme.textPrimary.opacity(0.60))
                if !player.queue.isEmpty {
                    Text("\(player.currentIndex + 1) / \(player.queue.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .lineLimit(1)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 32)
    }

    private var songInfo: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.name ?? "未在播放")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(player.currentTrack?.artistText ?? "")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(MelodiaTheme.textPrimary.opacity(0.75))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if let track = player.currentTrack {
                    Task { await appModel.toggleLike(track) }
                }
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(isLiked ? MelodiaTheme.accentSoft : MelodiaTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!appModel.isLoggedIn || player.currentTrack == nil)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var miniLyric: some View {
        if showMiniLyric {
            Button {
                showLyrics = true
            } label: {
                HStack(spacing: 0) {
                    Text(miniLyricText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MelodiaTheme.textPrimary.opacity(miniLyricText == "暂无歌词" ? 0.38 : 0.92))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(player.currentTrack == nil)
        }
    }

    private var miniLyricText: String {
        if let lyric = player.currentLyric, !lyric.text.isEmpty {
            return lyric.text
        }
        return player.lyricsLoading ? "正在加载歌词…" : "暂无歌词"
    }

    private var progressSection: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let duration = playbackDuration
                let rawProgress = (seekValue ?? player.currentTime) / max(duration, 0.001)
                let progress = min(max(rawProgress, 0), 1)
                let thumbSize: CGFloat = seekValue == nil ? 8 : 14

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MelodiaTheme.surfaceLight)
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, width * progress), height: 4)

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: max(0, min(width - thumbSize, width * progress - thumbSize / 2)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(value.location.x / width, 0), 1)
                            seekValue = Double(ratio) * duration
                        }
                        .onEnded { value in
                            let ratio = min(max(value.location.x / width, 0), 1)
                            player.seek(to: Double(ratio) * duration)
                            seekValue = nil
                        }
                )
            }
            .frame(height: 28)

            HStack {
                Text(formatTime(seekValue ?? player.currentTime))
                Spacer()
                Text(formatTime(playbackDuration))
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(MelodiaTheme.textSecondary)
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
    }

    private var playbackControls: some View {
        HStack(spacing: 0) {
            modeButton(
                icon: "shuffle",
                active: player.playbackMode == .shuffle,
                disabled: player.queue.isEmpty
            ) {
                player.toggleShuffle()
            }

            Spacer(minLength: 8)

            HStack(spacing: 28) {
                transportButton(
                    icon: "backward.end.fill",
                    enabled: player.hasPrevious
                ) {
                    player.previous()
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.black.opacity(0.22), radius: 10, y: 4)
                        if player.isLoading {
                            ProgressView()
                                .tint(Color.black)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(Color.black)
                                .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(player.currentTrack == nil)

                transportButton(
                    icon: "forward.end.fill",
                    enabled: player.hasNext
                ) {
                    player.next()
                }
            }

            Spacer(minLength: 8)

            modeButton(
                icon: player.playbackMode == .repeatOne ? "repeat.1" : "repeat",
                active: isRepeating,
                disabled: player.queue.isEmpty
            ) {
                player.toggleRepeat()
            }
        }
        .padding(.horizontal, 24)
    }

    private func modeButton(
        icon: String,
        active: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(active ? MelodiaTheme.textPrimary : MelodiaTheme.textSecondary)
                .frame(width: 44, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func transportButton(
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(enabled ? MelodiaTheme.textPrimary : MelodiaTheme.textTertiary)
                .frame(width: 52, height: 72)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var actionRow: some View {
        ZStack {
            HStack(spacing: 4) {
                AudioRoutePicker()
                    .frame(width: 44, height: 44)
                    .offset(x: -10)
                    .accessibilityLabel("播放设备")

                Spacer(minLength: 8)

                actionIcon("text.quote", label: "歌词", size: 24) {
                    showLyrics = true
                }

                actionIcon("bubble.left", label: "评论", size: 23) {
                    showComments = true
                }

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                actionIcon("list.bullet", label: "队列", size: 28) {
                    showQueue = true
                }
                .disabled(player.queue.isEmpty)
            }

            if showQualityBadge {
                Menu {
                    ForEach(AudioQuality.allCases) { quality in
                        Button {
                            player.selectQuality(quality)
                        } label: {
                            if quality == player.audioQuality {
                                Label(quality.title, systemImage: "checkmark")
                            } else {
                                Text(quality.title)
                            }
                        }
                    }
                } label: {
                    Text(player.audioQuality.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 44)
    }

    private func actionIcon(
        _ icon: String,
        label: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(MelodiaTheme.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func lyricsScreen(size: CGSize, wide: Bool) -> some View {
        ZStack {
            playerBackground(blurred: true)
                .overlay(Color.black.opacity(0.30))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button {
                        showLyrics = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 4)

                    VStack(spacing: 2) {
                        Text(player.currentTrack?.name ?? "歌词")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                            .lineLimit(1)
                        Text(player.currentTrack?.artistText ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Button {
                        showLyricSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)

                lyricsScrollContent(size: size, wide: wide)
            }
        }
    }

    @ViewBuilder
    private func lyricsScrollContent(size: CGSize, wide: Bool) -> some View {
        if player.lyricsLoading && player.lyrics.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(MelodiaTheme.accentSoft)
                Text("正在加载歌词…")
                    .font(.footnote)
                    .foregroundStyle(MelodiaTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if player.lyrics.isEmpty {
            EmptyStateView(
                icon: "text.quote",
                title: "暂无歌词",
                message: player.lyricsError ?? "这首歌还没有可用的歌词"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: lyricLineSpacing) {
                        ForEach(Array(player.lyrics.enumerated()), id: \.offset) { index, line in
                            lyricRow(index: index, line: line)
                        }
                    }
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 26)
                    .padding(.vertical, max(120, size.height * (wide ? 0.30 : 0.42)))
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollToCurrentLyric(proxy: proxy, animated: false)
                }
                .onChange(of: player.currentLyricIndex) { _ in
                    scrollToCurrentLyric(proxy: proxy, animated: true)
                }
            }
        }
    }

    private func wideLyricsPanel(size: CGSize) -> some View {
        lyricsScrollContent(size: size, wide: true)
    }

    private func lyricRow(index: Int, line: LyricLine) -> some View {
        let isCurrent = index == player.currentLyricIndex
        let nextTime = index + 1 < player.lyrics.count
            ? player.lyrics[index + 1].time
            : line.time + 6
        let showsSecondary = lyricSecondaryMode == .translation
            && line.translation?.isEmpty == false

        return VStack(spacing: lyricSecondarySpacing) {
            if isCurrent {
                LyricFlowLine(
                    line: line,
                    nextLineTime: nextTime,
                    playbackTime: player.currentTime,
                    isPlaying: player.isPlaying,
                    fontSize: lyricFontSize,
                    alignment: lyricAlignment,
                    style: karaokeStyle,
                    glowEnabled: karaokeGlow
                )
            } else {
                Text(line.text)
                    .font(.system(size: max(16, lyricFontSize - 5), weight: .semibold))
                    .foregroundStyle(index < player.currentLyricIndex ? MelodiaTheme.textTertiary : MelodiaTheme.textSecondary)
                    .multilineTextAlignment(lyricAlignment.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: lyricAlignment.frameAlignment)
            }

            if showsSecondary, let translation = line.translation {
                Text(translation)
                    .font(.system(size: max(12, lyricFontSize - 9), weight: .medium))
                    .foregroundStyle(isCurrent ? MelodiaTheme.accentSoft.opacity(0.82) : MelodiaTheme.textTertiary)
                    .multilineTextAlignment(lyricAlignment.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: lyricAlignment.frameAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: lyricAlignment.frameAlignment)
        .scaleEffect(isCurrent ? 1.04 : 1)
        .opacity(lineOpacity(index: index))
        .animation(.easeOut(duration: 0.26), value: player.currentLyricIndex)
        .id(index)
        .contentShape(Rectangle())
        .onTapGesture {
            player.seek(to: line.time)
        }
    }

    private func scrollToCurrentLyric(proxy: ScrollViewProxy, animated: Bool) {
        let index = player.currentLyricIndex
        guard index >= 0, index < player.lyrics.count else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo(index, anchor: .center)
            }
        } else {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    private func lineOpacity(index: Int) -> Double {
        guard player.currentLyricIndex >= 0 else { return 0.58 }
        let distance = abs(index - player.currentLyricIndex)
        if distance == 0 { return 1 }
        if distance == 1 { return 0.65 }
        if distance == 2 { return 0.45 }
        return 0.28
    }

    private func playerBackground(blurred: Bool) -> some View {
        ZStack {
            MelodiaTheme.background

            if blurred, let url = player.currentTrack?.coverURL {
                CachedRemoteImage(
                    url: url.melodiaImageURL(pixels: 960),
                    contentMode: .fill
                ) {
                    Color.clear
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .blur(radius: 70)
                .opacity(0.42)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(blurred ? 0.10 : 0.02),
                    MelodiaTheme.background.opacity(blurred ? 0.58 : 1.0),
                    MelodiaTheme.background.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var playbackDuration: Double {
        if player.duration.isFinite, player.duration > 0 {
            return player.duration
        }
        if let milliseconds = player.currentTrack?.durationMs, milliseconds > 0 {
            return Double(milliseconds) / 1000
        }
        return 0.001
    }

    private var isLiked: Bool {
        guard let track = player.currentTrack else { return false }
        return appModel.isTrackLiked(track)
    }

    private var isRepeating: Bool {
        player.playbackMode == .repeatAll || player.playbackMode == .repeatOne
    }

    private var shareURL: URL? {
        guard let track = player.currentTrack else { return nil }
        return URL(string: "https://music.163.com/song?id=\(track.id)")
    }

    private func formatTime(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let seconds = Int(value)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}