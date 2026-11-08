import Foundation
import SwiftUI

struct AlbumShelfView: View {
    @State private var albums: [AlbumShelfItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if isLoading {
                    ProgressView("正在加载收藏专辑…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 70)
                } else if albums.isEmpty {
                    EmptyStateView(icon: "square.stack", title: "还没有收藏专辑", message: "在网易云音乐收藏专辑后会出现在这里")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 14)], alignment: .leading, spacing: 18) {
                        ForEach(albums) { item in
                            NavigationLink(value: AlbumRoute(shelfItem: item)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverImage(url: item.coverURL, size: 142, cornerRadius: 18)
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                        .frame(width: 142, alignment: .leading)
                                    Text(item.artists.map(\.name).joined(separator: " / "))
                                        .font(.caption)
                                        .foregroundStyle(MelodiaTheme.textSecondary)
                                        .lineLimit(1)
                                        .frame(width: 142, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("收藏专辑")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            albums = try await client.subscribedAlbums()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

struct UserPlaylistsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = appModel.libraryError {
                    ErrorBanner(message: errorMessage)
                }

                if appModel.isLoadingLibrary && appModel.libraryPlaylists.isEmpty {
                    ProgressView("正在加载歌单…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 70)
                } else if appModel.libraryPlaylists.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "还没有歌单", message: "登录后创建的、收藏的歌单会显示在这里")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appModel.libraryPlaylists.enumerated()), id: \.element.id) { index, playlist in
                            NavigationLink(value: PlaylistRoute(userPlaylist: playlist)) {
                                HStack(spacing: 12) {
                                    CoverImage(url: playlist.coverURL, size: 58, cornerRadius: 12)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(playlist.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(MelodiaTheme.textPrimary)
                                                .lineLimit(1)
                                            if playlist.isLikedPlaylist {
                                                Text("喜欢")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(MelodiaTheme.accent, in: Capsule())
                                            }
                                        }
                                        Text("\(playlist.trackCount) 首")
                                            .font(.caption)
                                            .foregroundStyle(MelodiaTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MelodiaTheme.textTertiary)
                                }
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < appModel.libraryPlaylists.count - 1 {
                                Divider().overlay(MelodiaTheme.divider)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .melodiaCard()
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("我的歌单")
        .navigationBarTitleDisplayMode(.inline)
        .task { await appModel.loadLibrary() }
    }
}

struct LikedSongsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var player: PlayerEngine
    @State private var songs: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if isLoading {
                    ProgressView("正在加载喜欢的歌曲…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 70)
                } else if songs.isEmpty {
                    EmptyStateView(icon: "heart", title: "还没有喜欢的歌曲", message: "在播放页点击红心即可收藏")
                } else {
                    HStack {
                        SectionTitle(title: "我喜欢的音乐", subtitle: "\(songs.count) 首")
                        Spacer()
                        Button {
                            player.playAll(songs)
                        } label: {
                            Label("播放", systemImage: "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(MelodiaTheme.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

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

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("我喜欢的音乐")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let uid = appModel.profile?.userId else {
            errorMessage = "请先登录"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let ids = try await client.likedSongIDs(uid: uid)
            var result = [Track]()
            var offset = 0
            while offset < ids.count {
                let end = min(offset + 200, ids.count)
                let chunk = Array(ids[offset..<end])
                result.append(contentsOf: try await client.songDetails(ids: chunk))
                offset = end
            }
            songs = result
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

struct ListeningRankView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var response: ListeningRankResponse?
    @State private var selectedType = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("范围", selection: $selectedType) {
                    Text("本周").tag(0)
                    Text("全部时间").tag(1)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedType) { _ in
                    Task { await load() }
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if isLoading {
                    ProgressView("正在加载听歌排行…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 70)
                } else if records.isEmpty {
                    EmptyStateView(icon: "chart.bar", title: "暂无听歌记录", message: "多听几首歌再来看看")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                            if let track = record.song {
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(MelodiaTheme.textTertiary)
                                        .frame(width: 24)
                                    TrackRow(track: track, queue: queueTracks, showCover: true)
                                    Text("\(record.playCount) 次")
                                        .font(.caption2)
                                        .foregroundStyle(MelodiaTheme.textTertiary)
                                }
                                if index < records.count - 1 {
                                    Divider().overlay(MelodiaTheme.divider)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .melodiaCard()
                }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("听歌排行")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var records: [ListeningRecord] {
        guard let response else { return [] }
        return selectedType == 0 ? response.weekData : response.allData
    }

    private var queueTracks: [Track] {
        records.compactMap(\.song)
    }

    private func load() async {
        guard let uid = appModel.profile?.userId else {
            errorMessage = "请先登录"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            response = try await client.listeningRank(uid: uid, type: selectedType)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}