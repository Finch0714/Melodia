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
    @State private var presentedArtist: ArtistRoute?
    @State private var presentedAlbum: AlbumRoute?
    @State private var albumDetail: AlbumDetail?
    @State private var artistDetails: [ArtistDetail] = []
    @State private var artistAlbums: [ArtistAlbum] = []
    @State private var previewComments: [CommentItem] = []
    @State private var previewCommentTotal = 0
    @State private var previewCommentsLoading = false
    @State private var similarSongs: [Track] = []
    @State private var songWiki: SongWikiData?

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
            let safeTop = max(geometry.safeAreaInsets.top, 0)
            let safeBottom = max(geometry.safeAreaInsets.bottom, 0)

            ZStack {
                playerBackground(blurred: backgroundStyle == .cover)
                    .frame(width: width, height: height)

                if showLyrics {
                    lyricsScreen(size: size, wide: wide, safeBottom: safeBottom)
                        .overlay(alignment: .top) {
                            lyricsHeader(safeTop: safeTop, size: size)
                        }
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
        .sheet(item: $presentedArtist) { route in
            NavigationStack {
                ArtistView(route: route)
                    .environmentObject(player)
                    .environmentObject(appModel)
            }
        }
        .sheet(item: $presentedAlbum) { route in
            NavigationStack {
                AlbumView(route: route)
                    .environmentObject(player)
                    .environmentObject(appModel)
            }
        }
        .task(id: player.currentTrack?.id) {
            guard let track = player.currentTrack else {
                resetSupplementalData()
                return
            }
            await loadSupplementalData(for: track)
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
                    .padding(.bottom, 8)
                playerInfoSection
                    .padding(.top, 8)
                Color.clear.frame(height: 24)
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func widePlayer(size: CGSize) -> some View {
        let leftWidth = min(420, max(300, size.width * 0.40))
        let coverSide = min(leftWidth, max(120, size.height - 380))

        return VStack(spacing: 0) {
            sourceBar
                .padding(.horizontal, 24)
                .padding(.top, 16)

            HStack(alignment: .top, spacing: 56) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        coverArt(side: coverSide)
                            .padding(.top, 8)

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
                            .padding(.bottom, 8)

                        playerInfoSection
                            .padding(.top, 8)

                        Color.clear.frame(height: 24)
                    }
                    .frame(width: leftWidth)
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
                        if let track = player.currentTrack {
                            Button {
                                DownloadManager.shared.download(track, quality: player.audioQuality)
                            } label: {
                                Label(
                                    DownloadManager.shared.isDownloading(track.id) ? "正在下载…" : "下载",
                                    systemImage: "arrow.down.circle"
                                )
                            }
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

                HStack(spacing: 8) {
                    Text(player.currentTrack?.artistText ?? "")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(MelodiaTheme.textPrimary.opacity(0.75))
                        .lineLimit(1)

                    if showQualityBadge {
                        qualityBadge
                    }
                }
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
        HStack(spacing: 0) {
            AudioRoutePicker()
                .frame(width: 40, height: 44)
                .accessibilityLabel("播放设备")

            Spacer(minLength: 4)

            actionIcon("text.quote", label: "歌词", size: 23) {
                showLyrics = true
            }

            actionIcon("bubble.left", label: "评论", size: 22) {
                showComments = true
            }

            if let shareURL {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            actionIcon("list.bullet", label: "队列", size: 26) {
                showQueue = true
            }
            .disabled(player.queue.isEmpty)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
    }

    private var qualityBadge: some View {
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MelodiaTheme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.07), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("音质 \(player.audioQuality.title)")
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

    @ViewBuilder
    private var playerInfoSection: some View {
        if let track = player.currentTrack {
            PlayerInfoCards(
                track: track,
                albumDetail: albumDetail,
                artistDetails: artistDetails,
                artistAlbums: artistAlbums,
                previewComments: previewComments,
                commentsTotal: previewCommentTotal,
                commentsLoading: previewCommentsLoading,
                similarSongs: similarSongs,
                songWiki: songWiki,
                lyrics: player.lyrics,
                currentLyricIndex: player.currentLyricIndex,
                lyricsLoading: player.lyricsLoading,
                qualityTitle: player.audioQuality.title,
                onOpenLyrics: {
                    showLyrics = true
                },
                onOpenComments: {
                    showComments = true
                },
                onOpenArtist: { route in
                    presentedArtist = route
                },
                onOpenAlbum: { route in
                    presentedAlbum = route
                },
                onPlaySimilar: { selected in
                    let queue = similarSongs.contains(where: { $0.id == selected.id })
                        ? similarSongs
                        : [selected] + similarSongs
                    player.play(selected, queue: queue)
                }
            )
        }
    }

    @MainActor
    private func resetSupplementalData() {
        albumDetail = nil
        artistDetails = []
        artistAlbums = []
        previewComments = []
        previewCommentTotal = 0
        previewCommentsLoading = false
        similarSongs = []
        songWiki = nil
    }

    @MainActor
    private func loadSupplementalData(for track: Track) async {
        resetSupplementalData()
        previewCommentsLoading = true

        let albumID = track.album?.id ?? 0
        let artistIDs = track.artists.map(\.id)
        let primaryArtistID = artistIDs.first ?? 0

        async let albumRequest = fetchAlbum(id: albumID)
        async let artistsRequest = fetchArtists(ids: artistIDs)
        async let albumsRequest = fetchArtistAlbums(artistID: primaryArtistID)
        async let commentsRequest = fetchPreviewComments(songID: track.id)
        async let similarRequest = fetchSimilarSongs(id: track.id)
        async let wikiRequest = fetchSongWiki(id: track.id)

        let wiki = await wikiRequest
        guard !Task.isCancelled, player.currentTrack?.id == track.id else { return }
        songWiki = wiki

        let album = await albumRequest
        guard !Task.isCancelled, player.currentTrack?.id == track.id else { return }
        albumDetail = album

        let artists = await artistsRequest
        guard !Task.isCancelled, player.currentTrack?.id == track.id else { return }
        artistDetails = artists

        let albums = await albumsRequest
        guard !Task.isCancelled, player.currentTrack?.id == track.id else { return }
        artistAlbums = albums

        let comments = await commentsRequest
        guard !Task.isCancelled, player.currentTrack?.id == track.id else { return }
        previewComments = comments.comments
        previewCommentTotal = comments.total
        previewCommentsLoading = false

        let similar = await similarRequest
        guard !Task.isCancelled, player.currentTrack?.id == track.id else { return }
        similarSongs = similar
    }

    private func fetchAlbum(id: Int64) async -> AlbumDetail? {
        guard id > 0 else { return nil }
        return try? await NeteaseClient.shared.albumDetail(id: id).album
    }

    private func fetchArtists(ids: [Int64]) async -> [ArtistDetail] {
        var results: [ArtistDetail] = []
        for id in ids.prefix(4) {
            if Task.isCancelled { break }
            if let detail = try? await NeteaseClient.shared.artistDetail(id: id) {
                results.append(detail)
            }
        }
        return results
    }

    private func fetchArtistAlbums(artistID: Int64) async -> [ArtistAlbum] {
        guard artistID > 0 else { return [] }
        return (try? await NeteaseClient.shared.artistAlbums(id: artistID, limit: 20)) ?? []
    }

    private func fetchPreviewComments(songID: Int64) async -> (comments: [CommentItem], total: Int) {
        do {
            let data = try await NeteaseClient.shared.comments(
                threadID: "R_SO_4_\(songID)",
                page: 1,
                pageSize: 3,
                sortType: 99
            )
            return (data.comments, data.totalCount)
        } catch {
            return ([], 0)
        }
    }

    private func fetchSimilarSongs(id: Int64) async -> [Track] {
        (try? await NeteaseClient.shared.similarSongs(id: id)) ?? []
    }

    private func fetchSongWiki(id: Int64) async -> SongWikiData? {
        guard id > 0 else { return nil }
        return try? await NeteaseClient.shared.songWiki(songID: id)
    }
    private func lyricsScreen(size: CGSize, wide: Bool, safeBottom: CGFloat) -> some View {
        ZStack {
            playerBackground(blurred: true)
                .overlay(Color.black.opacity(0.30))
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(0)

            lyricsScrollContent(size: size, wide: wide)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, safeBottom)
                .zIndex(1)
        }
        .frame(width: size.width, height: size.height)
    }

    private func lyricsHeader(safeTop: CGFloat, size: CGSize) -> some View {
        let resolvedTopInset = safeTop > 0 ? safeTop : (size.height > size.width ? 48 : 12)

        return lyricsTopBar
            .padding(.horizontal, 14)
            .padding(.top, resolvedTopInset + 8)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.72), Color.black.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.height > 64 {
                            showLyrics = false
                        }
                    }
            )
            .zIndex(100)
    }

    private var lyricsTopBar: some View {
        HStack(spacing: 8) {
            Button {
                showLyrics = false
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                    Text("返回")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(MelodiaTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.42), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("返回播放页")

            Spacer(minLength: 8)

            Button {
                showLyricSettings = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                    Text("设置")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(MelodiaTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.42), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("歌词设置")
            .accessibilityIdentifier("lyrics.settings.button")

            Menu {
                Button {
                    showLyrics = false
                    showComments = true
                } label: {
                    Label("评论", systemImage: "bubble.left")
                }
                Button {
                    showQueue = true
                } label: {
                    Label("播放队列", systemImage: "list.bullet")
                }
                if let track = player.currentTrack {
                    Button {
                        DownloadManager.shared.download(track, quality: player.audioQuality)
                    } label: {
                        Label(
                            DownloadManager.shared.isDownloading(track.id) ? "正在下载…" : "下载",
                            systemImage: "arrow.down.circle"
                        )
                    }
                }
                Divider()
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("分享歌曲", systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .frame(width: 40, height: 38)
                    .background(Color.black.opacity(0.42), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("更多")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay(alignment: .center) {
            VStack(spacing: 1) {
                Text(player.currentTrack?.name ?? "歌词")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(player.currentTrack?.artistText ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 132)
            .allowsHitTesting(false)
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
