import Foundation

// MARK: - Listening report domain

struct ListenReport {
    let playMinutes: Int
    let beyondPercentText: String
    let achievementTitle: String
    let achievementSubtitle: String
    let listenDays: Int
    let wallpaperUrls: [String]
    let songCount: Int
    let highlights: [ListenHighlight]
    let dailyDurations: [ListenDayDuration]
    let timePeriods: [ListenTimePeriod]
    let topArtists: [ListenTopArtist]
    let genreName: String
    let ageLabel: String
    let languageName: String
    let vipItems: [ListenVipItem]
    let podcastMinutes: Int
    let podcastEpisodes: Int
    let friendsListening: [ListenFriend]
    let friendKeywords: [String]

    static let empty = ListenReport(
        playMinutes: 0,
        beyondPercentText: "",
        achievementTitle: "",
        achievementSubtitle: "",
        listenDays: 0,
        wallpaperUrls: [],
        songCount: 0,
        highlights: [],
        dailyDurations: [],
        timePeriods: [],
        topArtists: [],
        genreName: "",
        ageLabel: "",
        languageName: "",
        vipItems: [],
        podcastMinutes: 0,
        podcastEpisodes: 0,
        friendsListening: [],
        friendKeywords: []
    )
}

struct ListenHighlight: Identifiable {
    let songId: Int64
    let songName: String
    let coverUrl: String
    let label: String
    let valueText: String
    var id: Int64 { songId }
}

struct ListenDayDuration: Identifiable {
    let index: Int
    let label: String
    let fullLabel: String
    let minutes: Int
    var id: Int { index }
}

struct ListenTimePeriod: Identifiable {
    let key: String
    let label: String
    let minutes: Int
    var id: String { key }
}

struct ListenTopArtist: Identifiable {
    let id: Int64
    let name: String
    let coverUrl: String
    let countText: String
}

struct ListenVipItem: Identifiable {
    let field: String
    let mainText: String
    let subText: String
    var id: String { field + mainText }
}

struct ListenFriend: Identifiable {
    let userId: Int64
    let username: String
    let avatarUrl: String
    let songName: String
    let playCount: Int
    var id: Int64 { userId }
}

// MARK: - DTOs

struct ListenReportEnvelope: Decodable {
    let code: Int
    let data: ListenReportData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(ListenReportData.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case code, data }
}

struct ListenReportData: Decodable {
    let listenTimeBlock: ListenTimeBlockData?
    let listenTimeDistributionBlock: ListenDistributionBlockData?
    let wallpaperBlock: ListenWallpaperBlockData?
    let topSongBlock: ListenTopSongBlockData?
    let topArtistBlock: ListenTopArtistBlockData?
    let topStyleBlock: ListenTopStyleBlockData?
    let topAgeBlock: ListenTopAgeBlockData?
    let topLanguageBlock: ListenTopLanguageBlockData?
    let vipBlock: ListenVipBlockData?
    let djListenDataBlock: ListenDjBlockData?
    let friendsListenBlock: ListenFriendsBlockData?
    let friendsKeywordBlock: ListenFriendKeywordBlockData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listenTimeBlock = try? container.decodeIfPresent(ListenTimeBlockData.self, forKey: .listenTimeBlock)
        listenTimeDistributionBlock = try? container.decodeIfPresent(ListenDistributionBlockData.self, forKey: .listenTimeDistributionBlock)
        wallpaperBlock = try? container.decodeIfPresent(ListenWallpaperBlockData.self, forKey: .wallpaperBlock)
        topSongBlock = try? container.decodeIfPresent(ListenTopSongBlockData.self, forKey: .topSongBlock)
        topArtistBlock = try? container.decodeIfPresent(ListenTopArtistBlockData.self, forKey: .topArtistBlock)
        topStyleBlock = try? container.decodeIfPresent(ListenTopStyleBlockData.self, forKey: .topStyleBlock)
        topAgeBlock = try? container.decodeIfPresent(ListenTopAgeBlockData.self, forKey: .topAgeBlock)
        topLanguageBlock = try? container.decodeIfPresent(ListenTopLanguageBlockData.self, forKey: .topLanguageBlock)
        vipBlock = try? container.decodeIfPresent(ListenVipBlockData.self, forKey: .vipBlock)
        djListenDataBlock = try? container.decodeIfPresent(ListenDjBlockData.self, forKey: .djListenDataBlock)
        friendsListenBlock = try? container.decodeIfPresent(ListenFriendsBlockData.self, forKey: .friendsListenBlock)
            ?? (try? container.decodeIfPresent(ListenFriendsBlockData.self, forKey: .friendsListenWeekBlock))
            ?? (try? container.decodeIfPresent(ListenFriendsBlockData.self, forKey: .friendsListenMonthBlock))
        friendsKeywordBlock = try? container.decodeIfPresent(ListenFriendKeywordBlockData.self, forKey: .friendsKeywordBlock)
            ?? (try? container.decodeIfPresent(ListenFriendKeywordBlockData.self, forKey: .friendsKeywordWeekBlock))
            ?? (try? container.decodeIfPresent(ListenFriendKeywordBlockData.self, forKey: .friendsKeyWordMonthBlock))
    }

    private enum CodingKeys: String, CodingKey {
        case listenTimeBlock, listenTimeDistributionBlock, wallpaperBlock
        case topSongBlock, topArtistBlock, topStyleBlock, topAgeBlock, topLanguageBlock
        case vipBlock, djListenDataBlock
        case friendsListenBlock, friendsListenWeekBlock, friendsListenMonthBlock
        case friendsKeywordBlock, friendsKeywordWeekBlock, friendsKeyWordMonthBlock
    }
}

struct ListenTimeBlockData: Decodable {
    let playDuration: Int
    let playDurationText: String
    let circleTimePeriodDurations: [ListenTimePeriodData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playDuration = (try? container.decode(Int.self, forKey: .playDuration)) ?? 0
        playDurationText = (try? container.decode(String.self, forKey: .playDurationText)) ?? ""
        circleTimePeriodDurations = (try? container.decode([ListenTimePeriodData].self, forKey: .circleTimePeriodDurations)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case playDuration, playDurationText, circleTimePeriodDurations }
}

struct ListenTimePeriodData: Decodable {
    let period: String
    let duration: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = (try? container.decode(String.self, forKey: .period)) ?? ""
        duration = (try? container.decode(Int.self, forKey: .duration)) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case period, duration }
}

struct ListenDistributionBlockData: Decodable {
    let listenDays: Int
    let achievementTitle: ListenAchievementTitleData?
    let durationDetails: [ListenDayDurationData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listenDays = (try? container.decode(Int.self, forKey: .listenDays)) ?? 0
        achievementTitle = try? container.decodeIfPresent(ListenAchievementTitleData.self, forKey: .achievementTitle)
        durationDetails = (try? container.decode([ListenDayDurationData].self, forKey: .durationDetails)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case listenDays, achievementTitle, durationDetails }
}

struct ListenAchievementTitleData: Decodable {
    let mainTitle: String
    let subTitle: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainTitle = (try? container.decode(String.self, forKey: .mainTitle)) ?? ""
        subTitle = (try? container.decode(String.self, forKey: .subTitle)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case mainTitle, subTitle }
}

struct ListenDayDurationData: Decodable {
    let period: String
    let duration: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = (try? container.decode(String.self, forKey: .period)) ?? ""
        duration = (try? container.decode(Int.self, forKey: .duration)) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case period, duration }
}

struct ListenWallpaperBlockData: Decodable {
    let songCount: Int
    let picUrls: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songCount = (try? container.decode(Int.self, forKey: .songCount)) ?? 0
        picUrls = (try? container.decode([String].self, forKey: .picUrls)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case songCount, picUrls }
}

struct ListenTopSongBlockData: Decodable {
    let sections: [ListenTopSongSectionData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = (try? container.decode([ListenTopSongSectionData].self, forKey: .sections)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case sections }
}

struct ListenTopSongSectionData: Decodable {
    let songId: Int64
    let songName: String
    let picUrl: String
    let field: String
    let text: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songId = (try? container.decode(Int64.self, forKey: .songId)) ?? 0
        songName = (try? container.decode(String.self, forKey: .songName)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        field = (try? container.decode(String.self, forKey: .field)) ?? ""
        text = (try? container.decode(String.self, forKey: .text)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case songId, songName, picUrl, field, text }
}

struct ListenTopArtistBlockData: Decodable {
    let sections: [ListenTopArtistSectionData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = (try? container.decode([ListenTopArtistSectionData].self, forKey: .sections)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case sections }
}

struct ListenTopArtistSectionData: Decodable {
    let artistId: Int64
    let artistName: String
    let picUrl: String
    let text: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artistId = (try? container.decode(Int64.self, forKey: .artistId)) ?? 0
        artistName = (try? container.decode(String.self, forKey: .artistName)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        text = (try? container.decode(String.self, forKey: .text)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case artistId, artistName, picUrl, text }
}

struct ListenTopStyleBlockData: Decodable {
    let genreName: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genreName = (try? container.decode(String.self, forKey: .genreName)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case genreName }
}

struct ListenTopAgeBlockData: Decodable {
    let sections: [ListenTopAgeSectionData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = (try? container.decode([ListenTopAgeSectionData].self, forKey: .sections)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case sections }
}

struct ListenTopAgeSectionData: Decodable {
    let age: String
    let playSongNum: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        age = (try? container.decode(String.self, forKey: .age)) ?? ""
        playSongNum = (try? container.decode(Int.self, forKey: .playSongNum)) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case age, playSongNum }
}

struct ListenTopLanguageBlockData: Decodable {
    let sections: [ListenTopLanguageSectionData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = (try? container.decode([ListenTopLanguageSectionData].self, forKey: .sections)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case sections }
}

struct ListenTopLanguageSectionData: Decodable {
    let language: String
    let playSongNum: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = (try? container.decode(String.self, forKey: .language)) ?? ""
        playSongNum = (try? container.decode(Int.self, forKey: .playSongNum)) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case language, playSongNum }
}

struct ListenVipBlockData: Decodable {
    let sections: [ListenVipSectionData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = (try? container.decode([ListenVipSectionData].self, forKey: .sections)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case sections }
}

struct ListenVipSectionData: Decodable {
    let type: String
    let field: String
    let mainText: String
    let subText: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        field = (try? container.decode(String.self, forKey: .field)) ?? ""
        mainText = (try? container.decode(String.self, forKey: .mainText)) ?? ""
        subText = (try? container.decode(String.self, forKey: .subText)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case type, field, mainText, subText }
}

struct ListenDjBlockData: Decodable {
    let podcastPlayDuration: Int
    let podcastEpNum: Int
    let audiobookPlayDuration: Int
    let audiobookEpNum: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        podcastPlayDuration = (try? container.decode(Int.self, forKey: .podcastPlayDuration)) ?? 0
        podcastEpNum = (try? container.decode(Int.self, forKey: .podcastEpNum)) ?? 0
        audiobookPlayDuration = (try? container.decode(Int.self, forKey: .audiobookPlayDuration)) ?? 0
        audiobookEpNum = (try? container.decode(Int.self, forKey: .audiobookEpNum)) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case podcastPlayDuration, podcastEpNum, audiobookPlayDuration, audiobookEpNum
    }
}

struct ListenFriendsBlockData: Decodable {
    let items: [ListenFriendItemData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decode([ListenFriendItemData].self, forKey: .items)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case items }
}

struct ListenFriendItemData: Decodable {
    let userId: Int64
    let username: String
    let userAvatar: String
    let songId: Int64
    let songName: String
    let songPicUrl: String
    let playCount: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? container.decode(Int64.self, forKey: .userId)) ?? 0
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        userAvatar = (try? container.decode(String.self, forKey: .userAvatar)) ?? ""
        songId = (try? container.decode(Int64.self, forKey: .songId)) ?? 0
        songName = (try? container.decode(String.self, forKey: .songName)) ?? ""
        songPicUrl = (try? container.decode(String.self, forKey: .songPicUrl)) ?? ""
        playCount = (try? container.decode(Int.self, forKey: .playCount)) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case userId, username, userAvatar, songId, songName, songPicUrl, playCount
    }
}

struct ListenFriendKeywordBlockData: Decodable {
    let items: [ListenFriendKeywordItemData]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decode([ListenFriendKeywordItemData].self, forKey: .items)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case items }
}

struct ListenFriendKeywordItemData: Decodable {
    let title: String
    let subTitle: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        subTitle = (try? container.decode(String.self, forKey: .subTitle)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case title, subTitle }
}

// MARK: - Mapping and formatting

extension ListenReportData {
    func domain(isWeek: Bool) -> ListenReport {
        let timeBlock = listenTimeBlock
        let distribution = listenTimeDistributionBlock
        let wallpaper = wallpaperBlock
        let daily = distribution?.durationDetails ?? []

        return ListenReport(
            playMinutes: timeBlock?.playDuration ?? 0,
            beyondPercentText: listenCleanPercentText(timeBlock?.playDurationText ?? ""),
            achievementTitle: distribution?.achievementTitle?.mainTitle ?? "",
            achievementSubtitle: distribution?.achievementTitle?.subTitle ?? "",
            listenDays: distribution?.listenDays ?? 0,
            wallpaperUrls: (wallpaper?.picUrls ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            songCount: wallpaper?.songCount ?? 0,
            highlights: (topSongBlock?.sections ?? [])
                .filter { !$0.songName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map {
                    ListenHighlight(songId: $0.songId, songName: $0.songName, coverUrl: $0.picUrl, label: $0.field, valueText: $0.text)
                },
            dailyDurations: daily.enumerated().map { index, item in
                ListenDayDuration(
                    index: index,
                    label: isWeek
                        ? listenWeekdayLabel(item.period)
                        : (index % 5 == 0 ? listenMonthDayLabel(item.period) : ""),
                    fullLabel: isWeek ? listenFullWeekdayLabel(item.period) : listenFullMonthDayLabel(item.period),
                    minutes: item.duration
                )
            },
            timePeriods: (timeBlock?.circleTimePeriodDurations ?? [])
                .sorted { listenPeriodSortIndex($0.period) < listenPeriodSortIndex($1.period) }
                .map { ListenTimePeriod(key: $0.period, label: listenPeriodLabel($0.period), minutes: $0.duration) },
            topArtists: (topArtistBlock?.sections ?? []).map {
                ListenTopArtist(id: $0.artistId, name: $0.artistName, coverUrl: $0.picUrl, countText: $0.text)
            },
            genreName: topStyleBlock?.genreName ?? "",
            ageLabel: listenAgeLabel(topAgeBlock?.sections.first?.age ?? ""),
            languageName: topLanguageBlock?.sections.first?.language ?? "",
            vipItems: (vipBlock?.sections ?? []).map {
                ListenVipItem(field: $0.field, mainText: $0.mainText, subText: $0.subText)
            },
            podcastMinutes: djListenDataBlock?.podcastPlayDuration ?? 0,
            podcastEpisodes: djListenDataBlock?.podcastEpNum ?? 0,
            friendsListening: (friendsListenBlock?.items ?? []).map {
                ListenFriend(userId: $0.userId, username: $0.username, avatarUrl: $0.userAvatar, songName: $0.songName, playCount: $0.playCount)
            },
            friendKeywords: (friendsKeywordBlock?.items ?? []).map(\.title).filter { !$0.isEmpty }
        )
    }
}

private let listenPeriodOrder = ["early_morning", "morning", "noon", "afternoon", "night", "deep_night"]
private let listenPeriodLabels = [
    "early_morning": "凌晨", "morning": "早上", "noon": "中午",
    "afternoon": "下午", "night": "晚上", "deep_night": "深夜"
]

func listenPeriodLabel(_ value: String) -> String { listenPeriodLabels[value] ?? value }

func listenPeriodSortIndex(_ value: String) -> Int {
    listenPeriodOrder.firstIndex(of: value) ?? listenPeriodOrder.count
}

func listenCleanPercentText(_ raw: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "(\\d{1,3})\\s*%"),
          let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
          let range = Range(match.range(at: 1), in: raw) else { return "" }
    return "超过了 \(raw[range])% 的用户"
}

func listenAgeLabel(_ age: String) -> String {
    age.isEmpty ? "" : "\(age)s"
}

func listenHoursText(_ seconds: Int64) -> String {
    guard seconds > 0 else { return "0" }
    return String(format: "%.1f", Double(seconds) / 3600)
}

func listenWeekdayLabel(_ period: String) -> String {
    let parts = period.split(separator: "-")
    guard parts.count == 3,
          let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
        return period
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "zh_CN")
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
        return listenMonthDayLabel(period)
    }
    let symbols = ["日", "一", "二", "三", "四", "五", "六"]
    let weekday = calendar.component(.weekday, from: date)
    return symbols[(weekday - 1) % symbols.count]
}

func listenMonthDayLabel(_ period: String) -> String {
    let parts = period.split(separator: "-")
    guard parts.count >= 3 else { return period }
    let day = parts[2].drop(while: { $0 == "0" })
    return day.isEmpty ? String(parts[2]) : String(day)
}

func listenFullWeekdayLabel(_ period: String) -> String {
    let label = listenWeekdayLabel(period)
    return label.count == 1 ? "周\(label)" : label
}

func listenFullMonthDayLabel(_ period: String) -> String {
    let parts = period.split(separator: "-")
    guard parts.count >= 3 else { return period }
    let month = parts[1].drop(while: { $0 == "0" })
    let day = parts[2].drop(while: { $0 == "0" })
    guard !month.isEmpty, !day.isEmpty else { return period }
    return "\(month)月\(day)日"
}