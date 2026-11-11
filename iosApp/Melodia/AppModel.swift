import Combine
import CoreImage
import Foundation
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var homePlaylists: [PlaylistSummary] = []
    @Published private(set) var toplists: [PlaylistSummary] = []
    @Published private(set) var dailySongs: [Track] = []
    @Published private(set) var isLoadingHome = false
    @Published private(set) var isLoggedIn = false
    @Published private(set) var profile: UserProfile?
    @Published var homeError: String?

    @Published private(set) var qrCodeImage: UIImage?
    @Published private(set) var qrStatusText = "正在生成二维码…"
    @Published private(set) var isQRLoading = false
    @Published var loginError: String?

    @Published private(set) var libraryPlaylists: [UserPlaylist] = []
    @Published private(set) var libraryAlbums: [AlbumShelfItem] = []
    @Published private(set) var libraryCount: UserSubcount?
    @Published private(set) var likedSongIDs: Set<Int64> = []
    @Published private(set) var isLoadingLibrary = false
    @Published var libraryError: String?
    @Published private(set) var likedSongs: [Track] = []
    @Published private(set) var likedSongsTotal = 0
    @Published private(set) var isLoadingLikedSongs = false
    @Published private(set) var isBackfillingLikedSongs = false
    @Published var likedSongsError: String?

    private let client = NeteaseClient.shared
    private var qrTask: Task<Void, Never>?
    private var qrSession: QRLoginSession?
    private var didBootstrap = false
    private var didLoadLibrary = false
    private var didLoadLikedSongs = false
    private var likedSongsTask: Task<Void, Never>?

    var likedSongsDisplayCount: Int {
        max(likedSongsTotal, likedSongIDs.count)
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refreshSession()
        await loadHome()
    }

    func loadHome() async {
        isLoadingHome = true
        homeError = nil

        async let personalized = try? client.personalizedPlaylists()
        async let rankings = try? client.toplists()
        async let daily = dailySongsIfLoggedIn()
        let (personalizedValue, rankingsValue, dailyValue) = await (personalized, rankings, daily)

        if let personalizedValue {
            homePlaylists = personalizedValue
        } else {
            homeError = "首页推荐加载失败，请稍后重试"
        }
        if let rankingsValue {
            toplists = rankingsValue
        } else if homeError == nil {
            homeError = "排行榜加载失败，请稍后重试"
        }
        dailySongs = dailyValue
        isLoadingHome = false
    }

    func refreshSession() async {
        isLoggedIn = await client.loggedIn()
        if isLoggedIn {
            do {
                if let loaded = try await client.account() {
                    profile = loaded
                } else {
                    isLoggedIn = false
                }
            } catch {
                // Keep the local session on transient network failures.
            }
        } else {
            profile = nil
        }
        if !isLoggedIn {
            clearLibrary()
        }
    }

    func loadLibrary(force: Bool = false) async {
        guard isLoggedIn, let uid = profile?.userId else { return }
        if didLoadLibrary && !force { return }
        isLoadingLibrary = true
        libraryError = nil

        async let playlists = try? client.userPlaylists(uid: uid)
        async let albums = try? client.subscribedAlbums()
        async let count = try? client.userSubcount()
        let (playlistsValue, albumsValue, countValue) = await (playlists, albums, count)

        if let playlistsValue {
            libraryPlaylists = playlistsValue
        } else {
            libraryError = "歌单加载失败，请稍后重试"
        }
        if let albumsValue {
            libraryAlbums = albumsValue
        } else if libraryError == nil {
            libraryError = "收藏专辑加载失败，请稍后重试"
        }
        if let countValue {
            libraryCount = countValue
        } else if libraryError == nil {
            libraryError = "账号资料加载失败，请稍后重试"
        }
        didLoadLibrary = true
        isLoadingLibrary = false

        Task { [weak self] in
            await self?.loadLikedSongs()
        }
    }

    func isTrackLiked(_ track: Track) -> Bool {
        likedSongIDs.contains(track.id)
    }

    func toggleLike(_ track: Track) async {
        guard isLoggedIn, profile != nil else {
            loginError = "请先登录后再收藏歌曲"
            return
        }
        let shouldLike = !likedSongIDs.contains(track.id)
        do {
            try await client.likeSong(trackID: track.id, like: shouldLike)
            if shouldLike {
                likedSongIDs.insert(track.id)
                if didLoadLikedSongs && !likedSongs.contains(where: { $0.id == track.id }) {
                    likedSongs.insert(track, at: 0)
                    likedSongsTotal = max(likedSongsTotal + 1, likedSongs.count)
                }
            } else {
                likedSongIDs.remove(track.id)
                if didLoadLikedSongs {
                    likedSongs.removeAll { $0.id == track.id }
                    likedSongsTotal = max(likedSongs.count, likedSongsTotal - 1)
                }
            }
        } catch {
            libraryError = message(for: error)
        }
    }

    func loadLikedSongs(force: Bool = false) async {
        guard isLoggedIn, let uid = profile?.userId else {
            likedSongsError = "请先登录后查看喜欢的音乐"
            isLoadingLikedSongs = false
            return
        }
        if isLoadingLikedSongs && !force { return }
        if didLoadLikedSongs && !force { return }

        likedSongsTask?.cancel()
        likedSongsTask = nil
        isBackfillingLikedSongs = false
        isLoadingLikedSongs = true
        likedSongsError = nil

        let likedPlaylistID = libraryPlaylists.first(where: {
            $0.isLikedPlaylist || $0.id == uid
        })?.id ?? uid

        do {
            let detail = try await client.playlist(id: likedPlaylistID)
            guard !Task.isCancelled else { return }
            likedSongsTotal = max(max(detail.trackCount, detail.trackIds.count), detail.tracks.count)
            let allIDs = detail.trackIds.isEmpty ? detail.tracks.map(\.id) : detail.trackIds.map(\.id)
            if !allIDs.isEmpty {
                likedSongIDs = Set(allIDs)
            }

            if !detail.tracks.isEmpty {
                likedSongs = detail.tracks
                finishInitialLikedSongsLoad()
                let loadedIDs = Set(detail.tracks.map(\.id))
                backfillLikedSongs(ids: detail.trackIds.map(\.id).filter { !loadedIDs.contains($0) })
                return
            }

            let ids = detail.trackIds.map(\.id)
            if !ids.isEmpty {
                let firstIDs = Array(ids.prefix(200))
                likedSongs = try await client.songDetails(ids: firstIDs)
                guard !Task.isCancelled else { return }
                finishInitialLikedSongsLoad()
                backfillLikedSongs(ids: Array(ids.dropFirst(firstIDs.count)))
                return
            }

            likedSongs = []
            finishInitialLikedSongsLoad()
        } catch {
            guard !Task.isCancelled else { return }
            await loadLikedSongsFromLikes(uid: uid)
        }
    }

    func startQRLogin() {
        qrTask?.cancel()
        qrCodeImage = nil
        qrSession = nil
        loginError = nil
        qrStatusText = "正在生成二维码…"
        isQRLoading = true
        qrTask = Task { [weak self] in
            guard let self else { return }
            await self.runQRLogin()
        }
    }

    func stopQRLogin() {
        qrTask?.cancel()
        qrTask = nil
        isQRLoading = false
    }

    func logout() async {
        stopQRLogin()
        await client.logout()
        isLoggedIn = false
        profile = nil
        dailySongs = []
        qrCodeImage = nil
        clearLibrary()
        await loadHome()
    }

    func importCookie(_ value: String) async {
        await client.importCookie(value)
        loginError = nil
        await refreshSession()
        if isLoggedIn {
            qrStatusText = "Cookie 登录成功"
            qrCodeImage = nil
            await loadLibrary(force: true)
            await loadHome()
        } else {
            loginError = "Cookie 中没有找到有效的 MUSIC_U，请确认复制完整"
        }
    }

    private func runQRLogin() async {
        do {
            let session = try await client.qrKey()
            guard !Task.isCancelled else { return }
            qrSession = session
            qrCodeImage = QRCodeRenderer.image(for: "https://music.163.com/login?codekey=\(session.key)")
            qrStatusText = "请使用网易云音乐 App 扫码"
            isQRLoading = false

            for _ in 0..<90 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                let status = try await client.qrStatus(session: session)
                switch status.code {
                case 800:
                    qrStatusText = "二维码已过期，请重新生成"
                    return
                case 801:
                    qrStatusText = "等待扫码…"
                case 802:
                    qrStatusText = "已扫码，请在手机上确认"
                case 803:
                    qrStatusText = "登录成功"
                    qrCodeImage = nil
                    await refreshSession()
                    await loadLibrary(force: true)
                    await loadHome()
                    return
                default:
                    qrStatusText = status.message ?? "等待扫码…"
                }
            }
            qrStatusText = "二维码已过期，请重新生成"
        } catch {
            guard !Task.isCancelled else { return }
            loginError = message(for: error)
            qrStatusText = "二维码生成失败"
            isQRLoading = false
        }
    }

    private func dailySongsIfLoggedIn() async -> [Track] {
        guard isLoggedIn else { return [] }
        return (try? await client.dailyRecommendations()) ?? []
    }

    private func finishInitialLikedSongsLoad() {
        likedSongsTotal = max(likedSongsTotal, likedSongs.count)
        didLoadLikedSongs = true
        isLoadingLikedSongs = false
    }

    private func loadLikedSongsFromLikes(uid: Int64) async {
        do {
            let ids = try await client.likedSongIDs(uid: uid)
            guard !Task.isCancelled else { return }
            likedSongIDs = Set(ids)
            likedSongsTotal = max(likedSongsTotal, ids.count)
            let firstIDs = Array(ids.prefix(200))
            likedSongs = try await client.songDetails(ids: firstIDs)
            guard !Task.isCancelled else { return }
            finishInitialLikedSongsLoad()
            backfillLikedSongs(ids: Array(ids.dropFirst(firstIDs.count)))
        } catch {
            guard !Task.isCancelled else { return }
            likedSongsError = message(for: error)
            isLoadingLikedSongs = false
        }
    }

    private func backfillLikedSongs(ids: [Int64]) {
        guard !ids.isEmpty else {
            isBackfillingLikedSongs = false
            return
        }
        isBackfillingLikedSongs = true
        likedSongsTask = Task { [weak self] in
            guard let self else { return }
            var offset = 0
            while offset < ids.count && !Task.isCancelled {
                let end = min(offset + 1000, ids.count)
                let chunk = Array(ids[offset..<end])
                if let batch = try? await self.client.songDetails(ids: chunk), !Task.isCancelled {
                    let existingIDs = Set(self.likedSongs.map(\.id))
                    let newTracks = batch.filter { !existingIDs.contains($0.id) }
                    if !newTracks.isEmpty {
                        self.likedSongs.append(contentsOf: newTracks)
                        self.likedSongsTotal = max(self.likedSongsTotal, self.likedSongs.count)
                    }
                }
                offset = end
            }
            if !Task.isCancelled {
                self.isBackfillingLikedSongs = false
            }
        }
    }

    private func clearLibrary() {
        likedSongsTask?.cancel()
        likedSongsTask = nil
        libraryPlaylists = []
        libraryAlbums = []
        libraryCount = nil
        likedSongIDs = []
        likedSongs = []
        likedSongsTotal = 0
        isBackfillingLikedSongs = false
        likedSongsError = nil
        libraryError = nil
        didLoadLibrary = false
        didLoadLikedSongs = false
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

enum QRCodeRenderer {
    static func image(for text: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
