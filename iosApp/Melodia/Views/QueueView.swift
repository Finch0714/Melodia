import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("播放队列")
                                .font(.headline)
                                .foregroundStyle(MelodiaTheme.textPrimary)
                            Text("\(player.queue.count) 首 · \(player.playbackMode.title)")
                                .font(.caption)
                                .foregroundStyle(MelodiaTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            player.togglePlaybackMode()
                        } label: {
                            Image(systemName: player.playbackMode.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MelodiaTheme.accentSoft)
                                .frame(width: 38, height: 38)
                                .background(MelodiaTheme.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if player.queue.isEmpty {
                        EmptyStateView(icon: "music.note.list", title: "队列为空", message: "播放一首歌曲后会显示在这里")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(player.queue.enumerated()), id: \.offset) { index, track in
                                Button {
                                    player.playQueue(at: index)
                                } label: {
                                    HStack(spacing: 12) {
                                        CoverImage(url: track.coverURL, size: 46, cornerRadius: 11)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(track.name)
                                                .font(.subheadline.weight(index == player.currentIndex ? .bold : .medium))
                                                .foregroundStyle(index == player.currentIndex ? MelodiaTheme.accentSoft : MelodiaTheme.textPrimary)
                                                .lineLimit(1)
                                            Text(track.artistText)
                                                .font(.caption)
                                                .foregroundStyle(MelodiaTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if index == player.currentIndex {
                                            Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(MelodiaTheme.accent)
                                        }
                                        Text(track.formattedDuration)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(MelodiaTheme.textTertiary)
                                    }
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < player.queue.count - 1 {
                                    Divider().overlay(MelodiaTheme.divider)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .melodiaCard()
                    }

                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(MelodiaTheme.textPrimary)
                }
            }
        }
    }
}