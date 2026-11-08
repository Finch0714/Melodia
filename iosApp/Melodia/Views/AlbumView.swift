import Foundation
import SwiftUI

struct AlbumView: View {
    let route: AlbumRoute

    @EnvironmentObject private var player: PlayerEngine
    @State private var detail: AlbumDetail?
    @State private var songs: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                header

                if isLoading && songs.isEmpty {
                    ProgressView("正在加载专辑…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else {
                    trackSection
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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
                Text(detail?.name.isEmpty == false ? detail!.name : route.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(detail?.artistText ?? "")
                    .font(.subheadline)
                    .foregroundStyle(MelodiaTheme.textSecondary)

                Text("\(songs.count) 首歌曲")
                    .font(.caption)
                    .foregroundStyle(MelodiaTheme.textTertiary)
            }

            if let description = detail?.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(4)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .melodiaCard(radius: 14)
            }

            HStack(spacing: 12) {
                Button {
                    player.playAll(songs)
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(MelodiaTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(songs.isEmpty)

                Button {
                    player.playAll(songs.shuffled())
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .background(MelodiaTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(songs.isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "曲目", subtitle: "\(songs.count) 首")
            if songs.isEmpty {
                EmptyStateView(icon: "music.note", title: "暂无歌曲", message: "这张专辑暂时无法播放")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.offset) { index, track in
                        TrackRow(track: track, queue: songs, number: index + 1)
                        if index < songs.count - 1 {
                            Divider().overlay(MelodiaTheme.divider)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .melodiaCard()
            }
        }
    }

    private var coverURL: URL? {
        if let url = detail?.coverURL { return url }
        guard let cover = route.cover, !cover.isEmpty else { return nil }
        return URL(string: cover)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.albumDetail(id: route.id)
            detail = response.album
            songs = response.songs
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}