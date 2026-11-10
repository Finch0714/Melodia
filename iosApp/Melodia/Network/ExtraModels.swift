import Foundation

// MARK: - Song wiki / music memory

struct SongWikiData: Hashable {
    var style: String = ""
    var language: String = ""
    var bpm: String = ""
    var entertainment: String = ""
    var awards: [String] = []
    var awardTotal: Int = 0
    var creators: String = ""
    var musicMemory: SongMusicMemory?

    var hasDetail: Bool {
        !style.isEmpty || !language.isEmpty || !bpm.isEmpty || !entertainment.isEmpty
    }
}

struct SongMusicMemory: Hashable {
    let firstListenDate: String
    let season: String
    let period: String
    let playCount: Int
    let playCountText: String
}

struct SongWikiEnvelope: Decodable {
    let code: Int
    let data: SongWikiPage?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(SongWikiPage.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case code, data }
}

struct SongWikiPage: Decodable {
    let blocks: [SongWikiBlock]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks = (try? container.decode([SongWikiBlock].self, forKey: .blocks)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case blocks }
}

struct SongWikiBlock: Decodable {
    let code: String
    let creatives: [SongWikiCreative]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(String.self, forKey: .code)) ?? ""
        creatives = (try? container.decode([SongWikiCreative].self, forKey: .creatives)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, creatives }
}

struct SongWikiCreative: Decodable {
    let creativeType: String
    let resources: [SongWikiResource]
    let uiElement: SongWikiUIElement?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creativeType = (try? container.decode(String.self, forKey: .creativeType)) ?? ""
        resources = (try? container.decode([SongWikiResource].self, forKey: .resources)) ?? []
        uiElement = try? container.decodeIfPresent(SongWikiUIElement.self, forKey: .uiElement)
    }

    private enum CodingKeys: String, CodingKey { case creativeType, resources, uiElement }
}

struct SongWikiResource: Decodable {
    let resourceType: String
    let resourceExt: SongWikiResourceExt?
    let uiElement: SongWikiUIElement?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resourceType = (try? container.decode(String.self, forKey: .resourceType)) ?? ""
        resourceExt = try? container.decodeIfPresent(SongWikiResourceExt.self, forKey: .resourceExt)
        uiElement = try? container.decodeIfPresent(SongWikiUIElement.self, forKey: .uiElement)
    }

    private enum CodingKeys: String, CodingKey { case resourceType, resourceExt, uiElement }
}

struct SongWikiResourceExt: Decodable {
    let musicFirstListenDto: SongWikiFirstListen?
    let musicTotalPlayDto: SongWikiTotalPlay?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        musicFirstListenDto = try? container.decodeIfPresent(SongWikiFirstListen.self, forKey: .musicFirstListenDto)
        musicTotalPlayDto = try? container.decodeIfPresent(SongWikiTotalPlay.self, forKey: .musicTotalPlayDto)
    }

    private enum CodingKeys: String, CodingKey { case musicFirstListenDto, musicTotalPlayDto }
}

struct SongWikiFirstListen: Decodable {
    let date: String?
    let season: String?
    let period: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try? container.decodeIfPresent(String.self, forKey: .date)
        season = try? container.decodeIfPresent(String.self, forKey: .season)
        period = try? container.decodeIfPresent(String.self, forKey: .period)
    }

    private enum CodingKeys: String, CodingKey { case date, season, period }
}

struct SongWikiTotalPlay: Decodable {
    let playCount: Int?
    let text: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playCount = try? container.decodeIfPresent(Int.self, forKey: .playCount)
        text = try? container.decodeIfPresent(String.self, forKey: .text)
    }

    private enum CodingKeys: String, CodingKey { case playCount, text }
}

struct SongWikiUIElement: Decodable {
    let mainTitle: SongWikiTitle?
    let textLinks: [SongWikiTextLink]?
    let buttons: [SongWikiButton]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainTitle = try? container.decodeIfPresent(SongWikiTitle.self, forKey: .mainTitle)
        textLinks = try? container.decodeIfPresent([SongWikiTextLink].self, forKey: .textLinks)
        buttons = try? container.decodeIfPresent([SongWikiButton].self, forKey: .buttons)
    }

    private enum CodingKeys: String, CodingKey { case mainTitle, textLinks, buttons }
}

struct SongWikiTitle: Decodable {
    let title: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
    }
    private enum CodingKeys: String, CodingKey { case title }
}

struct SongWikiTextLink: Decodable {
    let text: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try? container.decodeIfPresent(String.self, forKey: .text)
    }
    private enum CodingKeys: String, CodingKey { case text }
}

struct SongWikiButton: Decodable {
    let text: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try? container.decodeIfPresent(String.self, forKey: .text)
    }
    private enum CodingKeys: String, CodingKey { case text }
}

extension SongWikiEnvelope {
    var wiki: SongWikiData? {
        guard code == 200, let page = data else { return nil }
        var result = SongWikiData()

        for block in page.blocks {
            if block.code == "SONG_PLAY_ABOUT_SONG_BASIC" {
                for creative in block.creatives {
                    switch creative.creativeType {
                    case "songTag":
                        result.style = creative.resources
                            .compactMap { $0.uiElement?.mainTitle?.title }
                            .filter { !$0.isEmpty }
                            .joined(separator: " / ")
                    case "language":
                        result.language = creative.uiElement?.textLinks?.first?.text ?? ""
                    case "bpm":
                        result.bpm = creative.uiElement?.textLinks?.first?.text ?? ""
                    case "entertainment":
                        result.entertainment = creative.resources
                            .compactMap { $0.uiElement?.mainTitle?.title }
                            .filter { !$0.isEmpty }
                            .joined(separator: " / ")
                    case "songAward":
                        result.awards = creative.resources
                            .compactMap { $0.uiElement?.mainTitle?.title }
                            .filter { !$0.isEmpty }
                        result.awardTotal = Int((creative.uiElement?.buttons?.first?.text ?? "").filter(\.isNumber)) ?? 0
                    default:
                        break
                    }
                }
            } else if block.code == "SONG_PLAY_ABOUT_MUSIC_MEMORY" {
                let resources = block.creatives.flatMap(\.resources)
                let firstListen = resources.first { $0.resourceType == "FIRST_LISTEN" }?.resourceExt?.musicFirstListenDto
                let totalPlay = resources.first { $0.resourceType == "TOTAL_PLAY" }?.resourceExt?.musicTotalPlayDto
                let date = firstListen?.date?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let count = max(totalPlay?.playCount ?? 0, 0)
                if !date.isEmpty || count > 0 {
                    result.musicMemory = SongMusicMemory(
                        firstListenDate: date,
                        season: firstListen?.season?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        period: firstListen?.period?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        playCount: count,
                        playCountText: totalPlay?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    )
                }
            }
        }

        return result
    }
}

func musicMemoryText(_ memory: SongMusicMemory) -> String {
    var parts: [String] = []
    let date = memory.firstListenDate.split(separator: " ").first.map(String.init) ?? ""
    if !date.isEmpty {
        var line = date
        let moment = [memory.season, memory.period].filter { !$0.isEmpty }.joined(separator: "的")
        if !moment.isEmpty {
            line += "，一个\(moment)"
        }
        line += "，你第一次听到这首歌。"
        parts.append(line)
    }
    if memory.playCount > 0 {
        var line = date.isEmpty ? "这首歌你已播放 \(memory.playCount) 次" : "至今播放 \(memory.playCount) 次"
        let analogy = memory.playCountText
            .trimmingCharacters(in: CharacterSet(charactersIn: "。，,!"))
        if !analogy.isEmpty {
            line += "，\(analogy)"
        }
        line += "。"
        parts.append(line)
    }
    return parts.joined()
}

// MARK: - Comment actions and floors

struct RepliedComment: Decodable, Hashable {
    let user: CommentUser?
    let content: String?
    let beRepliedCommentId: Int64?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try? container.decodeIfPresent(CommentUser.self, forKey: .user)
        content = try? container.decodeIfPresent(String.self, forKey: .content)
        beRepliedCommentId = try? container.decodeIfPresent(Int64.self, forKey: .beRepliedCommentId)
    }

    private enum CodingKeys: String, CodingKey { case user, content, beRepliedCommentId }
}

struct CommentActionEnvelope: Decodable {
    let code: Int
    let message: String?
    let comment: CommentItem?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        comment = try? container.decodeIfPresent(CommentItem.self, forKey: .comment)
    }

    private enum CodingKeys: String, CodingKey { case code, message, comment }
}

struct CommentFloorEnvelope: Decodable {
    let code: Int
    let data: CommentFloorData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(CommentFloorData.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case code, data }
}

struct CommentFloorData: Decodable {
    let comments: [CommentItem]
    let hasMore: Bool
    let totalCount: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        comments = (try? container.decode([CommentItem].self, forKey: .comments)) ?? []
        hasMore = (try? container.decode(Bool.self, forKey: .hasMore)) ?? false
        totalCount = (try? container.decode(Int.self, forKey: .totalCount)) ?? comments.count
    }

    private enum CodingKeys: String, CodingKey { case comments, hasMore, totalCount }
}
// MARK: - Recently played

struct RecentSongsEnvelope: Decodable {
    let code: Int
    let data: RecentSongsData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(RecentSongsData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct RecentSongsData: Decodable {
    let list: [RecentSongRecord]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? container.decode([RecentSongRecord].self, forKey: .list)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case list }
}

struct RecentSongRecord: Decodable, Identifiable {
    let playTime: Int64
    let data: Track
    var id: Int64 { data.id }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playTime = (try? container.decode(Int64.self, forKey: .playTime)) ?? 0
        data = (try? container.decode(Track.self, forKey: .data)) ?? Track.empty
    }
    private enum CodingKeys: String, CodingKey { case playTime, data }
}

struct RecentPlaylistsEnvelope: Decodable {
    let code: Int
    let data: RecentPlaylistsData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(RecentPlaylistsData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct RecentPlaylistsData: Decodable {
    let list: [RecentPlaylistRecord]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? container.decode([RecentPlaylistRecord].self, forKey: .list)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case list }
}

struct RecentPlaylistRecord: Decodable, Identifiable {
    let playTime: Int64
    let data: RecentPlaylistInfo
    var id: Int64 { data.id }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playTime = (try? container.decode(Int64.self, forKey: .playTime)) ?? 0
        data = (try? container.decode(RecentPlaylistInfo.self, forKey: .data)) ?? RecentPlaylistInfo.empty
    }
    private enum CodingKeys: String, CodingKey { case playTime, data }
}

struct RecentPlaylistInfo: Decodable, Hashable {
    let id: Int64
    let name: String
    let coverImgUrl: String
    let creator: PlaylistCreator?

    static let empty = RecentPlaylistInfo(id: 0, name: "", coverImgUrl: "", creator: nil)

    init(id: Int64, name: String, coverImgUrl: String, creator: PlaylistCreator?) {
        self.id = id
        self.name = name
        self.coverImgUrl = coverImgUrl
        self.creator = creator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        coverImgUrl = (try? container.decode(String.self, forKey: .coverImgUrl)) ?? ""
        creator = try? container.decodeIfPresent(PlaylistCreator.self, forKey: .creator)
    }

    private enum CodingKeys: String, CodingKey { case id, name, coverImgUrl, creator }
}

struct RecentAlbumsEnvelope: Decodable {
    let code: Int
    let data: RecentAlbumsData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(RecentAlbumsData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct RecentAlbumsData: Decodable {
    let list: [RecentAlbumRecord]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? container.decode([RecentAlbumRecord].self, forKey: .list)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case list }
}

struct RecentAlbumRecord: Decodable, Identifiable {
    let playTime: Int64
    let data: RecentAlbumInfo
    var id: Int64 { data.id }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playTime = (try? container.decode(Int64.self, forKey: .playTime)) ?? 0
        data = (try? container.decode(RecentAlbumInfo.self, forKey: .data)) ?? RecentAlbumInfo.empty
    }
    private enum CodingKeys: String, CodingKey { case playTime, data }
}

struct RecentAlbumInfo: Decodable, Hashable {
    let id: Int64
    let name: String
    let picUrl: String
    let artist: Artist?

    static let empty = RecentAlbumInfo(id: 0, name: "", picUrl: "", artist: nil)

    init(id: Int64, name: String, picUrl: String, artist: Artist?) {
        self.id = id
        self.name = name
        self.picUrl = picUrl
        self.artist = artist
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        artist = try? container.decodeIfPresent(Artist.self, forKey: .artist)
    }

    private enum CodingKeys: String, CodingKey { case id, name, picUrl, artist }
}

// MARK: - Home block page

struct HomeBlockEnvelope: Decodable {
    let code: Int
    let data: HomeBlockPageData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(HomeBlockPageData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct HomeBlockPageData: Decodable {
    let cursor: String?
    let hasMore: Bool
    let blocks: [HomeBlock]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cursor = try? container.decodeIfPresent(String.self, forKey: .cursor)
        hasMore = (try? container.decode(Bool.self, forKey: .hasMore)) ?? false
        blocks = (try? container.decode([HomeBlock].self, forKey: .blocks)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case cursor, hasMore, blocks }
}

struct HomeBlock: Decodable {
    let blockCode: String
    let uiElement: HomeUIElement?
    let creatives: [HomeCreative]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockCode = (try? container.decode(String.self, forKey: .blockCode)) ?? ""
        uiElement = try? container.decodeIfPresent(HomeUIElement.self, forKey: .uiElement)
        creatives = (try? container.decode([HomeCreative].self, forKey: .creatives)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case blockCode, uiElement, creatives }
}

struct HomeCreative: Decodable {
    let resources: [HomeResource]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resources = (try? container.decode([HomeResource].self, forKey: .resources)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case resources }
}

struct HomeResource: Decodable {
    let resourceType: String
    let resourceId: String?
    let uiElement: HomeUIElement?
    let action: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resourceType = (try? container.decode(String.self, forKey: .resourceType)) ?? ""
        resourceId = try? container.decodeIfPresent(String.self, forKey: .resourceId)
        uiElement = try? container.decodeIfPresent(HomeUIElement.self, forKey: .uiElement)
        action = try? container.decodeIfPresent(String.self, forKey: .action)
    }

    private enum CodingKeys: String, CodingKey { case resourceType, resourceId, uiElement, action }
}

struct HomeUIElement: Decodable {
    let mainTitle: HomeText?
    let subTitle: HomeText?
    let description: String?
    let image: HomeImage?
    let labelTexts: [String]?
    let labelText: HomeText?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainTitle = try? container.decodeIfPresent(HomeText.self, forKey: .mainTitle)
        subTitle = try? container.decodeIfPresent(HomeText.self, forKey: .subTitle)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        image = try? container.decodeIfPresent(HomeImage.self, forKey: .image)
        labelTexts = try? container.decodeIfPresent([String].self, forKey: .labelTexts)
        labelText = try? container.decodeIfPresent(HomeText.self, forKey: .labelText)
    }

    private enum CodingKeys: String, CodingKey {
        case mainTitle, subTitle, description, image, labelTexts, labelText
    }
}

struct HomeText: Decodable {
    let title: String?
    let text: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        text = try? container.decodeIfPresent(String.self, forKey: .text)
    }
    private enum CodingKeys: String, CodingKey { case title, text }
}

struct HomeImage: Decodable {
    let imageUrl: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageUrl = try? container.decodeIfPresent(String.self, forKey: .imageUrl)
    }
    private enum CodingKeys: String, CodingKey { case imageUrl }
}

struct HomeShelfModel: Identifiable {
    let code: String
    let title: String
    let showRank: Bool
    let cards: [HomeCardModel]
    var id: String { code }
}

enum HomeCardModel: Identifiable {
    case playlist(id: Int64, title: String, cover: String, caption: String)
    case album(id: Int64, title: String, cover: String, caption: String)
    case song(id: Int64, title: String, cover: String, caption: String)

    var id: String {
        switch self {
        case .playlist(let id, _, _, _): return "playlist-\(id)"
        case .album(let id, _, _, _): return "album-\(id)"
        case .song(let id, _, _, _): return "song-\(id)"
        }
    }

    var title: String {
        switch self {
        case .playlist(_, let title, _, _), .album(_, let title, _, _), .song(_, let title, _, _):
            return title
        }
    }

    var cover: String {
        switch self {
        case .playlist(_, _, let cover, _), .album(_, _, let cover, _), .song(_, _, let cover, _):
            return cover
        }
    }

    var caption: String {
        switch self {
        case .playlist(_, _, _, let caption), .album(_, _, _, let caption), .song(_, _, _, let caption):
            return caption
        }
    }

    var typeLabel: String {
        switch self {
        case .playlist: return "歌单"
        case .album: return "专辑"
        case .song: return "单曲"
        }
    }

    var isSong: Bool {
        if case .song = self { return true }
        return false
    }

    var coverURL: URL? {
        guard !cover.isEmpty else { return nil }
        return URL(string: cover.replacingOccurrences(of: "http://", with: "https://"))
    }
}

extension HomeBlockPageData {
    var shelves: [HomeShelfModel] {
        blocks.compactMap { block in
            guard block.blockCode != "HOMEPAGE_BANNER",
                  block.blockCode != "HOMEPAGE_BLOCK_OLD_DRAGON_BALL",
                  let element = block.uiElement else { return nil }
            let title = (element.mainTitle?.title?.isEmpty == false ? element.mainTitle?.title : element.subTitle?.title) ?? ""
            guard !title.isEmpty else { return nil }
            let cards = block.creatives.flatMap(\.resources).compactMap(Self.card(from:))
            guard !cards.isEmpty else { return nil }
            return HomeShelfModel(
                code: block.blockCode,
                title: title,
                showRank: block.blockCode == "HOMEPAGE_BLOCK_TOPLIST",
                cards: cards
            )
        }
    }

    private static func card(from resource: HomeResource) -> HomeCardModel? {
        guard let ui = resource.uiElement else { return nil }
        let title = ui.mainTitle?.title ?? ""
        var cover = ui.image?.imageUrl ?? ""
        guard !title.isEmpty, !cover.isEmpty else { return nil }
        if cover.hasPrefix("http://") {
            cover = cover.replacingOccurrences(of: "http://", with: "https://")
        }
        let caption = ui.labelTexts?.filter { !$0.isEmpty }.joined(separator: " · ")
            ?? ui.labelText?.text
            ?? ui.subTitle?.title
            ?? ui.description
            ?? ""

        switch resource.resourceType.lowercased() {
        case "list":
            guard let id = actionID(resource.action, kind: "playlist") ?? resource.resourceId.flatMap(Int64.init) else { return nil }
            return .playlist(id: id, title: title, cover: cover, caption: caption)
        case "album", "digitalalbum":
            guard let id = actionID(resource.action, kind: "album") else { return nil }
            return .album(id: id, title: title, cover: cover, caption: caption)
        case "song":
            guard let id = resource.resourceId.flatMap(Int64.init) else { return nil }
            return .song(id: id, title: title, cover: cover, caption: caption)
        default:
            return nil
        }
    }

    private static func actionID(_ action: String?, kind: String) -> Int64? {
        guard let action else { return nil }
        let prefix = "orpheus://\(kind)/"
        guard let range = action.range(of: prefix) else { return nil }
        return Int64(action[range.upperBound...].prefix { $0.isNumber })
    }
}
// MARK: - Messages

struct MessageCommentsEnvelope: Decodable {
    let code: Int
    let more: Bool
    let comments: [MessageCommentItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        more = (try? container.decode(Bool.self, forKey: .more)) ?? false
        comments = (try? container.decode([MessageCommentItem].self, forKey: .comments)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, more, comments }
}

struct MessageCommentItem: Decodable, Identifiable {
    let commentId: Int64
    let content: String
    let time: Int64
    let user: CommentUser
    let beRepliedContent: String?
    let threadId: String
    let resourceName: String?

    var id: Int64 { commentId }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commentId = (try? container.decode(Int64.self, forKey: .commentId)) ?? 0
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        time = (try? container.decode(Int64.self, forKey: .time)) ?? 0
        user = (try? container.decode(CommentUser.self, forKey: .user)) ?? CommentUser()
        beRepliedContent = try? container.decodeIfPresent(String.self, forKey: .beRepliedContent)
        threadId = (try? container.decode(String.self, forKey: .threadId)) ?? ""
        let resourceJSON = try? container.decodeIfPresent(String.self, forKey: .resourceJson)
        resourceName = MessageCommentItem.resourceName(from: resourceJSON)
    }

    private enum CodingKeys: String, CodingKey {
        case commentId, content, time, user, beRepliedContent, threadId, resourceJson
    }

    private static func resourceName(from raw: String?) -> String? {
        guard let raw, let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["name"] as? String
    }
}

struct MessageNoticesEnvelope: Decodable {
    let code: Int
    let more: Bool
    let lastTime: Int64
    let notices: [MessageNoticeItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        more = (try? container.decode(Bool.self, forKey: .more)) ?? false
        lastTime = (try? container.decode(Int64.self, forKey: .lastTime)) ?? 0
        notices = (try? container.decode([MessageNoticeItem].self, forKey: .notices)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, more, lastTime, notices }
}

struct MessageNoticeItem: Decodable, Identifiable {
    let id: Int64
    let time: Int64
    let notice: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        time = (try? container.decode(Int64.self, forKey: .time)) ?? 0
        notice = try? container.decodeIfPresent(String.self, forKey: .notice)
    }

    private enum CodingKeys: String, CodingKey { case id, time, notice }

    var displayText: String {
        guard let notice, let data = notice.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "收到一条通知"
        }
        let user = (object["user"] as? [String: Any])?["nickname"] as? String ?? ""
        let comment = object["comment"] as? [String: Any]
        let commentContent = comment?["content"] as? String ?? ""
        let type = object["type"] as? Int ?? 0

        switch type {
        case 6:
            if !commentContent.isEmpty { return "赞了你的评论：\(commentContent)" }
            return "赞了你的评论"
        case 1:
            return "赞了你的分享"
        case 2:
            if let playlist = object["playlist"] as? [String: Any],
               let name = playlist["name"] as? String, !name.isEmpty {
                return "收藏了你的歌单《\(name)》"
            }
            return "收藏了你的歌单"
        default:
            break
        }

        for key in ["content", "text", "title", "msg"] {
            if let value = object[key] as? String, !value.isEmpty {
                return user.isEmpty ? value : "\(user)：\(value)"
            }
        }
        return user.isEmpty ? "收到一条通知" : "\(user) 发来一条通知"
    }
}

struct MessageForwardsEnvelope: Decodable {
    let code: Int
    let more: Bool
    let forwards: [MessageForwardRaw]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        more = (try? container.decode(Bool.self, forKey: .more)) ?? false
        forwards = (try? container.decode([MessageForwardRaw].self, forKey: .forwards)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, more, forwards }
}

struct MessageForwardRaw: Decodable {
    let json: String?
    let msg: String?
    let content: String?
    let eventTime: Int64?
    let time: Int64?
    let user: CommentUser?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        json = try? container.decodeIfPresent(String.self, forKey: .json)
        msg = try? container.decodeIfPresent(String.self, forKey: .msg)
        content = try? container.decodeIfPresent(String.self, forKey: .content)
        eventTime = try? container.decodeIfPresent(Int64.self, forKey: .eventTime)
        time = try? container.decodeIfPresent(Int64.self, forKey: .time)
        user = try? container.decodeIfPresent(CommentUser.self, forKey: .user)
    }

    private enum CodingKeys: String, CodingKey { case json, msg, content, eventTime, time, user }
}

struct MessageForwardDisplay: Identifiable, Hashable {
    let id: Int64
    let nickname: String
    let avatarURL: String
    let content: String
    let time: Int64
}

// MARK: - Listening data

struct ListenTotalEnvelope: Decodable {
    let code: Int
    let data: ListenTotalData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(ListenTotalData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct ListenTotalData: Decodable {
    let totalDuration: Int64
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalDuration = (try? container.decode(Int64.self, forKey: .totalDuration)) ?? 0
    }
    private enum CodingKeys: String, CodingKey { case totalDuration }
}

struct ListenTodayEnvelope: Decodable {
    let code: Int
    let data: ListenTodayData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(ListenTodayData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct ListenTodayData: Decodable {
    let songDTOs: [ListenTodaySong]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songDTOs = (try? container.decode([ListenTodaySong].self, forKey: .songDTOs)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case songDTOs }
}

struct ListenTodaySong: Decodable, Identifiable {
    let songId: Int64
    let songName: String
    let picUrl: String
    let artists: [ListenArtist]
    var id: Int64 { songId }
    var artistText: String {
        artists.map(\.artistName).filter { !$0.isEmpty }.joined(separator: " / ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songId = (try? container.decode(Int64.self, forKey: .songId)) ?? 0
        songName = (try? container.decode(String.self, forKey: .songName)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        artists = (try? container.decode([ListenArtist].self, forKey: .artists)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case songId, songName, picUrl, artists }
}

struct ListenArtist: Decodable, Hashable {
    let artistId: Int64
    let artistName: String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artistId = (try? container.decode(Int64.self, forKey: .artistId)) ?? 0
        artistName = (try? container.decode(String.self, forKey: .artistName)) ?? ""
    }
    private enum CodingKeys: String, CodingKey { case artistId, artistName }
}

struct ListenRankEnvelope: Decodable {
    let code: Int
    let data: ListenRankData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(ListenRankData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct ListenRankData: Decodable {
    let songCount: Int
    let songItems: [ListenRankSong]

    static let empty = ListenRankData(songCount: 0, songItems: [])

    init(songCount: Int, songItems: [ListenRankSong]) {
        self.songCount = songCount
        self.songItems = songItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songCount = (try? container.decode(Int.self, forKey: .songCount)) ?? 0
        songItems = (try? container.decode([ListenRankSong].self, forKey: .songItems)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case songCount, songItems }
}

struct ListenRankSong: Decodable, Identifiable {
    let songId: Int64
    let songName: String
    let albumName: String
    let picUrl: String
    let playCount: Int
    let artists: [ListenArtist]
    var id: Int64 { songId }
    var artistText: String {
        artists.map(\.artistName).filter { !$0.isEmpty }.joined(separator: " / ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songId = (try? container.decode(Int64.self, forKey: .songId)) ?? 0
        songName = (try? container.decode(String.self, forKey: .songName)) ?? ""
        albumName = (try? container.decode(String.self, forKey: .albumName)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        playCount = (try? container.decode(Int.self, forKey: .playCount)) ?? 0
        artists = (try? container.decode([ListenArtist].self, forKey: .artists)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case songId, songName, albumName, picUrl, playCount, artists }
}

struct ListenYearEnvelope: Decodable {
    let code: Int
    let data: ListenYearData?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(ListenYearData.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, data }
}

struct ListenYearData: Decodable {
    let displayYear: Int
    let yearItems: [ListenYearItem]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayYear = (try? container.decode(Int.self, forKey: .displayYear)) ?? 0
        yearItems = (try? container.decode([ListenYearItem].self, forKey: .yearItems)) ?? []
    }
    private enum CodingKeys: String, CodingKey { case displayYear, yearItems }
}

struct ListenYearItem: Decodable, Identifiable {
    let year: Int
    let playNum: Int
    let playDuration: Int64
    var id: Int { year }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        year = (try? container.decode(Int.self, forKey: .year)) ?? 0
        playNum = (try? container.decode(Int.self, forKey: .playNum)) ?? 0
        playDuration = (try? container.decode(Int64.self, forKey: .playDuration)) ?? 0
    }
    private enum CodingKeys: String, CodingKey { case year, playNum, playDuration }
}