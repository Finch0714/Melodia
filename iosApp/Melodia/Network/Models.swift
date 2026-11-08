import Foundation

struct Artist: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = try? container.decodeIfPresent(String.self, forKey: .picUrl)
    }
}

struct Album: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let picUrl: String

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = (try? container.decode(String.self, forKey: .picUrl)) ?? ""
    }
}

struct Track: Decodable, Hashable, Identifiable {
    let id: Int64
    let name: String
    let artists: [Artist]
    let album: Album?
    let durationMs: Int64
    let fee: Int

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

struct EmptyResponse: Decodable {
    let code: Int?
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
}
