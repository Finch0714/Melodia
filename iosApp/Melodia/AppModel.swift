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

    private let client = NeteaseClient.shared
    private var qrTask: Task<Void, Never>?
    private var qrSession: QRLoginSession?
    private var didBootstrap = false
    private var didLoadLibrary = false

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refreshSession()
        await loadHome()
    }

    func loadHome() async {
        isLoadingHome = true
        homeError = nil
        do {
            homePlaylists = try await client.personalizedPlaylists()
        } catch {
            homeError = message(for: error)
        }
        do {
            toplists = try await client.toplists()
        } catch {
            if homeError == nil {
                homeError = message(for: error)
            }
        }
        if isLoggedIn {
            dailySongs = (try? await client.dailyRecommendations()) ?? []
        } else {
            dailySongs = []
        }
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

        do {
            libraryPlaylists = try await client.userPlaylists(uid: uid)
        } catch {
            libraryError = message(for: error)
        }
        do {
            libraryAlbums = try await client.subscribedAlbums()
        } catch {
            if libraryError == nil { libraryError = message(for: error) }
        }
        do {
            libraryCount = try await client.userSubcount()
        } catch {
            if libraryError == nil { libraryError = message(for: error) }
        }
        do {
            likedSongIDs = Set(try await client.likedSongIDs(uid: uid))
        } catch {
            if libraryError == nil { libraryError = message(for: error) }
        }

        didLoadLibrary = true
        isLoadingLibrary = false
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
            } else {
                likedSongIDs.remove(track.id)
            }
        } catch {
            libraryError = message(for: error)
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

    private func clearLibrary() {
        libraryPlaylists = []
        libraryAlbums = []
        libraryCount = nil
        likedSongIDs = []
        libraryError = nil
        didLoadLibrary = false
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