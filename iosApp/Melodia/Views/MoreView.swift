import Foundation
import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    CoverImage(url: appModel.profile?.avatarURL, size: 54, cornerRadius: 27)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appModel.profile?.nickname ?? "未登录")
                            .font(.headline)
                            .foregroundStyle(MelodiaTheme.textPrimary)
                        Text(appModel.isLoggedIn ? "网易云账号已连接" : "登录后可同步最近播放与听歌数据")
                            .font(.caption)
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("内容") {
                NavigationLink {
                    RecentPlayView()
                } label: {
                    MoreRow(
                        icon: "clock.arrow.circlepath",
                        color: Color(red: 0.36, green: 0.56, blue: 0.95),
                        title: "最近播放",
                        subtitle: "歌曲、歌单与专辑播放记录"
                    )
                }

                NavigationLink {
                    ListenDataView()
                } label: {
                    MoreRow(
                        icon: "chart.bar.xaxis",
                        color: Color(red: 0.33, green: 0.76, blue: 0.56),
                        title: "听歌数据",
                        subtitle: "累计时长、今日排行与年度报告"
                    )
                }

                NavigationLink {
                    MessageView()
                } label: {
                    MoreRow(
                        icon: "bell.badge",
                        color: Color(red: 0.95, green: 0.55, blue: 0.30),
                        title: "消息",
                        subtitle: "通知、@我 与评论回复"
                    )
                }
            }

            Section("本地") {
                NavigationLink {
                    DownloadsView()
                } label: {
                    MoreRow(
                        icon: "arrow.down.circle",
                        color: Color(red: 0.52, green: 0.45, blue: 0.92),
                        title: "下载管理",
                        subtitle: "已下载歌曲与下载任务"
                    )
                }
            }

            Section("设置") {
                NavigationLink {
                    SettingsView()
                } label: {
                    MoreRow(
                        icon: "gearshape",
                        color: Color(red: 0.55, green: 0.58, blue: 0.65),
                        title: "设置",
                        subtitle: "播放、歌词、音质与缓存"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("更多")
    }
}

private struct MoreRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(MelodiaTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RecentPlayView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var player: PlayerEngine

    @State private var tab = 0
    @State private var songs: [RecentSongRecord] = []
    @State private var playlists: [RecentPlaylistRecord] = []
    @State private var albums: [RecentAlbumRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Picker("类型", selection: $tab) {
                    Text("歌曲").tag(0)
                    Text("歌单").tag(1)
                    Text("专辑").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.vertical, 10)
                }

                if !appModel.isLoggedIn {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "需要登录",
                        message: "登录网易云账号后即可查看最近播放"
                    )
                } else if isLoading {
                    ProgressView("正在加载最近播放…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    content
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("最近播放")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case 0:
            if songs.isEmpty {
                EmptyStateView(icon: "music.note", title: "还没有歌曲播放记录", message: "")
            } else {
                ForEach(dayGroups(songs, time: \.playTime)) { group in
                    DayHeader(label: group.label)
                    ForEach(group.items.indices, id: \.self) { index in
                        let record = group.items[index]
                        RecentSongRow(record: record) {
                            player.play(record.data, queue: songs.map(\.data))
                        }
                    }
                }
            }
        case 1:
            if playlists.isEmpty {
                EmptyStateView(icon: "music.note.list", title: "还没有歌单播放记录", message: "")
            } else {
                ForEach(dayGroups(playlists, time: \.playTime)) { group in
                    DayHeader(label: group.label)
                    ForEach(group.items.indices, id: \.self) { index in
                        let record = group.items[index]
                        NavigationLink {
                            PlaylistView(
                                route: PlaylistRoute(
                                    id: record.data.id,
                                    title: record.data.name,
                                    cover: record.data.coverImgUrl
                                )
                            )
                        } label: {
                            RecentEntityRow(
                                cover: record.data.coverImgUrl,
                                title: record.data.name,
                                subtitle: [record.data.creator?.nickname ?? "", playTimeText(record.playTime)]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · ")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        default:
            if albums.isEmpty {
                EmptyStateView(icon: "square.stack", title: "还没有专辑播放记录", message: "")
            } else {
                ForEach(dayGroups(albums, time: \.playTime)) { group in
                    DayHeader(label: group.label)
                    ForEach(group.items.indices, id: \.self) { index in
                        let record = group.items[index]
                        NavigationLink {
                            AlbumView(
                                route: AlbumRoute(
                                    id: record.data.id,
                                    title: record.data.name,
                                    cover: record.data.picUrl
                                )
                            )
                        } label: {
                            RecentEntityRow(
                                cover: record.data.picUrl,
                                title: record.data.name,
                                subtitle: [record.data.artist?.name ?? "", playTimeText(record.playTime)]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · ")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func load() async {
        guard appModel.isLoggedIn else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            songs = try await NeteaseClient.shared.recentSongs()
        } catch {
            errorMessage = friendly(error)
        }
        do {
            playlists = try await NeteaseClient.shared.recentPlaylists()
        } catch {
            if errorMessage == nil { errorMessage = friendly(error) }
        }
        do {
            albums = try await NeteaseClient.shared.recentAlbums()
        } catch {
            if errorMessage == nil { errorMessage = friendly(error) }
        }
        isLoading = false
    }
}

private struct RecentSongRow: View {
    let record: RecentSongRecord
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                CoverImage(url: record.data.coverURL, size: 48, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.data.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .lineLimit(1)
                    Text(record.data.artistText)
                        .font(.system(size: 12))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(playTimeText(record.playTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MelodiaTheme.textTertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RecentEntityRow: View {
    let cover: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(url: URL(string: cover), size: 48, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MelodiaTheme.textTertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct DayHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(MelodiaTheme.textPrimary)
            .padding(.top, 18)
            .padding(.bottom, 4)
    }
}

private struct DayGroup<Item>: Identifiable {
    let label: String
    let items: [Item]
    var id: String { label }
}

private func dayGroups<Item>(_ items: [Item], time: KeyPath<Item, Int64>) -> [DayGroup<Item>] {
    var order: [String] = []
    var values: [String: [Item]] = [:]
    for item in items {
        let label = dayLabel(item[keyPath: time])
        if values[label] == nil {
            order.append(label)
            values[label] = []
        }
        values[label]?.append(item)
    }
    return order.map { DayGroup(label: $0, items: values[$0] ?? []) }
}

private func dayLabel(_ milliseconds: Int64) -> String {
    guard milliseconds > 0 else { return "更早" }
    let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    if Calendar.current.isDateInToday(date) { return "今天" }
    if Calendar.current.isDateInYesterday(date) { return "昨天" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter.string(from: date)
}

private func playTimeText(_ milliseconds: Int64) -> String {
    guard milliseconds > 0 else { return "" }
    let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func friendly(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}
struct MessageView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var tab = 0
    @State private var notices: [MessageNoticeItem] = []
    @State private var forwards: [MessageForwardDisplay] = []
    @State private var comments: [MessageCommentItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Picker("消息类型", selection: $tab) {
                    Text("通知").tag(0)
                    Text("@我").tag(1)
                    Text("评论").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 10)

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if !appModel.isLoggedIn {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "需要登录",
                        message: "登录网易云账号后即可查看消息"
                    )
                } else if isLoading {
                    ProgressView("正在加载消息…")
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    content
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case 0:
            if notices.isEmpty {
                EmptyStateView(icon: "bell", title: "还没有通知", message: "")
            } else {
                ForEach(notices) { item in
                    MessageRow(
                        avatar: nil,
                        title: "通知",
                        message: item.displayText,
                        time: item.time
                    )
                    Divider().overlay(MelodiaTheme.divider)
                }
            }
        case 1:
            if forwards.isEmpty {
                EmptyStateView(icon: "at", title: "还没有 @ 我的消息", message: "")
            } else {
                ForEach(forwards) { item in
                    MessageRow(
                        avatar: item.avatarURL,
                        title: item.nickname.isEmpty ? "有人 @ 你" : item.nickname,
                        message: item.content.isEmpty ? "在动态中 @ 了你" : item.content,
                        time: item.time
                    )
                    Divider().overlay(MelodiaTheme.divider)
                }
            }
        default:
            if comments.isEmpty {
                EmptyStateView(icon: "bubble.left.and.bubble.right", title: "还没有评论回复", message: "")
            } else {
                ForEach(comments) { item in
                    MessageRow(
                        avatar: item.user.avatarUrl,
                        title: item.user.nickname,
                        message: [item.content, item.beRepliedContent.map { "原评论：\($0)" }]
                            .compactMap { $0 }
                            .joined(separator: "\n"),
                        time: item.time,
                        footnote: item.resourceName.map { "来自《\($0)》" }
                    )
                    Divider().overlay(MelodiaTheme.divider)
                }
            }
        }
    }

    private func load() async {
        guard appModel.isLoggedIn else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        async let noticeRequest = try? client.messageNotices()
        async let forwardRequest = try? client.messageForwards()

        notices = (await noticeRequest)?.notices ?? []
        forwards = ((await forwardRequest)?.forwards ?? []).enumerated().map { index, raw in
            MessageForwardDisplay(
                id: Int64(index),
                nickname: raw.user?.nickname ?? "",
                avatarURL: raw.user?.avatarUrl ?? "",
                content: forwardText(raw),
                time: raw.eventTime ?? raw.time ?? 0
            )
        }

        if let uid = appModel.profile?.userId {
            comments = (try? await client.messageComments(uid: uid))?.comments ?? []
        } else {
            comments = []
        }
        isLoading = false
    }

    private func forwardText(_ raw: MessageForwardRaw) -> String {
        if let json = raw.json, let data = json.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let value = object["msg"] as? String, !value.isEmpty { return value }
            if let value = object["content"] as? String, !value.isEmpty { return value }
        }
        return raw.msg ?? raw.content ?? ""
    }
}

private struct MessageRow: View {
    let avatar: String?
    let title: String
    let message: String
    let time: Int64
    var footnote: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoverImage(url: avatar.flatMap { URL(string: $0) }, size: 38, cornerRadius: 19)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(relativeTimeText(time))
                        .font(.system(size: 10))
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let footnote {
                    Text(footnote)
                        .font(.system(size: 10))
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 11)
    }
}

struct DownloadsView: View {
    @EnvironmentObject private var player: PlayerEngine
    @ObservedObject private var manager = DownloadManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if !manager.activeSongIDs.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(MelodiaTheme.accentSoft)
                        Text("正在下载 \(manager.activeSongIDs.count) 首歌曲")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(MelodiaTheme.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let error = manager.lastErrorMessage {
                    ErrorBanner(message: error)
                }

                if manager.records.isEmpty {
                    EmptyStateView(
                        icon: "arrow.down.circle",
                        title: "还没有下载过歌曲",
                        message: "在播放页的更多菜单里选择下载"
                    )
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("已下载的歌曲")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(MelodiaTheme.textPrimary)
                            Text("\(manager.records.count) 首 · \(sizeText(manager.totalBytes))")
                                .font(.system(size: 11))
                                .foregroundStyle(MelodiaTheme.textTertiary)
                        }
                        Spacer()
                        Button {
                            player.playAll(manager.records.map(\.track))
                        } label: {
                            Label("播放全部", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(MelodiaTheme.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)

                    ForEach(manager.records) { record in
                        HStack(spacing: 12) {
                            Button {
                                player.play(record.track, queue: manager.records.map(\.track))
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: URL(string: record.coverURL), size: 48, cornerRadius: 9)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(MelodiaTheme.textPrimary)
                                            .lineLimit(1)
                                        HStack(spacing: 6) {
                                            Text(record.quality)
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(MelodiaTheme.textSecondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(MelodiaTheme.textTertiary, lineWidth: 1)
                                                )
                                            Text([record.artist, record.sizeText].filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.system(size: 11))
                                                .foregroundStyle(MelodiaTheme.textTertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 6)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                manager.remove(record)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(MelodiaTheme.textTertiary)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除下载")
                        }
                        .padding(.vertical, 6)
                        Divider().overlay(MelodiaTheme.divider)
                    }
                }

                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("下载管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func durationText(_ seconds: Int64) -> String {
    guard seconds > 0 else { return "0 分钟" }
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return "\(hours) 小时 \(minutes) 分钟"
    }
    return "\(minutes) 分钟"
}

private func sizeText(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 MB" }
    if bytes >= 1024 * 1024 * 1024 {
        return String(format: "%.2f GB", Double(bytes) / 1024 / 1024 / 1024)
    }
    return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
}

private func relativeTimeText(_ timestamp: Int64) -> String {
    guard timestamp > 0 else { return "" }
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}