import Foundation

struct Artist: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, img1v1Url
    }

    init(id: Int64, name: String, picUrl: String? = nil) {
        self.id = id
        self.name = name
        self.picUrl = picUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = (try? container.decodeIfPresent(String.self, forKey: .picUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .img1v1Url))
    }

    var avatarURL: URL? {
        guard let picUrl, !picUrl.isEmpty else { return nil }
        return URL(string: picUrl)
    }
}

struct Album: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String
    let artists: [Artist]
    let publishTime: Int64

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, artists, publishTime
    }

    init(
        id: Int64,
        name: String,
        picUrl: String = "",
        artists: [Artist] = [],
        publishTime: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.picUrl = picUrl
        self.artists = artists
        self.publishTime = publishTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        artists = (try? container.decode([Artist].self, forKey: .artists)) ?? []
        publishTime = (try? container.decode(Int64.self, forKey: .publishTime)) ?? 0
    }

    var coverURL: URL? {
        guard !picUrl.isEmpty else { return nil }
        return URL(string: picUrl)
    }

    var artistText: String {
        let value = artists.map(\.name).filter { !$0.isEmpty }.joined(separator: " / ")
        return value.isEmpty ? "未知歌手" : value
    }
}

struct Track: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let artists: [Artist]
    let album: Album?
    let durationMs: Int64
    let fee: Int

    static let empty = Track(id: 0, name: "", artists: [], album: nil, durationMs: 0, fee: 0)

    init(
        id: Int64,
        name: String,
        artists: [Artist] = [],
        album: Album? = nil,
        durationMs: Int64 = 0,
        fee: Int = 0
    ) {
        self.id = id
        self.name = name
        self.artists = artists
        self.album = album
        self.durationMs = durationMs
        self.fee = fee
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, ar, artists, al, album, dt, fee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "未知歌曲"
        artists = (try? container.decodeIfPresent([Artist].self, forKey: .ar))
            ?? (try? container.decodeIfPresent([Artist].self, forKey: .artists))
            ?? []
        album = (try? container.decodeIfPresent(Album.self, forKey: .al))
            ?? (try? container.decodeIfPresent(Album.self, forKey: .album))
        durationMs = (try? container.decode(Int64.self, forKey: .dt)) ?? 0
        fee = (try? container.decode(Int.self, forKey: .fee)) ?? 0
    }

    var artistText: String {
        let value = artists.map(\.name).filter { !$0.isEmpty }.joined(separator: " / ")
        return value.isEmpty ? "未知歌手" : value
    }

    var albumName: String {
        album?.name ?? ""
    }

    var coverURL: URL? {
        guard let raw = album?.picUrl, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    var formattedDuration: String {
        guard durationMs > 0 else { return "--:--" }
        let seconds = Int(durationMs / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct PlaylistSummary: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let cover: String
    let playCount: Int64

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, coverImgUrl, playCount
    }

    init(id: Int64, name: String, cover: String = "", playCount: Int64 = 0) {
        self.id = id
        self.name = name
        self.cover = cover
        self.playCount = playCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "未命名歌单"
        cover = (try? container.decodeIfPresent(String.self, forKey: .coverImgUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .picUrl))
            ?? ""
        playCount = (try? container.decode(Int64.self, forKey: .playCount)) ?? 0
    }

    var coverURL: URL? { URL(string: cover) }

    var playCountText: String? {
        guard playCount > 0 else { return nil }
        if playCount >= 100_000_000 {
            return String(format: "%.1f亿", Double(playCount) / 100_000_000)
        }
        if playCount >= 10_000 {
            return String(format: "%.1f万", Double(playCount) / 10_000)
        }
        return "\(playCount)"
    }
}

struct PlaylistCreator: Decodable, Hashable {
    let userId: Int64
    let nickname: String
    let avatarUrl: String

    private enum CodingKeys: String, CodingKey {
        case userId, nickname, avatarUrl
    }

    init(userId: Int64 = 0, nickname: String = "", avatarUrl: String = "") {
        self.userId = userId
        self.nickname = nickname
        self.avatarUrl = avatarUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? container.decode(Int64.self, forKey: .userId)) ?? 0
        nickname = (try? container.decode(String.self, forKey: .nickname)) ?? ""
        avatarUrl = (try? container.decode(String.self, forKey: .avatarUrl)) ?? ""
    }
}

struct PlaylistDetail: Decodable, Identifiable {
    let id: Int64
    let name: String
    let cover: String
    let description: String?
    let playCount: Int64
    let tracks: [Track]
    let trackIds: [PlaylistTrackId]
    let trackCount: Int
    let creator: PlaylistCreator?

    private enum CodingKeys: String, CodingKey {
        case id, name, coverImgUrl, description, playCount, tracks, trackIds, trackCount, creator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "歌单"
        cover = (try? container.decode(String.self, forKey: .coverImgUrl)) ?? ""
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        playCount = (try? container.decode(Int64.self, forKey: .playCount)) ?? 0
        tracks = (try? container.decode([Track].self, forKey: .tracks)) ?? []
        trackIds = (try? container.decode([PlaylistTrackId].self, forKey: .trackIds)) ?? []
        trackCount = (try? container.decode(Int.self, forKey: .trackCount)) ?? tracks.count
        creator = try? container.decodeIfPresent(PlaylistCreator.self, forKey: .creator)
    }

    var coverURL: URL? { URL(string: cover) }
}

struct PlaylistTrackId: Decodable, Hashable {
    let id: Int64

    private enum CodingKeys: String, CodingKey {
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
    }
}

struct SearchResult: Decodable {
    let songs: [Track]?
    let songCount: Int
    let albums: [Album]?
    let albumCount: Int
    let artists: [Artist]?
    let artistCount: Int
    let playlists: [PlaylistSummary]?
    let playlistCount: Int

    private enum CodingKeys: String, CodingKey {
        case songs, songCount, albums, albumCount, artists, artistCount, playlists, playlistCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songs = try? container.decodeIfPresent([Track].self, forKey: .songs)
        songCount = (try? container.decode(Int.self, forKey: .songCount)) ?? songs?.count ?? 0
        albums = try? container.decodeIfPresent([Album].self, forKey: .albums)
        albumCount = (try? container.decode(Int.self, forKey: .albumCount)) ?? albums?.count ?? 0
        artists = try? container.decodeIfPresent([Artist].self, forKey: .artists)
        artistCount = (try? container.decode(Int.self, forKey: .artistCount)) ?? artists?.count ?? 0
        playlists = try? container.decodeIfPresent([PlaylistSummary].self, forKey: .playlists)
        playlistCount = (try? container.decode(Int.self, forKey: .playlistCount)) ?? playlists?.count ?? 0
    }
}

struct SearchResponse: Decodable {
    let code: Int
    let result: SearchResult?
}

struct PersonalizedResponse: Decodable {
    let code: Int
    let result: [PlaylistSummary]
}

struct ToplistResponse: Decodable {
    let code: Int
    let list: [PlaylistSummary]
}

struct PlaylistResponse: Decodable {
    let code: Int
    let playlist: PlaylistDetail?
}

struct SongDetailResponse: Decodable {
    let code: Int
    let songs: [Track]
}

struct SongURLResponse: Decodable {
    let code: Int
    let data: [SongURLItem]
}

struct SongURLItem: Decodable {
    let id: Int64
    let url: String?
    let br: Int64
    let fee: Int
    let time: Int64
    let level: String?
    let freeTrialInfo: FreeTrialInfo?
    let freeTrialPrivilege: FreeTrialPrivilege?

    var isTrial: Bool {
        if url?.isEmpty != false { return true }
        if freeTrialInfo != nil { return true }
        if (freeTrialPrivilege?.cannotListenReason ?? 0) != 0 { return true }
        return (1...60_000).contains(time)
    }
}

struct FreeTrialInfo: Decodable {
    let start: Int64
    let end: Int64
}

struct FreeTrialPrivilege: Decodable {
    let cannotListenReason: Int?
}

struct LyricContent: Decodable {
    let lyric: String?
}

struct LyricResponse: Decodable {
    let code: Int
    let lrc: LyricContent?
    let tlyric: LyricContent?
    let yrc: LyricContent?
    let ytlrc: LyricContent?
    let nolyric: Bool?
}

struct UserProfile: Decodable, Identifiable, Hashable {
    let userId: Int64
    let nickname: String
    let avatarUrl: String
    let signature: String

    var id: Int64 { userId }

    private enum CodingKeys: String, CodingKey {
        case userId, nickname, avatarUrl, signature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? container.decode(Int64.self, forKey: .userId)) ?? 0
        nickname = (try? container.decode(String.self, forKey: .nickname)) ?? ""
        avatarUrl = (try? container.decode(String.self, forKey: .avatarUrl)) ?? ""
        signature = (try? container.decode(String.self, forKey: .signature)) ?? ""
    }

    var avatarURL: URL? {
        guard !avatarUrl.isEmpty else { return nil }
        return URL(string: avatarUrl)
    }
}

struct AccountResponse: Decodable {
    let code: Int
    let profile: UserProfile?
}

struct QRKeyResponse: Decodable {
    let code: Int
    let unikey: String
}

struct QRCheckResponse: Decodable {
    let code: Int
    let message: String?
}

enum QRLoginTransport: Hashable {
    case desktop
    case web
}

struct QRLoginSession: Hashable {
    let key: String
    let transport: QRLoginTransport
}

struct EmptyResponse: Decodable {
    let code: Int?
}

struct UserPlaylist: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let cover: String
    let playCount: Int64
    let trackCount: Int
    let userId: Int64
    let specialType: Int
    let top: Bool
    let creator: PlaylistCreator?

    private enum CodingKeys: String, CodingKey {
        case id, name, coverImgUrl, playCount, trackCount, userId, specialType, top, creator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "未命名歌单"
        cover = (try? container.decode(String.self, forKey: .coverImgUrl)) ?? ""
        playCount = (try? container.decode(Int64.self, forKey: .playCount)) ?? 0
        trackCount = (try? container.decode(Int.self, forKey: .trackCount)) ?? 0
        userId = (try? container.decode(Int64.self, forKey: .userId)) ?? 0
        specialType = (try? container.decode(Int.self, forKey: .specialType)) ?? 0
        top = (try? container.decode(Bool.self, forKey: .top)) ?? false
        creator = try? container.decodeIfPresent(PlaylistCreator.self, forKey: .creator)
    }

    var coverURL: URL? { URL(string: cover) }
    var isLikedPlaylist: Bool { specialType == 5 }
    var route: PlaylistRoute { PlaylistRoute(id: id, title: name, cover: cover) }
}

struct UserPlaylistsResponse: Decodable {
    let code: Int
    let playlist: [UserPlaylist]
}

struct UserSubcount: Decodable {
    let code: Int
    let artistCount: Int
    let mvCount: Int
    let createdPlaylistCount: Int
    let subPlaylistCount: Int

    var playlistCount: Int { createdPlaylistCount + subPlaylistCount }
}

struct AlbumShelfItem: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String
    let artists: [Artist]
    let size: Int
    let subTime: Int64

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, artists, size, subTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "未知专辑"
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        artists = (try? container.decode([Artist].self, forKey: .artists)) ?? []
        size = (try? container.decode(Int.self, forKey: .size)) ?? 0
        subTime = (try? container.decode(Int64.self, forKey: .subTime)) ?? 0
    }

    var coverURL: URL? { URL(string: picUrl) }
    var album: Album {
        Album(id: id, name: name, picUrl: picUrl, artists: artists)
    }
}

struct AlbumSublistResponse: Decodable {
    let code: Int
    let data: [AlbumShelfItem]
}

struct ArtistDetail: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let cover: String
    let avatar: String
    let briefDesc: String
    let albumSize: Int
    let musicSize: Int
    let alias: [String]
    let identifyTag: [String]
    let trans: String

    private enum CodingKeys: String, CodingKey {
        case id, name, cover, avatar, briefDesc, albumSize, musicSize, alias, identifyTag, trans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        cover = (try? container.decode(String.self, forKey: .cover)) ?? ""
        avatar = (try? container.decode(String.self, forKey: .avatar)) ?? ""
        briefDesc = (try? container.decode(String.self, forKey: .briefDesc)) ?? ""
        albumSize = (try? container.decode(Int.self, forKey: .albumSize)) ?? 0
        musicSize = (try? container.decode(Int.self, forKey: .musicSize)) ?? 0
        alias = (try? container.decode([String].self, forKey: .alias)) ?? []
        identifyTag = (try? container.decode([String].self, forKey: .identifyTag)) ?? []
        trans = (try? container.decode(String.self, forKey: .trans)) ?? ""
    }

    var imageURL: URL? {
        let value = cover.isEmpty ? avatar : cover
        return value.isEmpty ? nil : URL(string: value)
    }
}

struct ArtistDetailData: Decodable {
    let artist: ArtistDetail?
}

struct ArtistDetailEnvelope: Decodable {
    let code: Int
    let data: ArtistDetailData?
}

struct ArtistAlbum: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String
    let publishTime: Int64
    let size: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, publishTime, size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "未知专辑"
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        publishTime = (try? container.decode(Int64.self, forKey: .publishTime)) ?? 0
        size = (try? container.decode(Int.self, forKey: .size)) ?? 0
    }

    var coverURL: URL? { URL(string: picUrl) }
    var album: Album { Album(id: id, name: name, picUrl: picUrl) }
}

struct ArtistAlbumsResponse: Decodable {
    let code: Int
    let hotAlbums: [ArtistAlbum]
    let more: Bool
}

struct ArtistSongsResponse: Decodable {
    let code: Int
    let songs: [Track]
    let more: Bool?
}

struct AlbumDetail: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String
    let description: String?
    let artists: [Artist]

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, description, artists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? "未知专辑"
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        artists = (try? container.decode([Artist].self, forKey: .artists)) ?? []
    }

    var coverURL: URL? { URL(string: picUrl) }
    var artistText: String {
        let value = artists.map(\.name).filter { !$0.isEmpty }.joined(separator: " / ")
        return value.isEmpty ? "未知歌手" : value
    }
}

struct AlbumDetailResponse: Decodable {
    let code: Int
    let album: AlbumDetail?
    let songs: [Track]
}

struct LikedSongIDsResponse: Decodable {
    let code: Int
    let ids: [Int64]
}

struct LikeSongResponse: Decodable {
    let code: Int
    let playlistId: Int64?
}

struct ListeningRecord: Decodable, Identifiable {
    let playCount: Int
    let score: Int
    let song: Track?

    var id: Int64 { song?.id ?? Int64(playCount + score) }
}

struct ListeningRankResponse: Decodable {
    let code: Int
    let weekData: [ListeningRecord]
    let allData: [ListeningRecord]

    private enum CodingKeys: String, CodingKey {
        case code, weekData, allData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        weekData = (try? container.decode([ListeningRecord].self, forKey: .weekData)) ?? []
        allData = (try? container.decode([ListeningRecord].self, forKey: .allData)) ?? []
    }
}

struct CommentUser: Decodable, Hashable {
    let userId: Int64
    let nickname: String
    let avatarUrl: String

    private enum CodingKeys: String, CodingKey {
        case userId, nickname, avatarUrl
    }

    init(userId: Int64, nickname: String, avatarUrl: String) {
        self.userId = userId
        self.nickname = nickname
        self.avatarUrl = avatarUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? container.decode(Int64.self, forKey: .userId)) ?? 0
        nickname = (try? container.decode(String.self, forKey: .nickname)) ?? "网易云用户"
        avatarUrl = (try? container.decode(String.self, forKey: .avatarUrl)) ?? ""
    }

    var avatarURL: URL? { avatarUrl.isEmpty ? nil : URL(string: avatarUrl) }
}

struct CommentItem: Decodable, Identifiable {
    let commentId: Int64
    let user: CommentUser
    let content: String
    let time: Int64
    let timeStr: String?
    var likedCount: Int
    var liked: Bool
    let replyCount: Int
    let beReplied: [RepliedComment]?
    let parentCommentId: Int64?

    var id: Int64 { commentId }

    private enum CodingKeys: String, CodingKey {
        case commentId, user, content, time, timeStr, likedCount, liked, replyCount
        case beReplied, parentCommentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commentId = (try? container.decode(Int64.self, forKey: .commentId)) ?? 0
        user = (try? container.decode(CommentUser.self, forKey: .user)) ?? CommentUser.empty
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        time = (try? container.decode(Int64.self, forKey: .time)) ?? 0
        timeStr = try? container.decodeIfPresent(String.self, forKey: .timeStr)
        likedCount = (try? container.decode(Int.self, forKey: .likedCount)) ?? 0
        liked = (try? container.decode(Bool.self, forKey: .liked)) ?? false
        replyCount = (try? container.decode(Int.self, forKey: .replyCount)) ?? 0
        beReplied = try? container.decodeIfPresent([RepliedComment].self, forKey: .beReplied)
        parentCommentId = try? container.decodeIfPresent(Int64.self, forKey: .parentCommentId)
    }
}

extension CommentUser {
    static let empty = CommentUser()
}

extension CommentUser {
    init() {
        self.init(userId: 0, nickname: "网易云用户", avatarUrl: "")
    }
}

struct CommentsData: Decodable {
    let comments: [CommentItem]
    let totalCount: Int
    let hasMore: Bool
    let cursor: String?
}

struct CommentsEnvelope: Decodable {
    let code: Int
    let data: CommentsData?
}

struct HotSearchItem: Decodable, Identifiable {
    let searchWord: String
    let score: Int
    let content: String

    var id: String { searchWord }

    private enum CodingKeys: String, CodingKey {
        case searchWord, score, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        searchWord = (try? container.decode(String.self, forKey: .searchWord)) ?? ""
        score = (try? container.decode(Int.self, forKey: .score)) ?? 0
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
    }
}

struct HotSearchEnvelope: Decodable {
    let code: Int
    let data: [HotSearchItem]
}

struct PlaylistRoute: Hashable, Identifiable {
    let id: Int64
    let title: String
    let cover: String?

    init(id: Int64, title: String, cover: String? = nil) {
        self.id = id
        self.title = title
        self.cover = cover
    }

    init(summary: PlaylistSummary) {
        self.init(id: summary.id, title: summary.name, cover: summary.cover)
    }

    init(userPlaylist: UserPlaylist) {
        self.init(id: userPlaylist.id, title: userPlaylist.name, cover: userPlaylist.cover)
    }
}

struct ArtistRoute: Hashable, Identifiable {
    let id: Int64
    let title: String
    let avatar: String?

    init(id: Int64, title: String, avatar: String? = nil) {
        self.id = id
        self.title = title
        self.avatar = avatar
    }

    init(artist: Artist) {
        self.init(id: artist.id, title: artist.name, avatar: artist.picUrl)
    }
}

struct AlbumRoute: Hashable, Identifiable {
    let id: Int64
    let title: String
    let cover: String?

    init(id: Int64, title: String, cover: String? = nil) {
        self.id = id
        self.title = title
        self.cover = cover
    }

    init(album: Album) {
        self.init(id: album.id, title: album.name, cover: album.picUrl)
    }

    init(artistAlbum: ArtistAlbum) {
        self.init(id: artistAlbum.id, title: artistAlbum.name, cover: artistAlbum.picUrl)
    }

    init(shelfItem: AlbumShelfItem) {
        self.init(id: shelfItem.id, title: shelfItem.name, cover: shelfItem.picUrl)
    }
}