import Foundation
import SwiftUI

struct PlaylistView: View {
    let route: PlaylistRoute

    @EnvironmentObject private var player: PlayerEngine
    @State private var playlist: PlaylistDetail?
    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let errorMessage {
                    VStack(spacing: 10) {
                        ErrorBanner(message: errorMessage)
                        Button("重试") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MelodiaTheme.accent)
                    }
                }

                if isLoading && tracks.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("加载歌曲…")
                            .tint(MelodiaTheme.accentSoft)
                            .padding(.vertical, 50)
                        Spacer()
                    }
                } else if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "歌单为空", message: "这个歌单暂时没有可播放的歌曲")
                } else {
                    trackList
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle(playlist?.name ?? route.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: route.id) {
            await load()
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(MelodiaTheme.accent.opacity(0.24))
                    .frame(width: 230, height: 230)
                    .blur(radius: 45)
                CoverImage(url: coverURL, size: 190, cornerRadius: 24)
                    .shadow(color: .black.opacity(0.42), radius: 24, y: 14)
            }

            VStack(spacing: 7) {
                Text(playlist?.name ?? route.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let creator = playlist?.creator, !creator.nickname.isEmpty {
                    Text(creator.nickname)
                        .font(.subheadline)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }

                if let playlist {
                    Text("\(playlist.trackCount) 首 · \(playCountText(playlist.playCount))")
                        .font(.caption)
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }
            }

            if let description = playlist?.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .melodiaCard(radius: 14)
            }

            HStack(spacing: 12) {
                Button {
                    player.playAll(tracks)
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(MelodiaTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(tracks.isEmpty)

                Button {
                    player.playAll(tracks.shuffled())
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .background(MelodiaTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(tracks.isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                TrackRow(track: track, queue: tracks, number: index + 1)
                if index < tracks.count - 1 {
                    Divider().overlay(MelodiaTheme.divider)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .melodiaCard()
    }

    private var coverURL: URL? {
        if let cover = playlist?.cover, let url = URL(string: cover), !cover.isEmpty {
            return url
        }
        if let cover = route.cover, let url = URL(string: cover), !cover.isEmpty {
            return url
        }
        return nil
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await client.playlist(id: route.id)
            playlist = detail
            if !detail.trackIds.isEmpty && (detail.tracks.isEmpty || detail.tracks.count < detail.trackCount) {
                tracks = try await loadTrackDetails(ids: detail.trackIds.map(\.id))
            } else {
                tracks = detail.tracks
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func loadTrackDetails(ids: [Int64]) async throws -> [Track] {
        var result = [Track]()
        var offset = 0
        while offset < ids.count {
            let end = min(offset + 200, ids.count)
            let chunk = Array(ids[offset..<end])
            result.append(contentsOf: try await client.songDetails(ids: chunk))
            offset = end
        }
        return result
    }

    private func playCountText(_ count: Int64) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f 亿次播放", Double(count) / 100_000_000)
        }
        if count >= 10_000 {
            return String(format: "%.1f 万次播放", Double(count) / 10_000)
        }
        return "\(count) 次播放"
    }
}
