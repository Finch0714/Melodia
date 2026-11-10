import Foundation
import SwiftUI

// MARK: - Podcast home

struct PodcastHomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var player: PlayerEngine

    @State private var filter: PodcastFilter = .all
    @State private var categories: [PodcastCategory] = []
    @State private var picks: [PodcastProgram] = []
    @State private var groups: [PodcastCategoryGroup] = []
    @State private var toplist: [PodcastRadio] = []
    @State private var subscribed: [PodcastRadio] = []
    @State private var categoryRadios: [PodcastRadio] = []
    @State private var isOverviewLoading = true
    @State private var isSubscribedLoading = false
    @State private var isCategoryLoading = false
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared
    private let radioColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterBar

            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
            }

            content
        }
        .task { await loadInitial() }
        .onChange(of: filter) { value in
            Task {
                switch value {
                case .all:
                    if picks.isEmpty && groups.isEmpty && toplist.isEmpty {
                        await loadInitial()
                    }
                case .subscribed:
                    await loadSubscribed()
                case .category(let id, _):
                    await loadCategory(id)
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all, title: "全部")
                filterChip(.subscribed, title: "已订阅")
                ForEach(categories) { category in
                    filterChip(.category(category.id, category.name), title: category.name)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(_ value: PodcastFilter, title: String) -> some View {
        Button {
            filter = value
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: filter == value ? .semibold : .regular))
                .foregroundStyle(filter == value ? MelodiaTheme.background : MelodiaTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if filter == value {
                        Capsule().fill(MelodiaTheme.textPrimary)
                    } else {
                        Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch filter {
        case .all:
            overview
        case .subscribed:
            subscribedContent
        case .category(_, let name):
            categoryContent(name: name)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isOverviewLoading && picks.isEmpty && groups.isEmpty && toplist.isEmpty {
                ProgressView()
                    .tint(MelodiaTheme.accentSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            }

            if !subscribed.isEmpty {
                sectionHeading("我的订阅")
                radioShelf(subscribed)
            }

            if !picks.isEmpty {
                sectionHeading("今日优选")
                ForEach(Array(picks.prefix(8).enumerated()), id: \.element.id) { index, program in
                    Button {
                        let list = Array(picks.prefix(8))
                        guard list.indices.contains(index) else { return }
                        play(program, queue: list)
                    } label: {
                        PodcastProgramRow(program: program)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
            }

            ForEach(groups) { group in
                sectionHeading(group.categoryName) {
                    filter = .category(group.categoryId, group.categoryName)
                }
                radioShelf(group.radios)
            }

            if !toplist.isEmpty {
                sectionHeading("热门电台榜")
                radioShelf(toplist, showRank: true)
            }

            if !isOverviewLoading && picks.isEmpty && groups.isEmpty && toplist.isEmpty && subscribed.isEmpty {
                Text("播客内容暂时没有加载出来")
                    .font(.system(size: 12))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
            }
        }
        .padding(.bottom, 8)
    }

    private var subscribedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !appModel.isLoggedIn {
                VStack(spacing: 14) {
                    Text("登录后查看你订阅的电台")
                        .font(.system(size: 13))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                    NavigationLink {
                        AccountView()
                    } label: {
                        Text("去登录")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(MelodiaTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else if isSubscribedLoading && subscribed.isEmpty {
                ProgressView()
                    .tint(MelodiaTheme.accentSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else if subscribed.isEmpty {
                EmptyStateView(icon: "headphones", title: "还没有订阅的电台", message: "在电台详情页点「订阅」，更新会出现在这里")
            } else {
                sectionHeading("我的订阅")
                LazyVGrid(columns: radioColumns, alignment: .leading, spacing: 14) {
                    ForEach(subscribed) { radio in
                        radioLink(radio)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
    }

    private func categoryContent(name: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCategoryLoading && categoryRadios.isEmpty {
                ProgressView()
                    .tint(MelodiaTheme.accentSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else if categoryRadios.isEmpty {
                Text("这个分类暂时没有电台")
                    .font(.system(size: 12))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                sectionHeading("热门电台")
                LazyVGrid(columns: radioColumns, alignment: .leading, spacing: 14) {
                    ForEach(categoryRadios) { radio in
                        radioLink(radio)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
    }

    private func sectionHeading(_ title: String, more: (() -> Void)? = nil) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MelodiaTheme.textPrimary)
            Spacer()
            if let more {
                Button(action: more) {
                    Text("全部")
                        .font(.system(size: 12))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func radioShelf(_ radios: [PodcastRadio], showRank: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(radios.enumerated()), id: \.offset) { index, radio in
                    radioLink(radio, width: 120, rank: showRank ? index + 1 : nil)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 4)
        }
    }

    private func radioLink(_ radio: PodcastRadio, width: CGFloat? = nil, rank: Int? = nil) -> some View {
        NavigationLink {
            PodcastRadioDetailView(radioID: radio.id, fallbackName: radio.name)
        } label: {
            PodcastRadioCardView(radio: radio, width: width, rank: rank)
        }
        .buttonStyle(.plain)
    }

    private func play(_ program: PodcastProgram, queue: [PodcastProgram]) {
        player.play(program.track, queue: queue.map(\.track))
    }

    private func loadInitial() async {
        isOverviewLoading = true
        errorMessage = nil
        var succeeded = false

        if let loaded = try? await client.podcastCategories() {
            categories = loaded
            succeeded = true
        }
        if let page = try? await client.podcastRecommendPrograms(limit: 8) {
            picks = page.items
            succeeded = true
        }
        if let loaded = try? await client.podcastCategoryGroups() {
            groups = loaded
            succeeded = true
        }
        if let loaded = try? await client.podcastToplistRadios(limit: 20) {
            toplist = loaded
            succeeded = true
        }
        if appModel.isLoggedIn {
            await loadSubscribed()
        }
        if !succeeded {
            errorMessage = "播客内容加载失败，请稍后重试"
        }
        isOverviewLoading = false
    }

    private func loadSubscribed() async {
        guard appModel.isLoggedIn else {
            subscribed = []
            return
        }
        isSubscribedLoading = true
        if let page = try? await client.podcastSubscribedRadios(limit: 30) {
            subscribed = page.items
        }
        isSubscribedLoading = false
    }

    private func loadCategory(_ id: Int64) async {
        isCategoryLoading = true
        categoryRadios = []
        if let page = try? await client.podcastCategoryHotRadios(categoryID: id, limit: 30) {
            categoryRadios = page.items
        }
        isCategoryLoading = false
    }
}

private enum PodcastFilter: Hashable {
    case all
    case subscribed
    case category(Int64, String)
}

// MARK: - Podcast radio detail

struct PodcastRadioDetailView: View {
    let radioID: Int64
    var fallbackName: String = ""

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var player: PlayerEngine

    @State private var detail: PodcastRadioDetail?
    @State private var programs: [PodcastProgram] = []
    @State private var ascending = false
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var isSubscribing = false
    @State private var hasMore = false
    @State private var descriptionExpanded = false
    @State private var errorMessage: String?

    private let client = NeteaseClient.shared
    private let pageSize = 30

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    ProgressView()
                        .tint(MelodiaTheme.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if let detail {
                    header(detail)

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                    }

                    HStack(alignment: .lastTextBaseline) {
                        Text("全部节目")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(MelodiaTheme.textPrimary)
                        Spacer()
                        Text("\(detail.programCount) 期")
                            .font(.system(size: 12))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    HStack(spacing: 7) {
                        sortChip("最新优先", selected: !ascending) {
                            setAscending(false)
                        }
                        sortChip("最早优先", selected: ascending) {
                            setAscending(true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)

                    ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                        Button {
                            playProgram(at: index)
                        } label: {
                            PodcastProgramRow(program: program, showSerial: true)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index >= programs.count - 3 {
                                Task { await loadMore() }
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    if isLoadingMore {
                        ProgressView()
                            .tint(MelodiaTheme.accentSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }

                    Color.clear.frame(height: 100)
                } else {
                    VStack(spacing: 14) {
                        Text(errorMessage ?? "电台加载失败")
                            .font(.system(size: 13))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                        Button("重试") {
                            Task { await load() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MelodiaTheme.accentSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 70)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(MelodiaTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ detail: PodcastRadioDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                CachedRemoteImage(
                    url: detail.coverURL?.melodiaImageURL(pixels: 500),
                    contentMode: .fill
                ) {
                    MelodiaTheme.coverPlaceholder
                }
                .frame(height: 250)
                .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.35), Color.black.opacity(0.58), MelodiaTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 250)

                VStack(spacing: 0) {
                    PodcastCover(url: detail.coverURL, pixels: 400)
                        .frame(width: 132, height: 132)
                    Text(detail.name)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.top, 12)

                    if !detail.djName.isEmpty {
                        HStack(spacing: 7) {
                            if !detail.djAvatarUrl.isEmpty {
                                CoverImage(url: URL(string: detail.djAvatarUrl), size: 20, cornerRadius: 10)
                                    .clipShape(Circle())
                            }
                            Text(detail.djName)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.82))
                        }
                        .padding(.top, 7)
                    }

                    let stats = detailStats(detail)
                    if !stats.isEmpty {
                        Text(stats)
                            .font(.system(size: 11))
                            .foregroundStyle(MelodiaTheme.textSecondary)
                            .padding(.top, 5)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }

            HStack(spacing: 10) {
                Button {
                    playPrimary()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(ascending ? "从头播放" : "播放最新一期")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(MelodiaTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(programs.isEmpty)

                Button {
                    Task { await toggleSubscribe() }
                } label: {
                    Group {
                        if isSubscribing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(detail.subscribed ? "已订阅" : "订阅")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(detail.subscribed ? Color.white.opacity(0.66) : .white)
                        }
                    }
                    .frame(width: 82, height: 40)
                    .background(
                        detail.subscribed ? Color.white.opacity(0.08) : Color.white.opacity(0.16),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(detail.subscribed ? 0.22 : 0), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSubscribing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if !detail.desc.isEmpty {
                Text(detail.desc)
                    .font(.system(size: 12))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineSpacing(5)
                    .lineLimit(descriptionExpanded ? nil : 2)
                    .padding(.horizontal, 18)
                    .contentShape(Rectangle())
                    .onTapGesture { descriptionExpanded.toggle() }

                Button(descriptionExpanded ? "收起" : "展开") {
                    descriptionExpanded.toggle()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MelodiaTheme.accentSoft)
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
    }

    private func sortChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? MelodiaTheme.background : MelodiaTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if selected {
                        Capsule().fill(MelodiaTheme.textPrimary)
                    } else {
                        Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func detailStats(_ detail: PodcastRadioDetail) -> String {
        [
            detail.category,
            detail.programCount > 0 ? "\(detail.programCount) 期" : "",
            podcastSubCountText(detail.subCount)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    private func setAscending(_ value: Bool) {
        guard ascending != value else { return }
        ascending = value
        Task { await reloadPrograms() }
    }

    private func load() async {
        isLoading = detail == nil
        errorMessage = nil
        do {
            guard let loaded = try await client.podcastRadioDetail(id: radioID) else {
                throw NeteaseError.server(404, "电台不存在")
            }
            detail = loaded
            await reloadPrograms()
        } catch {
            errorMessage = message(for: error)
        }
        isLoading = false
    }

    private func reloadPrograms() async {
        do {
            let page = try await client.podcastRadioPrograms(
                radioID: radioID,
                limit: pageSize,
                offset: 0,
                ascending: ascending
            )
            programs = page.items
            hasMore = page.hasMore
        } catch {
            programs = []
            hasMore = false
            errorMessage = message(for: error)
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        do {
            let page = try await client.podcastRadioPrograms(
                radioID: radioID,
                limit: pageSize,
                offset: programs.count,
                ascending: ascending
            )
            programs.append(contentsOf: page.items)
            hasMore = page.hasMore
        } catch {
            errorMessage = message(for: error)
            hasMore = false
        }
        isLoadingMore = false
    }

    private func playPrimary() {
        guard let first = programs.first else { return }
        player.play(first.track, queue: programs.map(\.track))
    }

    private func playProgram(at index: Int) {
        guard programs.indices.contains(index) else { return }
        player.play(programs[index].track, queue: programs.map(\.track))
    }

    private func toggleSubscribe() async {
        guard appModel.isLoggedIn else {
            errorMessage = "请先登录后再订阅电台"
            return
        }
        guard var current = detail else { return }
        isSubscribing = true
        do {
            try await client.podcastSetSubscribed(radioID: current.id, subscribe: !current.subscribed)
            current.subscribed.toggle()
            detail = current
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
        isSubscribing = false
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - Shared podcast components

private struct PodcastCover: View {
    let url: URL?
    var pixels: Int = 300

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedRemoteImage(
                    url: url?.melodiaImageURL(pixels: pixels),
                    contentMode: .fill
                ) {
                    ZStack {
                        MelodiaTheme.coverPlaceholder
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct PodcastRadioCardView: View {
    let radio: PodcastRadio
    var width: CGFloat?
    var rank: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PodcastCover(url: radio.coverURL)
                .overlay(alignment: .topLeading) {
                    if let rank {
                        Text("\(rank)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .padding(6)
                    }
                }

            Text(radio.name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(MelodiaTheme.textPrimary)
                .lineLimit(1)
                .padding(.top, 7)

            let meta = radioMetaText(radio)
            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 10.5))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct PodcastProgramRow: View {
    let program: PodcastProgram
    var showSerial: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if showSerial {
                Text(program.serialNum > 0 ? "\(program.serialNum)" : "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MelodiaTheme.textSecondary)
                    .frame(width: 26)
            }

            PodcastCover(url: URL(string: program.coverUrl), pixels: 160)
                .frame(width: showSerial ? 50 : 52, height: showSerial ? 50 : 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.system(size: showSerial ? 13 : 13.5, weight: .medium))
                    .foregroundStyle(MelodiaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !program.sourceText.isEmpty {
                    Text(program.sourceText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(MelodiaTheme.textSecondary)
                        .lineLimit(1)
                }

                let meta = programMetaText(program)
                if !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 10.5))
                        .foregroundStyle(MelodiaTheme.textSecondary.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "play.circle.fill")
                .font(.system(size: 21))
                .foregroundStyle(MelodiaTheme.textTertiary)
        }
        .padding(.vertical, showSerial ? 8 : 6)
        .contentShape(Rectangle())
    }
}

private func radioMetaText(_ radio: PodcastRadio) -> String {
    [
        radio.programCount > 0 ? "\(radio.programCount) 期" : "",
        podcastSubCountText(radio.subCount)
    ]
    .filter { !$0.isEmpty }
    .joined(separator: " · ")
}

private func programMetaText(_ program: PodcastProgram) -> String {
    [
        podcastProgramDateText(program.createTimeMs),
        podcastDurationText(program.durationMs),
        podcastListenerText(program.listenerCount)
    ]
    .filter { !$0.isEmpty }
    .joined(separator: " · ")
}

private func podcastSubCountText(_ value: Int64) -> String {
    if value <= 0 { return "" }
    if value >= 100_000_000 { return "\(value / 100_000_000) 亿订阅" }
    if value >= 10_000 { return String(format: "%.1f 万订阅", Double(value) / 10_000) }
    return "\(value) 订阅"
}

private func podcastListenerText(_ value: Int64) -> String {
    if value <= 0 { return "" }
    if value >= 100_000_000 { return "\(value / 100_000_000) 亿人听过" }
    if value >= 10_000 { return String(format: "%.1f 万人听过", Double(value) / 10_000) }
    return "\(value) 人听过"
}

private func podcastProgramDateText(_ milliseconds: Int64) -> String {
    guard milliseconds > 0 else { return "" }
    let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    let calendar = Calendar.current
    let target = calendar.dateComponents([.year, .month, .day], from: date)
    let now = calendar.dateComponents([.year], from: Date())
    guard let year = target.year, let month = target.month, let day = target.day else { return "" }
    if year == now.year {
        return String(format: "%02d-%02d", month, day)
    }
    return String(format: "%d-%02d-%02d", year, month, day)
}
