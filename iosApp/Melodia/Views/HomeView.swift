import Foundation
import SwiftUI

struct HomeView: View {
    let onOpenAccount: () -> Void

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var player: PlayerEngine

    @State private var homeFilter = 0
    @State private var recentPlaylists: [RecentPlaylistRecord] = []
    @State private var shelves: [HomeShelfModel] = []
    @State private var nextCursor: String?
    @State private var hasMoreShelves = false
    @State private var isLoadingFeed = true
    @State private var isLoadingMore = false
    @State private var feedError: String?
    @State private var actionMessage: String?

    private let client = NeteaseClient.shared
    private let gridColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if let feedError {
                            ErrorBanner(message: feedError)
                        }
                        if let actionMessage {
                            ErrorBanner(message: actionMessage)
                        }

                        if homeFilter == 2 {
                            PodcastHomeView()
                                .padding(.top, 2)
                        } else {
                            recentGrid

                            highlights
                                .padding(.top, recentPlaylists.isEmpty ? 0 : 4)

                            if isLoadingFeed && shelves.isEmpty {
                                ProgressView("正在加载首页…")
                                    .tint(MelodiaTheme.accentSoft)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            }

                            ForEach(shelves) { shelf in
                                HomeShelfSection(shelf: shelf)
                            }

                            if hasMoreShelves {
                                Button {
                                    Task { await loadMoreShelves() }
                                } label: {
                                    HStack {
                                        if isLoadingMore {
                                            ProgressView().tint(MelodiaTheme.accentSoft)
                                        }
                                        Text(isLoadingMore ? "加载中…" : "加载更多")
                                            .font(.footnote.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(MelodiaTheme.surface, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingMore)
                            }
                        }

                        Color.clear.frame(height: 96)
                    }
                    .padding(.top, 6)
                }
                .scrollIndicators(.hidden)
                .refreshable { await reload() }
            }
            .background(
                ZStack {
                    MelodiaTheme.background
                    MelodiaTheme.heroGradient
                        .frame(height: 340)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await reload() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onOpenAccount) {
                if let url = appModel.profile?.avatarURL {
                    CoverImage(url: url, size: 36, cornerRadius: 18)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开我的")

            HStack(spacing: 9) {
                filterPill("全部", tag: 0)
                filterPill("音乐", tag: 1)
                filterPill("播客", tag: 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func filterPill(_ title: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                homeFilter = tag
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(homeFilter == tag ? Color.white : MelodiaTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    homeFilter == tag ? MelodiaTheme.accent : Color.white.opacity(0.07),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recentGrid: some View {
        if !recentPlaylists.isEmpty {
            LazyVGrid(columns: gridColumns, spacing: 7) {
                ForEach(recentPlaylists.prefix(8)) { record in
                    NavigationLink {
                        PlaylistView(
                            route: PlaylistRoute(
                                id: record.data.id,
                                title: record.data.name,
                                cover: record.data.coverImgUrl
                            )
                        )
                    } label: {
                        RecentPlayTile(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !appModel.dailySongs.isEmpty {
                dailySpotlight
            }
            forYouSection
        }
    }

    private var dailySpotlight: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeading(title: "今日为你推荐")
                .padding(.horizontal, 18)

            NavigationLink {
                DailySongsView(songs: appModel.dailySongs)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CoverImage(url: appModel.dailySongs.first?.coverURL, size: 64, cornerRadius: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("每日推荐")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(MelodiaTheme.textPrimary)
                            Text("根据你的口味 · \(todayText())")
                                .font(.system(size: 12))
                                .foregroundStyle(MelodiaTheme.textSecondary)
                        }
                        Spacer()
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        Text(trackLine)
                            .font(.system(size: 12))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            player.playAll(appModel.dailySongs)
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(MelodiaTheme.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [MelodiaTheme.accent.opacity(0.34), MelodiaTheme.surface.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
        }
    }

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeading(title: "为你定制")
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(forYouEntries) { entry in
                        forYouCard(entry)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    @ViewBuilder
    private func forYouCard(_ entry: ForYouEntryModel) -> some View {
        if let playlistID = entry.playlistID, let title = entry.playlistTitle {
            NavigationLink {
                PlaylistView(route: PlaylistRoute(id: playlistID, title: title))
            } label: {
                ForYouCardBody(entry: entry)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Task { await perform(entry.action) }
            } label: {
                ForYouCardBody(entry: entry)
            }
            .buttonStyle(.plain)
        }
    }

    private var forYouEntries: [ForYouEntryModel] {
        var result: [ForYouEntryModel] = []

        if let hotlist = appModel.toplists.first(where: { $0.name.contains("热") }) ?? appModel.toplists.first {
            result.append(
                ForYouEntryModel(
                    id: "hot",
                    title: "热歌榜",
                    subtitle: "最热音乐随时听",
                    icon: "flame.fill",
                    colors: [Color(red: 0.95, green: 0.35, blue: 0.22), Color(red: 0.62, green: 0.10, blue: 0.12)],
                    playlistID: hotlist.id,
                    playlistTitle: hotlist.name,
                    action: .idle
                )
            )
        }

        result.append(
            ForYouEntryModel(
                id: "heart",
                title: "心动模式",
                subtitle: "智能红心电台",
                icon: "heart.fill",
                colors: [Color(red: 0.96, green: 0.40, blue: 0.58), Color(red: 0.55, green: 0.16, blue: 0.52)],
                playlistID: nil,
                playlistTitle: nil,
                action: .intelligence
            )
        )

        if let radar = appModel.homePlaylists.first(where: { $0.name.contains("雷达") }) {
            result.append(
                ForYouEntryModel(
                    id: "radar",
                    title: "私人雷达",
                    subtitle: "根据喜好定制",
                    icon: "dot.radiowaves.left.and.right",
                    colors: [Color(red: 0.32, green: 0.55, blue: 0.96), Color(red: 0.18, green: 0.20, blue: 0.62)],
                    playlistID: radar.id,
                    playlistTitle: radar.name,
                    action: .idle
                )
            )
        }

        result.append(
            ForYouEntryModel(
                id: "roaming",
                title: "音乐漫游",
                subtitle: "无限探索相似歌曲",
                icon: "shuffle",
                colors: [Color(red: 0.22, green: 0.72, blue: 0.55), Color(red: 0.08, green: 0.40, blue: 0.40)],
                playlistID: nil,
                playlistTitle: nil,
                action: .roaming
            )
        )

        return result
    }

    private func perform(_ action: ForYouAction) async {
        switch action {
        case .intelligence:
            await startSeedRadio(shuffle: false)
        case .roaming:
            await startSeedRadio(shuffle: true)
        case .idle:
            break
        }
    }

    private func startSeedRadio(shuffle: Bool) async {
        actionMessage = nil
        var seed = player.currentTrack ?? appModel.dailySongs.first
        if seed == nil, let playlist = appModel.homePlaylists.first {
            if let detail = try? await client.playlist(id: playlist.id) {
                seed = detail.tracks.first
            }
        }
        guard let seed else {
            actionMessage = "暂时没有可用的推荐歌曲，请先播放一首歌或登录账号。"
            return
        }

        let similar = (try? await client.similarSongs(id: seed.id)) ?? []
        var queue = [seed] + similar
        if shuffle {
            queue.shuffle()
        }
        player.play(seed, queue: queue.isEmpty ? [seed] : queue)
    }

    private func reload() async {
        isLoadingFeed = shelves.isEmpty
        feedError = nil
        await appModel.loadHome()
        recentPlaylists = (try? await client.recentPlaylists()) ?? []
        do {
            let page = try await client.homeBlockPage(refresh: false)
            shelves = page.shelves
            nextCursor = page.cursor
            hasMoreShelves = page.hasMore
        } catch {
            feedError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoadingFeed = false
    }

    private func loadMoreShelves() async {
        guard hasMoreShelves, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let page = try await client.homeBlockPage(cursor: nextCursor ?? "", refresh: false)
            shelves.append(contentsOf: page.shelves)
            nextCursor = page.cursor
            hasMoreShelves = page.hasMore
        } catch {
            feedError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoadingMore = false
    }

    private var trackLine: String {
        let names = appModel.dailySongs.prefix(8).map(\.name)
        return "\(appModel.dailySongs.count) 首 · " + names.joined(separator: " · ")
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private func todayText() -> String {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        return "\(components.month ?? 0)月\(components.day ?? 0)日"
    }
}
private struct RecentPlayTile: View {
    let record: RecentPlaylistRecord

    var body: some View {
        HStack(spacing: 8) {
            CoverImage(url: URL(string: record.data.coverImgUrl), size: 48, cornerRadius: 6)
            Text(record.data.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.trailing, 7)
            Spacer(minLength: 0)
        }
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(MelodiaTheme.textPrimary)
    }
}

private enum ForYouAction {
    case idle
    case intelligence
    case roaming
}

private struct ForYouEntryModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let playlistID: Int64?
    let playlistTitle: String?
    let action: ForYouAction
}

private struct ForYouCardBody: View {
    let entry: ForYouEntryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: entry.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

                Image(systemName: entry.icon)
                    .font(.system(size: 78, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.13))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 18, y: -10)
                    .clipped()

                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: entry.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                    Spacer()
                    Text(entry.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(entry.colors.last ?? .white)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .padding(.leading, 10)
                        .padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(width: 132, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(entry.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(MelodiaTheme.textSecondary)
                .lineLimit(1)
                .frame(width: 132, alignment: .leading)
        }
        .frame(width: 132)
    }
}

private struct HomeShelfSection: View {
    let shelf: HomeShelfModel

    @EnvironmentObject private var player: PlayerEngine
    private let client = NeteaseClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shelf.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(shelf.cards.indices, id: \.self) { index in
                    let card = shelf.cards[index]
                        HomeShelfCard(
                            card: card,
                            rank: shelf.showRank ? index + 1 : nil,
                            onPlaySong: { songID in
                                Task { await playSong(songID) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func playSong(_ songID: Int64) async {
        let songIDs = shelf.cards.compactMap { card -> Int64? in
            if case .song(let id, _, _, _) = card { return id }
            return nil
        }
        let tracks = (try? await client.songDetails(ids: songIDs)) ?? []
        if let selected = tracks.first(where: { $0.id == songID }) {
            player.play(selected, queue: tracks)
        } else if let track = try? await client.songDetails(ids: [songID]).first {
            player.play(track)
        }
    }
}

private struct HomeShelfCard: View {
    let card: HomeCardModel
    let rank: Int?
    let onPlaySong: (Int64) -> Void

    var body: some View {
        switch card {
        case .playlist(let id, let title, let cover, _):
            NavigationLink {
                PlaylistView(route: PlaylistRoute(id: id, title: title, cover: cover))
            } label: {
                cardBody
            }
            .buttonStyle(.plain)
        case .album(let id, let title, let cover, _):
            NavigationLink {
                AlbumView(route: AlbumRoute(id: id, title: title, cover: cover))
            } label: {
                cardBody
            }
            .buttonStyle(.plain)
        case .song(let id, _, _, _):
            Button {
                onPlaySong(id)
            } label: {
                cardBody
            }
            .buttonStyle(.plain)
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                CoverImage(url: card.coverURL, size: 132, cornerRadius: 10)

                if card.isSong {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(MelodiaTheme.accent, in: Circle())
                        .padding(7)
                }
            }

            Text(rank.map { "\(card.typeLabel) · \($0)" } ?? card.typeLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MelodiaTheme.textTertiary)
                .lineLimit(1)
                .padding(.top, 4)

            Text(card.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .lineLimit(1)

            if !card.caption.isEmpty {
                Text(card.caption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 132, alignment: .leading)
    }
}

struct DailySongsView: View {
    let songs: [Track]

    @EnvironmentObject private var player: PlayerEngine

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(songs.indices, id: \.self) { index in
                    let track = songs[index]
                    TrackRow(track: track, queue: songs, number: index + 1)
                    if index < songs.count - 1 {
                        Divider().overlay(MelodiaTheme.divider)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("每日推荐")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    player.playAll(songs)
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                }
                .foregroundStyle(MelodiaTheme.textPrimary)
            }
        }
    }
}