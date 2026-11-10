import Foundation
import SwiftUI

struct PlayerInfoCards: View {
    let track: Track
    let albumDetail: AlbumDetail?
    let artistDetails: [ArtistDetail]
    let artistAlbums: [ArtistAlbum]
    let previewComments: [CommentItem]
    let commentsTotal: Int
    let commentsLoading: Bool
    let similarSongs: [Track]
    let lyrics: [LyricLine]
    let currentLyricIndex: Int
    let lyricsLoading: Bool
    let qualityTitle: String
    let onOpenLyrics: () -> Void
    let onOpenComments: () -> Void
    let onOpenArtist: (ArtistRoute) -> Void
    let onOpenAlbum: (AlbumRoute) -> Void
    let onPlaySimilar: (Track) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LyricsPreviewCard(
                lyrics: lyrics,
                currentLyricIndex: currentLyricIndex,
                isLoading: lyricsLoading,
                onOpen: onOpenLyrics
            )

            CommentsPreviewCard(
                comments: previewComments,
                total: commentsTotal,
                isLoading: commentsLoading,
                onOpen: onOpenComments
            )

            SongDetailCard(
                track: track,
                qualityTitle: qualityTitle,
                onOpenArtist: {
                    if let artist = track.artists.first {
                        onOpenArtist(ArtistRoute(artist: artist))
                    }
                },
                onOpenAlbum: {
                    if let album = track.album {
                        onOpenAlbum(AlbumRoute(album: album))
                    }
                }
            )

            if let albumDetail,
               let description = albumDetail.description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                AlbumStoryCard(
                    album: albumDetail,
                    onOpenAlbum: {
                        onOpenAlbum(AlbumRoute(id: albumDetail.id, title: albumDetail.name, cover: albumDetail.picUrl))
                    }
                )
            }

            if !artistDetails.isEmpty {
                AboutArtistCard(details: artistDetails, onOpenArtist: onOpenArtist)
            }

            if !artistAlbums.isEmpty {
                ArtistAlbumsCard(
                    albums: artistAlbums,
                    artistName: artistDetails.first?.name ?? track.artists.first?.name,
                    onOpenAlbum: onOpenAlbum
                )
            }

            if !similarSongs.isEmpty {
                SimilarSongsCard(
                    songs: similarSongs,
                    onPlay: onPlaySimilar
                )
            }
        }
    }
}

private struct PlayerInfoSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MelodiaTheme.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

private struct PlayerCapsuleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.11), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewLyric: Identifiable {
    let index: Int
    let line: LyricLine
    var id: String { line.id }
}

private struct LyricsPreviewCard: View {
    let lyrics: [LyricLine]
    let currentLyricIndex: Int
    let isLoading: Bool
    let onOpen: () -> Void

    private var previewLines: [PreviewLyric] {
        let visibleCount = 4
        guard !lyrics.isEmpty else { return [] }
        let current = min(max(currentLyricIndex, 0), lyrics.count - 1)
        let latestStart = max(0, lyrics.count - visibleCount)
        let start = min(max(0, current - 1), latestStart)
        return lyrics.enumerated()
            .dropFirst(start)
            .prefix(visibleCount)
            .map { PreviewLyric(index: $0.offset, line: $0.element) }
    }

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("歌词预览")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                Group {
                    if isLoading && lyrics.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(MelodiaTheme.accentSoft)
                            Text("正在加载歌词…")
                                .font(.system(size: 14))
                                .foregroundStyle(MelodiaTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 152)
                    } else if previewLines.isEmpty {
                        Text("暂无歌词")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 152, alignment: .center)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(previewLines) { item in
                                lyricLine(item)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
                        .clipped()
                    }
                }

                PlayerCapsuleButton(title: "显示歌词", action: onOpen)
            }
        }
    }

    private func lyricLine(_ item: PreviewLyric) -> some View {
        let isCurrent = item.index == currentLyricIndex
        let distance = abs(item.index - currentLyricIndex)
        let opacity = isCurrent ? 1.0 : max(0.38, 0.82 - Double(distance) * 0.12)

        return VStack(alignment: .leading, spacing: 4) {
            Text(item.line.text)
                .font(.system(size: isCurrent ? 20 : 18, weight: .heavy))
                .foregroundStyle(MelodiaTheme.textPrimary.opacity(opacity))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let translation = item.line.translation,
               !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(translation)
                    .font(.system(size: isCurrent ? 15 : 14, weight: .medium))
                    .foregroundStyle(MelodiaTheme.textSecondary.opacity(isCurrent ? 0.9 : 0.62))
                    .lineLimit(2)
            }
        }
        .scaleEffect(isCurrent ? 1.08 : 1, anchor: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.24), value: currentLyricIndex)
    }
}

private struct CommentsPreviewCard: View {
    let comments: [CommentItem]
    let total: Int
    let isLoading: Bool
    let onOpen: () -> Void

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("评论")
                        .font(.system(size: 18, weight: .bold))
                    if total > 0 {
                        Text("(\(total))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textSecondary.opacity(0.82))
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(MelodiaTheme.textPrimary)

                if isLoading && comments.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(MelodiaTheme.accentSoft)
                        Text("正在加载评论…")
                            .font(.system(size: 14))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 74)
                } else if comments.isEmpty {
                    Text("暂无评论")
                        .font(.system(size: 14))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                } else {
                    VStack(spacing: 12) {
                        ForEach(0..<min(2, comments.count), id: \.self) { index in
                            commentRow(comments[index])
                            if index == 0, comments.count > 1 {
                                Divider().overlay(MelodiaTheme.divider)
                            }
                        }
                    }

                    Button(action: onOpen) {
                        Text("查看全部 \(max(total, comments.count)) 条评论")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
        }
    }

    private func commentRow(_ comment: CommentItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            CoverImage(url: comment.user.avatarURL, size: 36, cornerRadius: 18)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.user.nickname)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(comment.timeStr?.isEmpty == false ? comment.timeStr! : relativeTime(comment.time))
                        .font(.system(size: 11))
                        .foregroundStyle(MelodiaTheme.textTertiary)
                        .lineLimit(1)
                }

                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Label("\(comment.likedCount)", systemImage: comment.liked ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundStyle(MelodiaTheme.textTertiary)
            }
        }
    }

    private func relativeTime(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct SongDetailCard: View {
    let track: Track
    let qualityTitle: String
    let onOpenArtist: () -> Void
    let onOpenAlbum: () -> Void

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("歌曲详情")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                VStack(spacing: 12) {
                    if !track.albumName.isEmpty {
                        detailRow("专辑", value: track.albumName, action: onOpenAlbum)
                    }
                    if !track.artistText.isEmpty {
                        detailRow("歌手", value: track.artistText, action: onOpenArtist)
                    }
                    detailRow("时长", value: track.formattedDuration)
                    if let publishTime = track.album?.publishTime, publishTime > 0 {
                        detailRow("发行时间", value: formattedDate(publishTime))
                    }
                    if !qualityTitle.isEmpty {
                        detailRow("音质", value: qualityTitle)
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(MelodiaTheme.textTertiary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MelodiaTheme.textTertiary)
                    .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action?()
        }
    }

    private func formattedDate(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct AlbumStoryCard: View {
    let album: AlbumDetail
    let onOpenAlbum: () -> Void

    @State private var expanded = false

    private var description: String {
        album.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 15) {
                Text("专辑介绍")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                HStack(spacing: 13) {
                    CoverImage(url: album.coverURL, size: 58, cornerRadius: 9)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                            .lineLimit(1)
                        Text(album.artistText)
                            .font(.system(size: 12))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(4)
                    .lineLimit(expanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            expanded.toggle()
                        }
                    }

                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            expanded.toggle()
                        }
                    } label: {
                        Text(expanded ? "收起" : "查看更多")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onOpenAlbum) {
                        Text("查看专辑")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MelodiaTheme.accentSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AboutArtistCard: View {
    let details: [ArtistDetail]
    let onOpenArtist: (ArtistRoute) -> Void

    @State private var selected = 0

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("关于艺人")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                if details.count == 1, let detail = details.first {
                    artistPage(detail)
                } else {
                    TabView(selection: $selected) {
                        ForEach(details.indices, id: \.self) { index in
                            artistPage(details[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 328)

                    HStack(spacing: 6) {
                        ForEach(details.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selected ? Color.white : Color.white.opacity(0.25))
                                .frame(width: index == selected ? 6 : 5, height: index == selected ? 6 : 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func artistPage(_ detail: ArtistDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                CachedRemoteImage(
                    url: detail.imageURL?.melodiaImageURL(pixels: 720),
                    contentMode: .fill
                ) {
                    MelodiaTheme.coverPlaceholder
                }
                .frame(height: 176)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(detail.musicSize) 首歌曲 · \(detail.albumSize) 张专辑")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(14)
            }
            .frame(height: 176)

            if !detail.briefDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ArtistDescription(text: detail.briefDesc)
            }

            Button {
                onOpenArtist(
                    ArtistRoute(
                        id: detail.id,
                        title: detail.name,
                        avatar: detail.cover.isEmpty ? detail.avatar : detail.cover
                    )
                )
            } label: {
                Text("查看歌手")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ArtistDescription: View {
    let text: String
    @State private var expanded = false

    private var cleanText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(cleanText)
                .font(.system(size: 13))
                .foregroundStyle(MelodiaTheme.textSecondary)
                .lineSpacing(4)
                .lineLimit(expanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            if cleanText.count > 95 {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        expanded.toggle()
                    }
                } label: {
                    Text(expanded ? "收起" : "查看更多")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ArtistAlbumsCard: View {
    let albums: [ArtistAlbum]
    let artistName: String?
    let onOpenAlbum: (AlbumRoute) -> Void

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text(artistName.map { "\($0)的更多专辑" } ?? "更多专辑")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(albums.prefix(20)) { album in
                            Button {
                                onOpenAlbum(AlbumRoute(artistAlbum: album))
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverImage(url: album.coverURL, size: 120, cornerRadius: 10)
                                    Text(album.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                        .frame(width: 120, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct SimilarSongsCard: View {
    let songs: [Track]
    let onPlay: (Track) -> Void

    var body: some View {
        PlayerInfoSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("相似歌曲")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(songs.prefix(12)) { song in
                            Button {
                                onPlay(song)
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    CoverImage(url: song.coverURL, size: 108, cornerRadius: 10)
                                    Text(song.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                        .frame(width: 108, alignment: .leading)
                                    Text(song.artistText)
                                        .font(.system(size: 11))
                                        .foregroundStyle(MelodiaTheme.textSecondary)
                                        .lineLimit(1)
                                        .frame(width: 108, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
