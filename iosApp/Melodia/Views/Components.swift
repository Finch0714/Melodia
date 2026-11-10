import Foundation
import SwiftUI

struct CoverImage: View {
    let url: URL?
    let size: CGFloat
    var cornerRadius: CGFloat = 14

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        CachedRemoteImage(
            url: url?.melodiaImageURL(pixels: requestPixels),
            contentMode: .fill
        ) {
            placeholder
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var requestPixels: Int {
        Int(min(1024, max(96, ceil(size * displayScale))))
    }

    private var placeholder: some View {
        ZStack {
            MelodiaTheme.coverPlaceholder
            Image(systemName: "music.note")
                .font(.system(size: max(16, size * 0.28), weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
        }
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
            }
            Spacer()
        }
    }
}

struct PlaylistCard: View {
    let playlist: PlaylistSummary
    var width: CGFloat = 148

    var body: some View {
        NavigationLink(value: PlaylistRoute(summary: playlist)) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .bottomTrailing) {
                    CoverImage(url: playlist.coverURL, size: width, cornerRadius: 18)
                    if let count = playlist.playCountText {
                        Label(count, systemImage: "play.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(9)
                    }
                }
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AlbumCard: View {
    let album: Album
    var width: CGFloat = 148

    var body: some View {
        NavigationLink(value: AlbumRoute(album: album)) {
            VStack(alignment: .leading, spacing: 9) {
                CoverImage(url: album.coverURL, size: width, cornerRadius: 18)
                Text(album.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: width, alignment: .leading)
                Text(album.artistText)
                    .font(.caption)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ArtistCard: View {
    let artist: Artist
    var width: CGFloat = 128

    var body: some View {
        NavigationLink(value: ArtistRoute(artist: artist)) {
            VStack(spacing: 9) {
                CoverImage(url: artist.avatarURL, size: width, cornerRadius: width / 2)
                    .clipShape(Circle())
                Text(artist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: width)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TrackRow: View {
    @EnvironmentObject private var player: PlayerEngine
    let track: Track
    var queue: [Track]
    var number: Int?
    var showCover = true

    private var isCurrent: Bool { player.currentTrack?.id == track.id }

    var body: some View {
        Button {
            player.play(track, queue: queue)
        } label: {
            HStack(spacing: 12) {
                if let number {
                    ZStack {
                        if isCurrent {
                            Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MelodiaTheme.accent)
                        } else {
                            Text("\(number)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(MelodiaTheme.textTertiary)
                        }
                    }
                    .frame(width: 24)
                }

                if showCover {
                    CoverImage(url: track.coverURL, size: 50, cornerRadius: 12)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.system(size: 15, weight: isCurrent ? .semibold : .medium))
                        .foregroundStyle(isCurrent ? MelodiaTheme.accentSoft : MelodiaTheme.textPrimary)
                        .lineLimit(1)
                    Text(track.artistText + (track.albumName.isEmpty ? "" : " · \(track.albumName)"))
                        .font(.caption)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Text(track.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(MelodiaTheme.textTertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var player: PlayerEngine
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 12) {
                Button {
                    showNowPlaying = true
                } label: {
                    HStack(spacing: 12) {
                        CoverImage(url: track.coverURL, size: 46, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MelodiaTheme.textPrimary)
                                .lineLimit(1)
                            Text(track.artistText)
                                .font(.caption)
                                .foregroundStyle(MelodiaTheme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if player.isLoading {
                    ProgressView()
                        .tint(MelodiaTheme.accentSoft)
                        .frame(width: 34, height: 34)
                } else {
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(MelodiaTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(!player.hasNext)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.36), radius: 18, y: 8)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MelodiaTheme.accentSoft)
            Text(message)
                .font(.footnote)
                .foregroundStyle(MelodiaTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .melodiaCard(radius: 14)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(MelodiaTheme.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(MelodiaTheme.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(MelodiaTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

struct LoadingCards: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 9) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MelodiaTheme.surface)
                        .frame(width: 148, height: 148)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(MelodiaTheme.surface)
                        .frame(width: 112, height: 13)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}
