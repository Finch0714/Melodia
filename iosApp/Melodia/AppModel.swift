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

    private let client = NeteaseClient.shared
    private var qrTask: Task<Void, Never>?
    private var didBootstrap = false

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
            profile = try? await client.account()
        } else {
            profile = nil
        }
    }

    func startQRLogin() {
        qrTask?.cancel()
        qrCodeImage = nil
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
        await loadHome()
    }

    func importCookie(_ value: String) async {
        await client.importCookie(value)
        loginError = nil
        await refreshSession()
        if isLoggedIn {
            qrStatusText = "Cookie 登录成功"
            qrCodeImage = nil
        } else {
            loginError = "Cookie 中没有找到 MUSIC_U，请确认复制完整"
        }
        await loadHome()
    }

    private func runQRLogin() async {
        do {
            let key = try await client.qrKey()
            guard !Task.isCancelled else { return }
            qrCodeImage = QRCodeRenderer.image(for: "https://music.163.com/login?codekey=\(key)")
            qrStatusText = "请使用网易云音乐 App 扫码"
            isQRLoading = false

            for _ in 0..<90 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                let status = try await client.qrStatus(key: key)
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
