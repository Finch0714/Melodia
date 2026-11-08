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
                        quickActions
                        playlistsSection
                    } else {
                        loginSection
                    }

                    if let loginError = appModel.loginError {
                        ErrorBanner(message: loginError)
                    }
                    if let libraryError = appModel.libraryError {
                        ErrorBanner(message: libraryError)
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
                if appModel.isLoggedIn {
                    await appModel.loadLibrary()
                } else if appModel.qrCodeImage == nil {
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

            HStack(spacing: 0) {
                statItem(value: "\(appModel.libraryPlaylists.count)", label: "歌单")
                Divider().frame(height: 28).overlay(MelodiaTheme.divider)
                statItem(value: "\(appModel.libraryAlbums.count)", label: "收藏专辑")
                Divider().frame(height: 28).overlay(MelodiaTheme.divider)
                statItem(value: "\(appModel.likedSongIDs.count)", label: "喜欢")
            }

            Divider().overlay(MelodiaTheme.divider)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await appModel.refreshSession()
                        await appModel.loadLibrary(force: true)
                        await appModel.loadHome()
                    }
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

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "我的音乐", subtitle: "资料、收藏和听歌记录")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NavigationLink {
                    LikedSongsView()
                } label: {
                    quickCard(icon: "heart.fill", title: "我喜欢的音乐", subtitle: "\(appModel.likedSongIDs.count) 首")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AlbumShelfView()
                } label: {
                    quickCard(icon: "square.stack.fill", title: "收藏专辑", subtitle: "\(appModel.libraryAlbums.count) 张")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ListeningRankView()
                } label: {
                    quickCard(icon: "chart.bar.fill", title: "听歌排行", subtitle: "本周与全部")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    UserPlaylistsView()
                } label: {
                    quickCard(icon: "music.note.list", title: "我的歌单", subtitle: "\(appModel.libraryPlaylists.count) 个")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "最近歌单")
                Spacer()
                NavigationLink {
                    UserPlaylistsView()
                } label: {
                    Text("查看全部")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MelodiaTheme.accentSoft)
                }
                .buttonStyle(.plain)
            }

            if appModel.isLoadingLibrary && appModel.libraryPlaylists.isEmpty {
                LoadingCards()
            } else if appModel.libraryPlaylists.isEmpty {
                EmptyStateView(icon: "music.note.list", title: "还没有歌单", message: "登录后创建或收藏歌单")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(appModel.libraryPlaylists.prefix(12))) { playlist in
                            NavigationLink(value: PlaylistRoute(userPlaylist: playlist)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverImage(url: playlist.coverURL, size: 138, cornerRadius: 18)
                                    Text(playlist.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                        .frame(width: 138, alignment: .leading)
                                    Text("\(playlist.trackCount) 首")
                                        .font(.caption)
                                        .foregroundStyle(MelodiaTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
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
                Text("已使用桌面客户端登录协议，扫码或导入 Cookie 登录")
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
                Text("在浏览器登录 music.163.com 后复制 Cookie。内容需包含 MUSIC_U；这是扫码失败时最稳定的登录方式。")
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

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(MelodiaTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(MelodiaTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MelodiaTheme.accentSoft)
                .frame(width: 38, height: 38)
                .background(MelodiaTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(MelodiaTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .melodiaCard(radius: 16)
    }
}