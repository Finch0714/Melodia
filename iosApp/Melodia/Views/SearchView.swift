import Foundation
import SwiftUI

private enum SearchCategory: String, CaseIterable, Identifiable {
    case songs = "单曲"
    case playlists = "歌单"
    case albums = "专辑"
    case artists = "歌手"

    var id: String { rawValue }
}

struct SearchView: View {
    @EnvironmentObject private var player: PlayerEngine
    @State private var query = ""
    @State private var songs: [Track] = []
    @State private var playlists: [PlaylistSummary] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var selectedCategory = SearchCategory.songs
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var errorMessage: String?
    @State private var history: [String] = []
    @State private var hotKeywords: [String] = []
    @State private var generation = 0

    private let client = NeteaseClient.shared
    private let historyKey = "melodia.search.history"
    private let fallbackKeywords = ["周杰伦", "林俊杰", "Taylor Swift", "华语流行", "轻音乐"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        discoveryContent
                    } else if isSearching && totalResultCount == 0 {
                        HStack {
                            Spacer()
                            ProgressView("正在搜索…")
                                .tint(MelodiaTheme.accentSoft)
                                .padding(.vertical, 70)
                            Spacer()
                        }
                    } else if didSearch && totalResultCount == 0 {
                        EmptyStateView(icon: "magnifyingglass", title: "没有找到结果", message: "换一个关键词试试")
                    } else if didSearch {
                        resultsContent
                    }

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle("搜索")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索歌曲、歌单、专辑、歌手")
            .submitLabel(.search)
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationDestination(for: PlaylistRoute.self) { route in
                PlaylistView(route: route)
            }
            .navigationDestination(for: AlbumRoute.self) { route in
                AlbumView(route: route)
            }
            .navigationDestination(for: ArtistRoute.self) { route in
                ArtistView(route: route)
            }
            .task {
                if hotKeywords.isEmpty {
                    hotKeywords = (try? await client.hotSearches()) ?? []
                }
            }
        }
    }

    private var discoveryContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "最近搜索")
                    chipCloud(history) { keyword in
                        query = keyword
                        Task { await search(keyword: keyword) }
                    }
                    Button("清空记录") {
                        history = []
                        UserDefaults.standard.removeObject(forKey: historyKey)
                    }
                    .font(.caption)
                    .foregroundStyle(MelodiaTheme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "热门搜索", subtitle: "从这些开始")
                chipCloud(hotKeywords.isEmpty ? fallbackKeywords : Array(hotKeywords.prefix(15))) { keyword in
                    query = keyword
                    Task { await search(keyword: keyword) }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("搜索整个音乐世界")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Text("单曲、歌单、专辑和歌手都可以直接搜索，播放页支持歌词、评论、收藏、队列和音质切换。")
                    .font(.subheadline)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [MelodiaTheme.accent.opacity(0.28), MelodiaTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .onAppear(perform: loadHistory)
    }

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("结果类型", selection: $selectedCategory) {
                ForEach(SearchCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)

            switch selectedCategory {
            case .songs:
                songsSection
            case .playlists:
                playlistsSection
            case .albums:
                albumsSection
            case .artists:
                artistsSection
            }
        }
    }

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "单曲", subtitle: "\(songs.count) 首")
                Spacer()
                if !songs.isEmpty {
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
            }

            if songs.isEmpty {
                EmptyStateView(icon: "music.note", title: "没有单曲结果", message: "试试更换关键词")
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

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "歌单", subtitle: "\(playlists.count) 个")
            if playlists.isEmpty {
                EmptyStateView(icon: "music.note.list", title: "没有歌单结果", message: "试试更换关键词")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(playlists.enumerated()), id: \.offset) { index, playlist in
                        NavigationLink(value: PlaylistRoute(summary: playlist)) {
                            HStack(spacing: 12) {
                                CoverImage(url: playlist.coverURL, size: 54, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                    if let count = playlist.playCountText {
                                        Text("\(count) 次播放")
                                            .font(.caption)
                                            .foregroundStyle(MelodiaTheme.textSecondary)
                                    }
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
                        if index < playlists.count - 1 {
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
                EmptyStateView(icon: "square.stack", title: "没有专辑结果", message: "试试更换关键词")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 14)], alignment: .leading, spacing: 18) {
                    ForEach(albums) { album in
                        AlbumCard(album: album, width: 142)
                    }
                }
            }
        }
    }

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "歌手", subtitle: "\(artists.count) 位")
            if artists.isEmpty {
                EmptyStateView(icon: "person.2", title: "没有歌手结果", message: "试试更换关键词")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 14)], alignment: .leading, spacing: 18) {
                    ForEach(artists) { artist in
                        ArtistCard(artist: artist, width: 108)
                    }
                }
            }
        }
    }

    private var totalResultCount: Int {
        songs.count + playlists.count + albums.count + artists.count
    }

    private func chipCloud(_ values: [String], action: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(values, id: \.self) { value in
                Button {
                    action(value)
                } label: {
                    Text(value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MelodiaTheme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func search(keyword: String? = nil) async {
        if let keyword { query = keyword }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        generation += 1
        let current = generation
        isSearching = true
        didSearch = true
        errorMessage = nil

        do {
            let songResult = try await client.search(keyword: trimmed, type: .song)
            guard current == generation else { return }
            songs = songResult.songs ?? []
        } catch {
            if current == generation {
                songs = []
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        do {
            let playlistResult = try await client.search(keyword: trimmed, type: .playlist)
            guard current == generation else { return }
            playlists = playlistResult.playlists ?? []
        } catch {
            if current == generation { playlists = [] }
        }

        do {
            let albumResult = try await client.search(keyword: trimmed, type: .album)
            guard current == generation else { return }
            albums = albumResult.albums ?? []
        } catch {
            if current == generation { albums = [] }
        }

        do {
            let artistResult = try await client.search(keyword: trimmed, type: .artist)
            guard current == generation else { return }
            artists = artistResult.artists ?? []
        } catch {
            if current == generation { artists = [] }
        }

        if current == generation {
            isSearching = false
            saveHistory(trimmed)
        }
    }

    private func loadHistory() {
        history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    private func saveHistory(_ keyword: String) {
        var values = history.filter { $0 != keyword }
        values.insert(keyword, at: 0)
        history = Array(values.prefix(10))
        UserDefaults.standard.set(history, forKey: historyKey)
    }
}