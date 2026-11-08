import Foundation
import SwiftUI

struct ArtistView: View {
    let route: ArtistRoute

    @EnvironmentObject private var player: PlayerEngine
    @State private var detail: ArtistDetail?
    @State private var songs: [Track] = []
    @State private var albums: [ArtistAlbum] = []
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

                if isLoading && songs.isEmpty && albums.isEmpty {
                    ProgressView("正在加载歌手资料…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else {
                    songsSection
                    albumsSection
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
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(MelodiaTheme.accent.opacity(0.22))
                    .frame(width: 210, height: 210)
                    .blur(radius: 40)
                CoverImage(url: imageURL, size: 126, cornerRadius: 63)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
            }

            VStack(spacing: 7) {
                Text(detail?.name.isEmpty == false ? detail!.name : route.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if let alias = detail?.alias.first, !alias.isEmpty {
                    Text(alias)
                        .font(.footnote)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }

                if let detail {
                    Text("\(detail.musicSize) 首歌曲 · \(detail.albumSize) 张专辑")
                        .font(.caption)
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }
            }

            if let detail, !detail.briefDesc.isEmpty {
                Text(detail.briefDesc)
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
                    Label("播放热门歌曲", systemImage: "play.fill")
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

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "热门歌曲", subtitle: "\(songs.count) 首")
            if songs.isEmpty {
                EmptyStateView(icon: "music.note", title: "暂无歌曲", message: "稍后再试")
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

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "专辑", subtitle: "\(albums.count) 张")
            if albums.isEmpty {
                EmptyStateView(icon: "square.stack", title: "暂无专辑", message: "稍后再试")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(albums) { item in
                            NavigationLink(value: AlbumRoute(artistAlbum: item)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverImage(url: item.coverURL, size: 140, cornerRadius: 18)
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                        .frame(width: 140, alignment: .leading)
                                    Text("\(item.size) 首")
                                        .font(.caption)
                                        .foregroundStyle(MelodiaTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var imageURL: URL? {
        if let url = detail?.imageURL { return url }
        guard let avatar = route.avatar, !avatar.isEmpty else { return nil }
        return URL(string: avatar)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await client.artistDetail(id: route.id)
        } catch {
            errorMessage = message(for: error)
        }
        do {
            songs = try await client.artistSongs(id: route.id)
        } catch {
            if errorMessage == nil { errorMessage = message(for: error) }
        }
        do {
            albums = try await client.artistAlbums(id: route.id)
        } catch {
            if errorMessage == nil { errorMessage = message(for: error) }
        }
        isLoading = false
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}