import Foundation
import SwiftUI

private enum ListenTab: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "今日"
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "年度"
        }
    }

    var apiType: String? {
        switch self {
        case .week: return "week"
        case .month: return "month"
        case .today, .year: return nil
        }
    }
}

struct ListenDataView: View {
    @EnvironmentObject private var player: PlayerEngine

    @State private var selectedTab: ListenTab = .week
    @State private var totalSeconds: Int64 = 0
    @State private var todaySongs: [ListenTodaySong] = []
    @State private var reports: [ListenTab: ListenReport] = [:]
    @State private var ranks: [ListenTab: ListenRankData] = [:]
    @State private var years: [ListenYearItem] = []
    @State private var loadedTabs: Set<ListenTab> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }

                    if isLoading {
                        ProgressView("正在加载听歌数据…")
                            .tint(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 56)
                    } else {
                        content
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
            .refreshable { await reload(selectedTab) }
        }
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("听歌数据")
        .navigationBarTitleDisplayMode(.inline)
        .task { await initialLoad() }
        .onChange(of: selectedTab) { tab in
            Task { await loadTab(tab) }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(ListenTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.label)
                            .font(.system(size: 12.5, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? MelodiaTheme.background : MelodiaTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                if selectedTab == tab {
                                    Capsule().fill(MelodiaTheme.textPrimary)
                                } else {
                                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(MelodiaTheme.background)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .today:
            todayContent
        case .week, .month:
            periodContent
        case .year:
            yearContent
        }
    }

    private var todayContent: some View {
        Group {
            if todaySongs.isEmpty {
                EmptyStateView(icon: "chart.bar.xaxis", title: "今天还没有收听记录", message: "听几首歌之后再回来看看")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日播放")
                            .font(.system(size: 12))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                        Text("\(todaySongs.count) 首")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    ForEach(Array(todaySongs.enumerated()), id: \.element.songId) { index, song in
                        ListenRankRow(
                            number: index + 1,
                            title: song.songName,
                            artist: song.artistText,
                            cover: song.picUrl,
                            trailing: "",
                            isActive: player.currentTrack?.id == song.songId,
                            isPlaying: player.isPlaying
                        ) {
                            play(trackFor(song), queue: todaySongs.map(trackFor))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var periodContent: some View {
        if let report = reports[selectedTab] {
            ListenPeriodContent(
                tab: selectedTab,
                report: report,
                rank: ranks[selectedTab] ?? .empty,
                totalSeconds: totalSeconds,
                player: player
            )
            .id(selectedTab)
        } else if let rank = ranks[selectedTab], !rank.songItems.isEmpty {
            ListenRankContent(tab: selectedTab, rank: rank, player: player)
        } else {
            EmptyStateView(icon: "chart.bar.xaxis", title: "这个周期还没有听歌记录", message: "多听几首歌再来看看")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
        }
    }

    private var yearContent: some View {
        Group {
            if years.isEmpty {
                EmptyStateView(icon: "chart.bar.xaxis", title: "还没有历年收听记录", message: "")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else {
                ListenYearStats(items: years)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func initialLoad() async {
        if totalSeconds == 0 {
            totalSeconds = (try? await client.listenTotalDuration()) ?? 0
        }
        await loadTab(selectedTab)
    }

    private func reload(_ tab: ListenTab) async {
        totalSeconds = (try? await client.listenTotalDuration()) ?? totalSeconds
        loadedTabs.remove(tab)
        reports[tab] = nil
        ranks[tab] = nil
        await loadTab(tab)
    }

    private func loadTab(_ tab: ListenTab) async {
        guard !loadedTabs.contains(tab) else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil

        switch tab {
        case .today:
            do {
                let songs = try await client.listenTodaySongs()
                guard selectedTab == tab else { return }
                todaySongs = songs
                loadedTabs.insert(tab)
            } catch {
                if selectedTab == tab { errorMessage = friendly(error) }
            }

        case .week, .month:
            guard let type = tab.apiType else { return }
            async let reportTask = try? client.listenReport(type: type)
            async let rankTask = try? client.listenSongRank(type: type)
            let report = await reportTask
            let rank = await rankTask
            guard selectedTab == tab else { return }
            if let report { reports[tab] = report }
            if let rank { ranks[tab] = rank }
            if report == nil && rank == nil {
                errorMessage = "加载失败，请稍后重试"
            } else {
                loadedTabs.insert(tab)
            }

        case .year:
            do {
                let items = try await client.listenYearReport()
                guard selectedTab == tab else { return }
                years = items
                loadedTabs.insert(tab)
            } catch {
                if selectedTab == tab { errorMessage = friendly(error) }
            }
        }

        if selectedTab == tab { isLoading = false }
    }

    private func play(_ track: Track, queue: [Track]) {
        player.play(track, queue: queue)
    }

    private func trackFor(_ song: ListenTodaySong) -> Track {
        Track(
            id: song.songId,
            name: song.songName,
            artists: [Artist(id: 0, name: song.artistText)],
            album: Album(id: 0, name: "", picUrl: song.picUrl)
        )
    }

    private func friendly(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - Week / month
private struct ListenPeriodContent: View {
    let tab: ListenTab
    let report: ListenReport
    let rank: ListenRankData
    let totalSeconds: Int64
    let player: PlayerEngine

    @State private var expanded = false
    @State private var selectedDay: Int?
    @State private var selectedPeriod: Int?

    private var visibleSongs: [ListenRankSong] {
        expanded ? rank.songItems : Array(rank.songItems.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero

            if !report.highlights.isEmpty {
                sectionTitle("\(tab.label)亮点")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(report.highlights) { highlight in
                            Button {
                                playHighlight(highlight)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    CoverImage(url: URL(string: highlight.coverUrl), size: 52, cornerRadius: 10)
                                    Text(highlight.label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(MelodiaTheme.accentSoft)
                                        .lineLimit(1)
                                        .padding(.top, 10)
                                    Text(highlight.songName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 2)
                                    if !highlight.valueText.isEmpty {
                                        Text(highlight.valueText)
                                            .font(.system(size: 11))
                                            .foregroundStyle(MelodiaTheme.textSecondary)
                                            .lineLimit(1)
                                            .padding(.top, 2)
                                    }
                                }
                                .frame(width: 108, alignment: .leading)
                                .padding(12)
                                .background(listenCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !report.dailyDurations.isEmpty {
                ListenDailyChart(days: report.dailyDurations, selected: $selectedDay)
            }

            if !report.timePeriods.isEmpty {
                ListenPeriodChart(periods: report.timePeriods, selected: $selectedPeriod)
            }

            if !rank.songItems.isEmpty {
                sectionTitle("最常听", trailing: "共 \(rank.songCount) 首")
                ForEach(Array(visibleSongs.enumerated()), id: \.element.songId) { index, song in
                    ListenRankRow(
                        number: index + 1,
                        title: song.songName,
                        artist: song.artistText,
                        cover: song.picUrl,
                        trailing: "\(song.playCount)次",
                        isActive: player.currentTrack?.id == song.songId,
                        isPlaying: player.isPlaying
                    ) {
                        playRank(at: index)
                    }
                }
                if rank.songItems.count > 5 {
                    Button {
                        expanded.toggle()
                    } label: {
                        Text(expanded ? "收起" : "展开全部 \(rank.songItems.count) 首")
                            .font(.system(size: 13))
                            .foregroundStyle(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !report.topArtists.isEmpty {
                sectionTitle("最常听的歌手")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(report.topArtists) { artist in
                            NavigationLink {
                                ArtistView(route: ArtistRoute(id: artist.id, title: artist.name, avatar: artist.coverUrl))
                            } label: {
                                VStack(spacing: 3) {
                                    CoverImage(url: URL(string: artist.coverUrl), size: 56, cornerRadius: 28)
                                        .clipShape(Circle())
                                    Text(artist.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(MelodiaTheme.textPrimary)
                                        .lineLimit(1)
                                        .frame(width: 64)
                                    Text(artist.countText)
                                        .font(.system(size: 10))
                                        .foregroundStyle(MelodiaTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 64, alignment: .top)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            let preference = [("曲风", report.genreName), ("年代", report.ageLabel), ("语种", report.languageName)]
                .filter { !$0.1.isEmpty }
            if !preference.isEmpty {
                sectionTitle("听歌偏好")
                HStack(spacing: 8) {
                    ForEach(Array(preference.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 2) {
                            Text(item.0)
                                .font(.system(size: 10))
                                .foregroundStyle(MelodiaTheme.textSecondary)
                            Text(item.1)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(MelodiaTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(listenCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            let vip = report.vipItems.first
            if report.podcastMinutes > 0 || report.podcastEpisodes > 0 || !(vip?.mainText.isEmpty ?? true) {
                HStack(spacing: 8) {
                    if report.podcastMinutes > 0 || report.podcastEpisodes > 0 {
                        ListenStatCard(
                            icon: "mic",
                            label: "播客",
                            value: "\(report.podcastMinutes)",
                            unit: "分钟",
                            caption: "\(report.podcastEpisodes) 期节目"
                        )
                    }
                    if let vip, !vip.mainText.isEmpty {
                        let digits = vip.mainText.filter(\.isNumber)
                        ListenStatCard(
                            icon: "crown",
                            label: "会员畅听",
                            value: digits.isEmpty ? "0" : digits,
                            unit: vip.mainText.filter { !$0.isNumber }.isEmpty ? "首" : vip.mainText.filter { !$0.isNumber },
                            caption: vip.subText
                        )
                    }
                }
                .padding(.top, 12)
            }

            ListenFriendsSection(friends: report.friendsListening, keywords: report.friendKeywords)
        }
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                if !report.wallpaperUrls.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(report.wallpaperUrls.prefix(6).enumerated()), id: \.offset) { _, url in
                            CachedRemoteImage(url: URL(string: url)?.melodiaImageURL(pixels: 220), contentMode: .fill) {
                                MelodiaTheme.surface
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        }
                    }
                    .frame(height: 244)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: MelodiaTheme.background.opacity(0.95), location: 0),
                                .init(color: MelodiaTheme.background.opacity(0.86), location: 0.35),
                                .init(color: MelodiaTheme.background.opacity(0.93), location: 0.8),
                                .init(color: MelodiaTheme.background, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        Text("\(tab.label)收听")
                        if report.songCount > 0 {
                            Text(" · 听过 \(report.songCount) 首")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(MelodiaTheme.textSecondary)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(report.playMinutes)")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                        Text("分钟")
                            .font(.system(size: 13))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .padding(.bottom, 7)
                    }
                    .padding(.top, 2)

                    if !report.beyondPercentText.isEmpty {
                        let percent = Int(report.beyondPercentText.filter(\.isNumber)) ?? 0
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(MelodiaTheme.accent)
                                    .frame(width: proxy.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 10)
                        Text(report.beyondPercentText)
                            .font(.system(size: 11))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .padding(.top, 5)
                    }
                }
                .padding(.vertical, 18)
            }

            if !report.achievementTitle.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(MelodiaTheme.accentSoft)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(report.achievementTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                        if !report.achievementSubtitle.isEmpty {
                            Text(report.achievementSubtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(MelodiaTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(MelodiaTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 12)
            }

            HStack(spacing: 8) {
                ListenStatCard(icon: nil, label: "听歌天数", value: "\(report.listenDays)", unit: "天", caption: nil)
                ListenStatCard(icon: nil, label: "累计收听", value: "\(totalSeconds / 3600)", unit: "小时", caption: nil)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func sectionTitle(_ title: String, trailing: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MelodiaTheme.textPrimary)
            Spacer()
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundStyle(MelodiaTheme.textSecondary)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func playRank(at index: Int) {
        guard rank.songItems.indices.contains(index) else { return }
        let queue = rank.songItems.map(trackFor)
        player.play(queue[index], queue: queue)
    }

    private func playHighlight(_ highlight: ListenHighlight) {
        if let index = rank.songItems.firstIndex(where: { $0.songId == highlight.songId }) {
            playRank(at: index)
            return
        }
        let track = Track(
            id: highlight.songId,
            name: highlight.songName,
            artists: [],
            album: Album(id: 0, name: "", picUrl: highlight.coverUrl)
        )
        player.play(track, queue: [track])
    }

    private func trackFor(_ song: ListenRankSong) -> Track {
        Track(
            id: song.songId,
            name: song.songName,
            artists: [Artist(id: 0, name: song.artistText)],
            album: Album(id: 0, name: song.albumName, picUrl: song.picUrl)
        )
    }
}

private struct ListenRankContent: View {
    let tab: ListenTab
    let rank: ListenRankData
    let player: PlayerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("最常听")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 18)
            ForEach(Array(rank.songItems.enumerated()), id: \.element.songId) { index, song in
                ListenRankRow(
                    number: index + 1,
                    title: song.songName,
                    artist: song.artistText,
                    cover: song.picUrl,
                    trailing: "\(song.playCount)次",
                    isActive: player.currentTrack?.id == song.songId,
                    isPlaying: player.isPlaying
                ) {
                    let queue = rank.songItems.map(trackFor)
                    player.play(queue[index], queue: queue)
                }
            }
        }
    }

    private func trackFor(_ song: ListenRankSong) -> Track {
        Track(
            id: song.songId,
            name: song.songName,
            artists: [Artist(id: 0, name: song.artistText)],
            album: Album(id: 0, name: song.albumName, picUrl: song.picUrl)
        )
    }
}

// MARK: - Shared rows and sections

private let listenCard = Color.white.opacity(0.06)

// MARK: - Shared rows and sections

private struct ListenRankRow: View {
    let number: Int
    let title: String
    let artist: String
    let cover: String
    let trailing: String
    let isActive: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(number <= 3 ? MelodiaTheme.accentSoft : MelodiaTheme.textTertiary)
                    .frame(width: 24)

                CoverImage(url: URL(string: cover), size: 44, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isActive ? MelodiaTheme.accentSoft : MelodiaTheme.textPrimary)
                        .lineLimit(1)
                    Text(artist.isEmpty ? "未知歌手" : artist)
                        .font(.system(size: 11))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if !trailing.isEmpty {
                    Text(trailing)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(MelodiaTheme.textTertiary)
                }
                if isActive {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.accentSoft)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ListenStatCard: View {
    let icon: String?
    let label: String
    let value: String
    let unit: String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(MelodiaTheme.textSecondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .padding(.bottom, 2)
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(listenCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ListenDailyChart: View {
    let days: [ListenDayDuration]
    @Binding var selected: Int?

    private var maxMinutes: Int { max(days.map(\.minutes).max() ?? 1, 1) }
    private var selectedDay: ListenDayDuration? {
        guard let selected, days.indices.contains(selected) else { return nil }
        return days[selected]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("每日时长")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Spacer()
                if let selectedDay {
                    Text("\(selectedDay.fullLabel) · \(selectedDay.minutes) 分钟")
                        .font(.system(size: 12))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)

            HStack(alignment: .bottom, spacing: days.count > 10 ? 2 : 6) {
                ForEach(Array(days.enumerated()), id: \.element.index) { index, day in
                    let isSelected = selected == index
                    let isPeak = day.minutes == maxMinutes
                    Button {
                        selected = isSelected ? nil : index
                    } label: {
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(isSelected || (selected == nil && isPeak) ? MelodiaTheme.accent : MelodiaTheme.accent.opacity(0.62))
                                .frame(height: max(3, 72 * CGFloat(day.minutes) / CGFloat(maxMinutes)))
                            Text(day.label)
                                .font(.system(size: 10))
                                .foregroundStyle(isSelected ? MelodiaTheme.textPrimary : MelodiaTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(height: 14)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 96, alignment: .bottom)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 2)
        }
    }
}

private struct ListenPeriodChart: View {
    let periods: [ListenTimePeriod]
    @Binding var selected: Int?

    private var sorted: [ListenTimePeriod] {
        periods.sorted { $0.minutes > $1.minutes }
    }
    private var maxMinutes: Int { max(sorted.first?.minutes ?? 1, 1) }
    private var totalMinutes: Int { sorted.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("时段偏好")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                Spacer()
                if let selected, sorted.indices.contains(selected) {
                    let item = sorted[selected]
                    Text(totalMinutes > 0 ? "\(item.label)占 \(item.minutes * 100 / totalMinutes)%" : item.label)
                        .font(.system(size: 12))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, period in
                let isSelected = selected == index
                Button {
                    selected = isSelected ? nil : index
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: periodIcon(period.key))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .frame(width: 15)

                        Text(period.label)
                            .font(.system(size: 12))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .frame(width: 32, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                if period.minutes > 0 {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(barColor(isSelected: isSelected, minutes: period.minutes))
                                        .frame(width: proxy.size.width * CGFloat(period.minutes) / CGFloat(maxMinutes))
                                }
                            }
                        }
                        .frame(height: 14)

                        Text("\(period.minutes)分")
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected || (selected == nil && period.minutes == maxMinutes) ? MelodiaTheme.textPrimary : MelodiaTheme.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func barColor(isSelected: Bool, minutes: Int) -> Color {
        if isSelected { return MelodiaTheme.accent }
        if selected != nil { return MelodiaTheme.accent.opacity(0.3) }
        return minutes == maxMinutes ? MelodiaTheme.accent : MelodiaTheme.accent.opacity(0.7)
    }

    private func periodIcon(_ key: String) -> String {
        switch key {
        case "early_morning": return "moon.zzz.fill"
        case "morning": return "sun.max.fill"
        case "noon": return "sun.max.circle.fill"
        case "afternoon": return "sunset.fill"
        case "night": return "moon.stars.fill"
        case "deep_night": return "moon.fill"
        default: return "clock.fill"
        }
    }
}

private struct ListenFriendsSection: View {
    let friends: [ListenFriend]
    let keywords: [String]

    var body: some View {
        if !friends.isEmpty || !keywords.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("好友在听")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                if !friends.isEmpty {
                    ForEach(friends) { friend in
                        HStack(spacing: 10) {
                            CoverImage(url: URL(string: friend.avatarUrl), size: 36, cornerRadius: 18)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.username)
                                    .font(.system(size: 13))
                                    .foregroundStyle(MelodiaTheme.textPrimary)
                                    .lineLimit(1)
                                Text(friend.playCount > 0 ? "\(friend.songName) · 听了 \(friend.playCount) 次" : friend.songName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(MelodiaTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 5)
                    }
                }

                if !keywords.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(keywords.prefix(3).enumerated()), id: \.offset) { _, keyword in
                            Text(keyword)
                                .font(.system(size: 11))
                                .foregroundStyle(MelodiaTheme.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct ListenYearStats: View {
    let items: [ListenYearItem]

    private var maxDuration: Int64 {
        max(items.map(\.playDuration).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("历年收听")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ForEach(items) { item in
                VStack(spacing: 0) {
                    HStack {
                        Text("\(item.year)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                        Spacer()
                        Text("\(item.playNum) 首 · \(listenHoursText(item.playDuration)) 小时")
                            .font(.system(size: 11))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(MelodiaTheme.accent)
                                .frame(width: proxy.size.width * CGFloat(item.playDuration) / CGFloat(maxDuration))
                        }
                    }
                    .frame(height: 7)
                    .padding(.top, 6)
                }
                .padding(.vertical, 7)
            }
        }
    }
}