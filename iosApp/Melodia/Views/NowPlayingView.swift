import Foundation
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false
    @State private var showComments = false
    @State private var showQueue = false
    @State private var seekValue: Double?

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 720
            let artSide = max(
                132,
                min(geometry.size.width - 56, geometry.size.height * (compact ? 0.33 : 0.38))
            )

            ZStack {
                background

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 18)
                        .padding(.top, 6)

                    if showLyrics {
                        lyricsView
                            .padding(.horizontal, 20)
                            .padding(.top, compact ? 6 : 10)
                            .frame(maxHeight: .infinity)
                    } else {
                        Spacer(minLength: compact ? 4 : 10)
                        artwork(side: artSide, compact: compact)
                        Spacer(minLength: compact ? 4 : 10)
                    }

                    trackInfo
                        .padding(.horizontal, 24)
                        .padding(.top, compact ? 4 : 8)

                    progressSection
                        .padding(.horizontal, 24)
                        .padding(.top, compact ? 8 : 12)

                    controls
                        .padding(.top, compact ? 8 : 14)

                    bottomBar
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, MelodiaTheme.background.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
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
    }

    private func artwork(side: CGFloat, compact: Bool) -> some View {
        CoverImage(
            url: player.currentTrack?.coverURL,
            size: side,
            cornerRadius: compact ? 24 : 30
        )
        .shadow(color: MelodiaTheme.accent.opacity(0.20), radius: 40, y: 18)
        .frame(maxWidth: .infinity)
    }

    private var lyricsView: some View {
        Group {
            if player.lyricsLoading && player.lyrics.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(MelodiaTheme.accentSoft)
                    Text("正在加载歌词…")
                        .font(.footnote)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else if player.lyrics.isEmpty {
                EmptyStateView(
                    icon: "text.quote",
                    title: "暂无歌词",
                    message: player.lyricsError ?? "这首歌还没有可用的歌词"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 19) {
                            ForEach(Array(player.lyrics.enumerated()), id: \.offset) { index, line in
                                lyricRow(index: index, line: line)
                            }
                        }
                        .padding(.vertical, 110)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        if player.currentLyricIndex >= 0 {
                            proxy.scrollTo(player.currentLyricIndex, anchor: .center)
                        }
                    }
                    .onChange(of: player.currentLyricIndex) { index in
                        guard index >= 0 else { return }
                        withAnimation(.easeOut(duration: 0.35)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func lyricRow(index: Int, line: LyricLine) -> some View {
        let isCurrent = index == player.currentLyricIndex
        let nextTime = index + 1 < player.lyrics.count
            ? player.lyrics[index + 1].time
            : line.time + 6

        return VStack(spacing: 5) {
            if isCurrent {
                LyricFlowLine(
                    line: line,
                    nextLineTime: nextTime,
                    playbackTime: player.currentTime,
                    isPlaying: player.isPlaying,
                    fontSize: 21
                )
            } else {
                Text(line.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        index < player.currentLyricIndex
                            ? MelodiaTheme.textTertiary
                            : MelodiaTheme.textSecondary
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        isCurrent
                            ? MelodiaTheme.accentSoft.opacity(0.82)
                            : MelodiaTheme.textTertiary
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isCurrent ? 1.035 : 1)
        .opacity(lineOpacity(index: index))
        .animation(.easeOut(duration: 0.28), value: player.currentLyricIndex)
        .id(index)
        .contentShape(Rectangle())
        .onTapGesture {
            player.seek(to: line.time)
        }
    }

    private func lineOpacity(index: Int) -> Double {
        guard player.currentLyricIndex >= 0 else { return 0.58 }
        let distance = abs(index - player.currentLyricIndex)
        if distance == 0 { return 1 }
        return max(0.22, 0.58 - Double(distance - 1) * 0.055)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Text("正在播放")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                if !player.queue.isEmpty {
                    Text("\(player.currentIndex + 1) / \(player.queue.count)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showLyrics.toggle()
                }
            } label: {
                Label(
                    showLyrics ? "封面" : "歌词",
                    systemImage: showLyrics ? "photo" : "text.quote"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(showLyrics ? MelodiaTheme.accentSoft : MelodiaTheme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var trackInfo: some View {
        VStack(spacing: 4) {
            Text(player.currentTrack?.name ?? "未在播放")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(player.currentTrack?.artistText ?? "")
                .font(.subheadline)
                .foregroundStyle(MelodiaTheme.textSecondary)
                .lineLimit(1)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 5) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let duration = max(player.duration, 0.001)
                let rawProgress = (seekValue ?? player.currentTime) / duration
                let progress = min(max(rawProgress, 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MelodiaTheme.accentSoft, MelodiaTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * progress, height: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: MelodiaTheme.accent.opacity(0.55), radius: 5)
                        .offset(x: max(0, min(width - 12, width * progress - 6)))
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
            .frame(height: 24)

            HStack {
                Text(formatTime(seekValue ?? player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(MelodiaTheme.textTertiary)
        }
    }

    private var controls: some View {
        HStack(spacing: 38) {
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(player.hasPrevious ? MelodiaTheme.textPrimary : MelodiaTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasPrevious)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(MelodiaTheme.accent)
                        .frame(width: 72, height: 72)
                        .shadow(color: MelodiaTheme.accent.opacity(0.36), radius: 18, y: 8)
                    if player.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(player.currentTrack == nil)

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(player.hasNext ? MelodiaTheme.textPrimary : MelodiaTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasNext)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            bottomAction(
                icon: isLiked ? "heart.fill" : "heart",
                title: "喜欢",
                active: isLiked,
                disabled: !appModel.isLoggedIn
            ) {
                if let track = player.currentTrack {
                    Task { await appModel.toggleLike(track) }
                }
            }

            bottomAction(
                icon: "text.quote",
                title: "歌词",
                active: showLyrics,
                disabled: player.currentTrack == nil
            ) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showLyrics.toggle()
                }
            }

            bottomAction(
                icon: "bubble.left",
                title: "评论",
                active: showComments,
                disabled: player.currentTrack == nil
            ) {
                showComments = true
            }

            bottomAction(
                icon: "list.bullet",
                title: "队列",
                active: showQueue,
                disabled: player.queue.isEmpty
            ) {
                showQueue = true
            }

            bottomAction(
                icon: player.playbackMode.icon,
                title: playbackModeTitle,
                active: player.playbackMode != .sequence,
                disabled: player.queue.isEmpty
            ) {
                player.togglePlaybackMode()
            }

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
                VStack(spacing: 3) {
                    Text(player.audioQuality.title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("音质")
                        .font(.system(size: 9.5, weight: .medium))
                }
                .foregroundStyle(MelodiaTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
        }
    }

    private var playbackModeTitle: String {
        switch player.playbackMode {
        case .sequence: return "顺序"
        case .repeatAll: return "循环"
        case .repeatOne: return "单曲"
        case .shuffle: return "随机"
        }
    }

    private var isLiked: Bool {
        guard let track = player.currentTrack else { return false }
        return appModel.isTrackLiked(track)
    }

    private func bottomAction(
        icon: String,
        title: String,
        active: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? MelodiaTheme.accentSoft : MelodiaTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private var background: some View {
        ZStack {
            MelodiaTheme.background
            if let url = player.currentTrack?.coverURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 75)
                .opacity(0.34)
            }
            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func formatTime(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let seconds = Int(value)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}