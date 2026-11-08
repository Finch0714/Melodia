import Foundation
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var cookieText = ""
    @State private var showCookieLogin = false
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if appModel.isLoggedIn {
                        profileSection
                    } else {
                        loginSection
                    }

                    if let loginError = appModel.loginError {
                        ErrorBanner(message: loginError)
                    }

                    Text("本应用仅用于个人学习与技术交流。音乐、封面及歌词版权归网易云音乐及原权利人所有。")
                        .font(.caption2)
                        .foregroundStyle(MelodiaTheme.textTertiary)
                        .lineSpacing(3)
                        .padding(.top, 8)

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .background(MelodiaTheme.background.ignoresSafeArea())
            .navigationTitle("我的")
            .task {
                if !appModel.isLoggedIn && appModel.qrCodeImage == nil {
                    appModel.startQRLogin()
                }
            }
            .alert("退出登录？", isPresented: $showLogoutConfirm) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    Task { await appModel.logout() }
                }
            } message: {
                Text("本地保存的登录 Cookie 会被清除")
            }
        }
    }

    private var profileSection: some View {
        VStack(spacing: 16) {
            avatar

            VStack(spacing: 5) {
                Text(appModel.profile?.nickname.isEmpty == false ? appModel.profile!.nickname : "网易云用户")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)

                if let signature = appModel.profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(.footnote)
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                if let profile = appModel.profile {
                    Text("UID \(profile.userId)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(MelodiaTheme.textTertiary)
                        .padding(.top, 3)
                }
            }

            Divider().overlay(MelodiaTheme.divider)

            HStack(spacing: 12) {
                Button {
                    Task { await appModel.refreshSession() }
                } label: {
                    Label("刷新资料", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MelodiaTheme.surfaceLight, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showLogoutConfirm = true
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MelodiaTheme.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .melodiaCard(radius: 24)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = appModel.profile?.avatarURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 82, height: 82)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [MelodiaTheme.accent.opacity(0.75), MelodiaTheme.surfaceLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 82, height: 82)
        .clipShape(Circle())
    }

    private var loginSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 7) {
                Text("登录网易云音乐")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Text("扫码或导入 Cookie，解锁每日推荐与完整播放权限")
                    .font(.footnote)
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            qrPanel

            Text(appModel.qrStatusText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(MelodiaTheme.textSecondary)

            if !appModel.isQRLoading {
                Button {
                    appModel.startQRLogin()
                } label: {
                    Label("刷新二维码", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(MelodiaTheme.surfaceLight, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(MelodiaTheme.divider)
            cookieLoginSection
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .melodiaCard(radius: 24)
    }

    @ViewBuilder
    private var qrPanel: some View {
        if let image = appModel.qrCodeImage {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 205, height: 205)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else if appModel.isQRLoading {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MelodiaTheme.surface)
                    .frame(width: 229, height: 229)
                ProgressView()
                    .tint(MelodiaTheme.accentSoft)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MelodiaTheme.surface)
                    .frame(width: 229, height: 229)
                VStack(spacing: 10) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 50, weight: .light))
                    Text("二维码未生成")
                        .font(.caption)
                }
                .foregroundStyle(MelodiaTheme.textTertiary)
            }
        }
    }

    private var cookieLoginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCookieLogin.toggle()
                }
            } label: {
                HStack {
                    Label("使用 Cookie 登录", systemImage: "key.horizontal")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Image(systemName: showCookieLogin ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(MelodiaTheme.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showCookieLogin {
                Text("在浏览器登录 music.163.com 后复制 Cookie。内容需包含 MUSIC_U。")
                    .font(.caption)
                    .foregroundStyle(MelodiaTheme.textTertiary)

                TextEditor(text: $cookieText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 96)
                    .background(MelodiaTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    Task {
                        await appModel.importCookie(cookieText)
                    }
                } label: {
                    Text("导入 Cookie")
                        .font(.footnote.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(MelodiaTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
