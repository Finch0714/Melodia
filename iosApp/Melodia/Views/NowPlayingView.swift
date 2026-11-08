import Foundation
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false
    @State private var seekValue: Double?

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                Spacer(minLength: 10)

                if showLyrics {
                    lyricsView
                        .padding(.horizontal, 22)
                } else {
                    artwork
                }

                Spacer(minLength: 10)

                trackInfo
                    .padding(.horizontal, 28)

                progressSection
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                controls
                    .padding(.top, 18)

                bottomBar
                    .padding(.top, 16)
                    .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var artwork: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width - 48, geometry.size.height)
            CoverImage(url: player.currentTrack?.coverURL, size: max(180, side), cornerRadius: 30)
                .shadow(color: MelodiaTheme.accent.opacity(0.20), radius: 40, y: 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var lyricsView: some View {
        Group {
            if player.lyrics.isEmpty {
                EmptyStateView(icon: "text.quote", title: "暂无歌词", message: "这首歌还没有可用的歌词")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 17) {
                            ForEach(Array(player.lyrics.enumerated()), id: \.offset) { index, line in
                                VStack(spacing: 4) {
                                    Text(line.text)
                                        .font(.system(size: index == player.currentLyricIndex ? 19 : 16, weight: index == player.currentLyricIndex ? .bold : .medium))
                                        .foregroundStyle(index == player.currentLyricIndex ? MelodiaTheme.accentSoft : MelodiaTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                    if let translation = line.translation, !translation.isEmpty {
                                        Text(translation)
                                            .font(.caption)
                                            .foregroundStyle(MelodiaTheme.textTertiary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .id(index)
                                .onTapGesture {
                                    player.seek(to: line.time)
                                }
                            }
                        }
                        .padding(.vertical, 120)
                    }
                    .scrollIndicators(.hidden)
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

    private var topBar: some View {
        HStack {
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

            Spacer()

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

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showLyrics.toggle()
                }
            } label: {
                Image(systemName: showLyrics ? "photo" : "text.quote")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(showLyrics ? MelodiaTheme.accentSoft : MelodiaTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var trackInfo: some View {
        VStack(spacing: 5) {
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
        VStack(spacing: 1) {
            Slider(
                value: Binding(
                    get: { seekValue ?? player.currentTime },
                    set: { seekValue = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        player.seek(to: seekValue ?? player.currentTime)
                        seekValue = nil
                    }
                }
            )
            .tint(.white)

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
        HStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.caption)
            Text(player.currentTrack?.albumName.isEmpty == false ? player.currentTrack!.albumName : "网易云音乐")
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(MelodiaTheme.textTertiary)
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
