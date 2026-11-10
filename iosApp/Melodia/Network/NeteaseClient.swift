import Foundation

enum NeteaseError: LocalizedError {
    case network(String)
    case server(Int, String)
    case invalidResponse
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .server(let code, let message):
            if let friendly = NeteaseError.friendlyMessage(for: code) {
                return friendly
            }
            return message.isEmpty ? "网易云接口错误（\(code)）" : message
        case .invalidResponse:
            return "服务器返回了无法解析的数据"
        case .unavailable(let message):
            return message
        }
    }

    static func friendlyMessage(for code: Int) -> String? {
        switch code {
        case 301:
            return "需要登录后才能使用此功能"
        case 250:
            return "登录状态已失效，请重新登录"
        case 8821:
            return "网易云提示客户端版本过低。已切换到桌面协议，若仍失败请使用 Cookie 登录。"
        case 800:
            return "二维码已过期，请刷新后重试"
        case 803:
            return "授权成功"
        default:
            return nil
        }
    }
}

enum SearchType: Int {
    case song = 1
    case album = 10
    case artist = 100
    case playlist = 1000
}

actor NeteaseClient {
    static let shared = NeteaseClient()

    private struct RawResponse {
        let data: Data
        let response: HTTPURLResponse
        let url: URL
    }

    private enum CookieIdentity {
        case desktop
        case web
    }

    private var session: URLSession
    private let decoder = JSONDecoder()
    private var cookies: String
    private let deviceId = NeteaseCrypto.md5("Apple_iPhone15,2_D73AP")

    private let eapiHost = "https://interface.music.163.com"
    private let webHost = "https://music.163.com"
    private let cookieKey = "melodia.netease.cookies"
    private let desktopAppVersion = "3.1.23.204814"
    private let desktopOSVersion = "Microsoft-Windows-10-Professional-build-10512-64bit"
    private let desktopUserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) NeteaseMusicDesktop/3.1.23.204814 Chrome/91.0.4472.164 Electron/13.6.9 Safari/537.36"

    private var xeapiKeyState: XeapiKeyState?
    private let xeapiHost = "https://interface3.music.163.com"
    private let xeapiAppVersion = "9.5.61"
    private let xeapiOSVersion = "14"
    private let xeapiUserAgent = "NeteaseMusic/9.5.61.260802021928(9005061);Dalvik/2.1.0 (Linux; U; Android 14; Pixel 7)"

    init() {
        let storedTimeout = UserDefaults.standard.double(forKey: MelodiaSettings.requestTimeoutKey)
        let timeout = storedTimeout > 0 ? storedTimeout : MelodiaSettings.defaultRequestTimeout
        session = Self.makeSession(timeout: timeout)
        cookies = UserDefaults.standard.string(forKey: cookieKey) ?? ""
    }

    func setRequestTimeout(_ seconds: Double) {
        let timeout = max(5, seconds)
        UserDefaults.standard.set(timeout, forKey: MelodiaSettings.requestTimeoutKey)
        let previous = session
        session = Self.makeSession(timeout: timeout)
        previous.finishTasksAndInvalidate()
    }

    private static func makeSession(timeout: Double) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = max(timeout * 2, timeout + 10)
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        return URLSession(configuration: configuration)
    }

    func loggedIn() -> Bool {
        cookieValue(named: "MUSIC_U")?.isEmpty == false
    }

    func cookieSnapshot() -> String {
        cookies
    }

    func importCookie(_ value: String) {
        replaceCookies(with: value)
    }

    func logout() async {
        let _: EmptyResponse? = try? await postEAPI("/eapi/logout", payload: [:])
        cookies = ""
        UserDefaults.standard.removeObject(forKey: cookieKey)
    }

    func personalizedPlaylists() async throws -> [PlaylistSummary] {
        let response: PersonalizedResponse = try await postEAPI(
            "/eapi/personalized/playlist",
            payload: ["limit": 30]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.result
    }

    func toplists() async throws -> [PlaylistSummary] {
        let response: ToplistResponse = try await postEAPI("/eapi/toplist/detail", payload: [:])
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.list
    }

    func dailyRecommendations() async throws -> [Track] {
        let response: DailySongsEnvelope = try await postEAPI(
            "/eapi/v3/discovery/recommend/songs",
            payload: [:]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.dailySongs ?? []
    }

    func playlist(id: Int64) async throws -> PlaylistDetail {
        let response: PlaylistResponse = try await postEAPI(
            "/eapi/v6/playlist/detail",
            payload: ["id": id, "n": 100_000, "s": 8]
        )
        guard response.code == 200, let playlist = response.playlist else {
            throw NeteaseError.server(response.code, "歌单不存在或不可访问")
        }
        return playlist
    }

    func songDetails(ids: [Int64]) async throws -> [Track] {
        guard !ids.isEmpty else { return [] }
        let objects = ids.map { ["id": $0] }
        let payloadData = try JSONSerialization.data(withJSONObject: objects, options: [])
        let value = String(data: payloadData, encoding: .utf8) ?? "[]"
        let response: SongDetailResponse = try await postEAPI(
            "/eapi/v3/song/detail",
            payload: ["c": value]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.songs
    }

    func search(
        keyword: String,
        type: SearchType,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> SearchResult {
        let response: SearchResponse = try await postEAPI(
            "/eapi/cloudsearch/pc",
            payload: ["s": keyword, "type": type.rawValue, "limit": limit, "offset": offset]
        )
        guard response.code == 200, let result = response.result else {
            throw NeteaseError.server(response.code, "")
        }
        return result
    }

    func searchSongs(keyword: String, limit: Int = 30, offset: Int = 0) async throws -> [Track] {
        let result = try await search(keyword: keyword, type: .song, limit: limit, offset: offset)
        return result.songs ?? []
    }

    func hotSearches() async throws -> [String] {
        let response: HotSearchEnvelope = try await postEAPI("/eapi/hotsearchlist/get", payload: [:])
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data
            .map(\.searchWord)
            .filter { !$0.isEmpty }
    }

    func songURL(id: Int64, level: String = "exhigh") async throws -> URL {
        let ids = "[\(id)]"
        let response: SongURLResponse = try await postEAPI(
            "/eapi/song/enhance/player/url/v1",
            payload: ["ids": ids, "level": level, "encodeType": "flac"]
        )
        guard response.code == 200, let item = response.data.first else {
            throw NeteaseError.server(response.code, "无法获取播放地址")
        }
        guard let rawURL = item.url, !rawURL.isEmpty, let url = secureURL(rawURL) else {
            throw NeteaseError.unavailable("该歌曲暂无版权或当前账号无播放权限")
        }
        return url
    }

    func lyrics(songID: Int64) async throws -> LyricResponse {
        let response: LyricResponse = try await postEAPI(
            "/eapi/song/lyric/v1",
            payload: [
                "id": songID,
                "cp": false,
                "tv": -1,
                "lv": -1,
                "rv": -1,
                "kv": -1,
                "yv": 99,
                "ytv": -1,
                "yrv": -1
            ]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func account() async throws -> UserProfile? {
        let response: AccountResponse = try await postEAPI("/eapi/nuser/account/get", payload: [:])
        guard response.code == 200 else { return nil }
        return response.profile
    }

    func userPlaylists(uid: Int64) async throws -> [UserPlaylist] {
        let response: UserPlaylistsResponse = try await postEAPI(
            "/eapi/user/playlist",
            payload: ["uid": uid, "limit": 1000, "offset": 0, "includeTop": true]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.playlist
    }

    func userSubcount() async throws -> UserSubcount {
        let response: UserSubcount = try await postWEAPI(
            "/weapi/subcount",
            payload: [:],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func subscribedAlbums() async throws -> [AlbumShelfItem] {
        let response: AlbumSublistResponse = try await postEAPI(
            "/eapi/album/sublist",
            payload: ["limit": 1000, "offset": 0, "total": true]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data
    }

    func listeningRank(uid: Int64, type: Int) async throws -> ListeningRankResponse {
        let response: ListeningRankResponse = try await postWEAPI(
            "/weapi/v1/play/record",
            payload: ["uid": uid, "type": type],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func likedSongIDs(uid: Int64) async throws -> [Int64] {
        let response: LikedSongIDsResponse = try await postEAPI(
            "/eapi/song/like/get",
            payload: ["uid": uid]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.ids
    }

    func likeSong(trackID: Int64, like: Bool) async throws {
        let response: LikeSongResponse = try await postEAPI(
            "/eapi/song/like",
            payload: ["trackId": trackID, "like": like]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
    }

    func artistDetail(id: Int64) async throws -> ArtistDetail? {
        let response: ArtistDetailEnvelope = try await postEAPI(
            "/eapi/artist/head/info/get",
            payload: ["id": id]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.artist
    }

    func artistSongs(id: Int64, limit: Int = 100) async throws -> [Track] {
        do {
            let response: ArtistSongsResponse = try await postEAPI(
                "/eapi/v1/artist/songs",
                payload: [
                    "id": id,
                    "private_cloud": "true",
                    "work_type": 1,
                    "order": "hot",
                    "offset": 0,
                    "limit": limit
                ]
            )
            guard response.code == 200 else {
                throw NeteaseError.server(response.code, "")
            }
            return response.songs
        } catch {
            let response: ArtistSongsResponse = try await postWEAPI(
                "/weapi/artist/top/song",
                payload: ["id": id],
                includeCookies: true
            )
            guard response.code == 200 else {
                throw NeteaseError.server(response.code, "")
            }
            return response.songs
        }
    }

    func artistAlbums(id: Int64, limit: Int = 30, offset: Int = 0) async throws -> [ArtistAlbum] {
        let response: ArtistAlbumsResponse = try await postWEAPI(
            "/weapi/artist/albums/\(id)",
            payload: ["limit": limit, "offset": offset, "total": true],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.hotAlbums
    }

    func albumDetail(id: Int64) async throws -> AlbumDetailResponse {
        let response: AlbumDetailResponse = try await postWEAPI(
            "/weapi/v1/album/\(id)",
            payload: [:],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func comments(
        threadID: String,
        page: Int = 1,
        pageSize: Int = 30,
        sortType: Int = 99
    ) async throws -> CommentsData {
        let cursor: String
        switch sortType {
        case 2:
            cursor = "normalHot#\(max(0, (page - 1) * pageSize))"
        case 3:
            cursor = page <= 1 ? "0" : "\(max(0, (page - 1) * pageSize))"
        default:
            cursor = "\(max(0, (page - 1) * pageSize))"
        }

        let response: CommentsEnvelope = try await postWEAPI(
            "/weapi/v2/resource/comments",
            payload: [
                "threadId": threadID,
                "pageNo": page,
                "pageSize": pageSize,
                "cursor": cursor,
                "sortType": sortType,
                "showInner": true
            ],
            includeCookies: true
        )
        guard response.code == 200, let data = response.data else {
            throw NeteaseError.server(response.code, "")
        }
        return data
    }

    func songWiki(songID: Int64) async throws -> SongWikiData? {
        let response: SongWikiEnvelope = try await postWEAPI(
            "/weapi/song/play/about/block/page",
            payload: ["songId": songID],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.wiki
    }

    func homeBlockPage(cursor: String = "", refresh: Bool = false) async throws -> HomeBlockPageData {
        let response: HomeBlockEnvelope = try await postEAPI(
            "/eapi/homepage/block/page",
            payload: [
                "cursor": cursor,
                "refresh": refresh
            ]
        )
        guard response.code == 200, let data = response.data else {
            throw NeteaseError.server(response.code, "")
        }
        return data
    }

    func recentSongs() async throws -> [RecentSongRecord] {
        let response: RecentSongsEnvelope = try await postWEAPI(
            "/weapi/play-record/song/list",
            payload: ["limit": 100],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.list ?? []
    }

    func recentPlaylists() async throws -> [RecentPlaylistRecord] {
        let response: RecentPlaylistsEnvelope = try await postEAPI(
            "/eapi/play-record/playlist/list",
            payload: ["limit": 100]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.list ?? []
    }

    func recentAlbums() async throws -> [RecentAlbumRecord] {
        let response: RecentAlbumsEnvelope = try await postWEAPI(
            "/weapi/play-record/album/list",
            payload: ["limit": 100],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.list ?? []
    }

    func listenTotalDuration() async throws -> Int64 {
        let response: ListenTotalEnvelope = try await postWEAPI(
            "/weapi/content/activity/listen/data/total",
            payload: [:],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.totalDuration ?? 0
    }

    func listenTodaySongs() async throws -> [ListenTodaySong] {
        let response: ListenTodayEnvelope = try await postWEAPI(
            "/weapi/content/activity/listen/data/today/song/play/rank",
            payload: [:],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.songDTOs ?? []
    }

    func listenSongRank(type: String) async throws -> ListenRankData {
        let response: ListenRankEnvelope = try await postWEAPI(
            "/weapi/content/activity/listen/data/song/play/rank",
            payload: ["type": type],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data ?? ListenRankData.empty
    }

    func listenYearReport() async throws -> [ListenYearItem] {
        let response: ListenYearEnvelope = try await postWEAPI(
            "/weapi/content/activity/listen/data/year/report",
            payload: [:],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.data?.yearItems ?? []
    }

    func messageNotices(time: Int64 = -1, limit: Int = 30) async throws -> MessageNoticesEnvelope {
        let response: MessageNoticesEnvelope = try await postWEAPI(
            "/weapi/msg/notices",
            payload: ["time": time, "limit": limit],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func messageComments(uid: Int64, beforeTime: String = "-1", limit: Int = 30) async throws -> MessageCommentsEnvelope {
        let response: MessageCommentsEnvelope = try await postWEAPI(
            "/weapi/v1/user/comments/\(uid)",
            payload: [
                "uid": uid,
                "beforeTime": beforeTime,
                "limit": limit,
                "total": "true"
            ],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func messageForwards(offset: Int = 0, limit: Int = 30) async throws -> MessageForwardsEnvelope {
        let response: MessageForwardsEnvelope = try await postWEAPI(
            "/weapi/forwards/get",
            payload: [
                "offset": offset,
                "limit": limit,
                "total": "true"
            ],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response
    }

    func commentFloors(
        parentCommentID: Int64,
        threadID: String,
        time: Int64 = -1,
        limit: Int = 20
    ) async throws -> CommentFloorData {
        let response: CommentFloorEnvelope = try await postWEAPI(
            "/weapi/resource/comment/floor/get",
            payload: [
                "parentCommentId": parentCommentID,
                "threadId": threadID,
                "time": time,
                "limit": limit
            ],
            includeCookies: true
        )
        guard response.code == 200, let data = response.data else {
            throw NeteaseError.server(response.code, "")
        }
        return data
    }

    func addComment(threadID: String, content: String) async throws -> CommentItem? {
        let data = try await postXEAPI(
            "/xeapi/resource/comments/add",
            fields: [
                ("threadId", threadID),
                ("content", content),
                ("resourceType", "0"),
                ("expressionPicId", "-1"),
                ("bubbleId", "-1")
            ]
        )
        let response = try decoder.decode(CommentActionEnvelope.self, from: data)
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, response.message ?? "")
        }
        return response.comment
    }

    func replyComment(threadID: String, commentID: Int64, content: String) async throws -> CommentItem? {
        let data = try await postXEAPI(
            "/xeapi/v1/resource/comments/reply",
            fields: [
                ("threadId", threadID),
                ("commentId", "\(commentID)"),
                ("content", content),
                ("resourceType", "0")
            ]
        )
        let response = try decoder.decode(CommentActionEnvelope.self, from: data)
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, response.message ?? "")
        }
        return response.comment
    }

    func likeComment(threadID: String, commentID: Int64, like: Bool) async throws {
        let response: EmptyResponse = try await postWEAPI(
            like ? "/weapi/v1/comment/like" : "/weapi/v1/comment/unlike",
            payload: ["threadId": threadID, "commentId": commentID],
            includeCookies: true
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code ?? 0, "")
        }
    }

    func similarSongs(id: Int64) async throws -> [Track] {
        let response: SimilarSongsResponse = try await postEAPI(
            "/eapi/v1/discovery/simiSong",
            payload: ["songid": "\(id)"]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.songs
    }

    func qrKey() async throws -> QRLoginSession {
        do {
            let response: QRKeyResponse = try await postEAPI(
                "/eapi/login/qrcode/unikey",
                payload: ["type": 1]
            )
            if response.code == 200, !response.unikey.isEmpty {
                return QRLoginSession(key: response.unikey, transport: .desktop)
            }
        } catch {
            // Fall through to the legacy endpoint.
        }

        let response: QRKeyResponse = try await postWEAPI(
            "/weapi/login/qrcode/unikey",
            payload: ["type": 1],
            includeCookies: false
        )
        guard response.code == 200, !response.unikey.isEmpty else {
            throw NeteaseError.server(response.code, "无法生成登录二维码")
        }
        return QRLoginSession(key: response.unikey, transport: .web)
    }

    func qrStatus(session: QRLoginSession) async throws -> QRCheckResponse {
        let raw: RawResponse
        switch session.transport {
        case .desktop:
            raw = try await postEAPIRaw(
                "/eapi/login/qrcode/client/login",
                payload: ["key": session.key, "type": 1]
            )
        case .web:
            raw = try await postWEAPIRaw(
                "/weapi/login/qrcode/client/login",
                payload: ["key": session.key, "type": 1],
                includeCookies: false
            )
        }

        let result = try decoder.decode(QRCheckResponse.self, from: raw.data)
        if result.code == 803 {
            let pairs = cookiePairs(from: raw.response)
            if !pairs.isEmpty {
                mergeCookies(pairs)
            }
        }
        return result
    }

    private func postXEAPI(_ path: String, fields: [(String, String)]) async throws -> Data {
        let state = try await xeapiKey()
        return try await sendXEAPI(path, fields: fields, state: state)
    }

    private func xeapiKey() async throws -> XeapiKeyState {
        if let xeapiKeyState {
            return xeapiKeyState
        }
        let state = try await fetchXeapiKey()
        xeapiKeyState = state
        return state
    }

    private func fetchXeapiKey() async throws -> XeapiKeyState {
        guard let url = URL(string: "https://interface.music.163.com/api/gorilla/anti/crawler/security/key/get") else {
            throw NeteaseError.invalidResponse
        }
        let nonce = (0..<16).map { _ in String(Int.random(in: 0...9)) }.joined()
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let signature = XeapiCrypto.sign(timestamp: timestamp, nonce: nonce)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(xeapiUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("deviceId=\(deviceId)", forHTTPHeaderField: "Cookie")
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "appVersion": "9.5.61",
            "currentKeyVersion": "",
            "deviceId": deviceId,
            "nonce": nonce,
            "os": "android",
            "requestType": "active",
            "signature": signature,
            "t1": "",
            "t2": "",
            "timestamp": timestamp,
            "uid": ""
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NeteaseError.network("获取评论加密密钥失败")
        }
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = object["code"] as? Int,
            code == 200,
            let payload = object["data"] as? [String: Any],
            let encrypted = payload["encryptedData"] as? String,
            !encrypted.isEmpty
        else {
            throw NeteaseError.network("获取评论加密密钥失败")
        }

        if let responseSignature = payload["signature"] as? String,
           !responseSignature.isEmpty,
           let responseTimestamp = payload["timestamp"] as? String,
           XeapiCrypto.sign(timestamp: responseTimestamp, nonce: nonce) != responseSignature {
            throw NeteaseError.network("评论加密密钥校验失败")
        }

        return try XeapiCrypto.decryptPublicKeyResponse(encrypted)
    }

    private func sendXEAPI(
        _ path: String,
        fields: [(String, String)],
        state: XeapiKeyState
    ) async throws -> Data {
        guard let url = URL(string: xeapiHost + path) else {
            throw NeteaseError.invalidResponse
        }
        let apiPath = path.replacingOccurrences(of: "/xeapi/", with: "/api/")
        let encrypted = try XeapiCrypto.assembleRequest(path: apiPath, fields: fields, state: state)
        let buildVersion = String(Int(Date().timeIntervalSince1970))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.httpBody = formBody([
            "B": encrypted.b,
            "S": encrypted.s,
            "R": encrypted.r
        ])
        request.setValue(xeapiUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("ENCRYPTED", forHTTPHeaderField: "X-Client-Enc-State")
        request.setValue("true", forHTTPHeaderField: "x-aeapi")
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "content-type")
        request.setValue(deviceId, forHTTPHeaderField: "x-deviceid")
        request.setValue("android", forHTTPHeaderField: "x-os")
        request.setValue(xeapiOSVersion, forHTTPHeaderField: "x-osver")
        request.setValue(xeapiAppVersion, forHTTPHeaderField: "x-appver")
        request.setValue(deviceId, forHTTPHeaderField: "x-sdeviceid")
        request.setValue(buildVersion, forHTTPHeaderField: "x-buildver")
        if let musicU = cookieValue(named: "MUSIC_U"), !musicU.isEmpty {
            request.setValue(musicU, forHTTPHeaderField: "x-music-u")
        }

        var cookieParts = [
            "os=android",
            "osver=\(xeapiOSVersion)",
            "appver=\(xeapiAppVersion)",
            "deviceId=\(deviceId)",
            "sDeviceId=\(deviceId)",
            "buildver=\(buildVersion)"
        ]
        let stored = cookies.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty {
            cookieParts.append(stored)
        }
        request.setValue(cookieParts.joined(separator: "; "), forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NeteaseError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NeteaseError.server(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
        return try XeapiCrypto.decryptResponseBody(data)
    }

    private func postEAPI<T: Decodable>(
        _ path: String,
        payload: [String: Any]
    ) async throws -> T {
        let raw = try await postEAPIRaw(path, payload: payload)
        return try decoder.decode(T.self, from: raw.data)
    }

    private func postEAPIRaw(
        _ path: String,
        payload: [String: Any]
    ) async throws -> RawResponse {
        var root = payload
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let requestID = "\(now)_\(Int.random(in: 1000...9999))"
        root["header"] = [
            "osver": desktopOSVersion,
            "deviceId": deviceId,
            "os": "pc",
            "appver": desktopAppVersion,
            "versioncode": "140",
            "mobilename": "",
            "buildver": String(now / 1000),
            "resolution": "1920x1080",
            "requestId": requestID,
            "channel": "netease",
            "__csrf": csrfToken()
        ]
        root["e_r"] = false

        let json = try jsonString(root)
        let apiPath = path.replacingOccurrences(of: "/eapi/", with: "/api/")
        let params = NeteaseCrypto.eapi(apiPath: apiPath, json: json)
        guard !params.isEmpty else {
            throw NeteaseError.invalidResponse
        }

        return try await postForm(
            url: eapiHost + path,
            fields: ["params": params],
            headers: eapiHeaders()
        )
    }

    private func postWEAPI<T: Decodable>(
        _ path: String,
        payload: [String: Any],
        includeCookies: Bool
    ) async throws -> T {
        let raw = try await postWEAPIRaw(path, payload: payload, includeCookies: includeCookies)
        return try decoder.decode(T.self, from: raw.data)
    }

    private func postWEAPIRaw(
        _ path: String,
        payload: [String: Any],
        includeCookies: Bool
    ) async throws -> RawResponse {
        var root = payload
        root["csrf_token"] = csrfToken()
        root["e_r"] = false
        let json = try jsonString(root)
        let encrypted = NeteaseCrypto.weapi(json: json)
        guard
            let params = encrypted["params"],
            let encSecKey = encrypted["encSecKey"],
            !params.isEmpty,
            encSecKey.count == 256
        else {
            throw NeteaseError.invalidResponse
        }

        var headers = webHeaders()
        if includeCookies {
            headers["Cookie"] = cookieHeader(identity: .web)
        }
        return try await postForm(
            url: webHost + path,
            fields: ["params": params, "encSecKey": encSecKey],
            headers: headers
        )
    }

    private func postForm(
        url urlString: String,
        fields: [String: String],
        headers: [String: String]
    ) async throws -> RawResponse {
        guard let url = URL(string: urlString) else {
            throw NeteaseError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = formBody(fields)
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NeteaseError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw NeteaseError.server(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
            }
            return RawResponse(data: data, response: http, url: url)
        } catch let error as NeteaseError {
            throw error
        } catch {
            throw NeteaseError.network(error.localizedDescription)
        }
    }

    private func eapiHeaders() -> [String: String] {
        [
            "User-Agent": desktopUserAgent,
            "Cookie": cookieHeader(identity: .desktop)
        ]
    }

    private func webHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://music.163.com"
        ]
    }

    private func cookieHeader(identity: CookieIdentity) -> String {
        let identityKeys: Set<String> = [
            "os", "osver", "appver", "versioncode", "mobilename", "buildver",
            "resolution", "requestid", "channel", "deviceid"
        ]
        var pairs = cookies
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { pair in
                guard let equals = pair.firstIndex(of: "=") else { return false }
                let key = String(pair[..<equals]).lowercased()
                return !identityKeys.contains(key)
            }

        let now = Date()
        let milliseconds = Int64(now.timeIntervalSince1970 * 1000)
        switch identity {
        case .desktop:
            pairs.append("os=pc")
            pairs.append("osver=\(desktopOSVersion)")
            pairs.append("appver=\(desktopAppVersion)")
            pairs.append("versioncode=140")
            pairs.append("mobilename=")
            pairs.append("buildver=\(Int64(now.timeIntervalSince1970))")
            pairs.append("resolution=1920x1080")
            pairs.append("channel=netease")
            pairs.append("requestId=\(milliseconds)_\(Int.random(in: 1000...9999))")
            pairs.append("deviceId=\(deviceId)")
        case .web:
            pairs.append("os=pc")
            pairs.append("osver=\(desktopOSVersion)")
            pairs.append("appver=\(desktopAppVersion)")
            pairs.append("versioncode=140")
        }
        return pairs.joined(separator: "; ")
    }

    private func cookieValue(named name: String) -> String? {
        for pair in cookies.split(separator: ";") {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            if String(trimmed[..<equals]) == name {
                return String(trimmed[trimmed.index(after: equals)...])
            }
        }
        return nil
    }

    private func csrfToken() -> String {
        cookieValue(named: "__csrf") ?? ""
    }

    private func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let value = fields
            .map { pair -> String in
                let encodedKey = pair.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? pair.key
                let encodedValue = pair.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? pair.value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(value.utf8)
    }

    private func jsonString(_ object: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw NeteaseError.invalidResponse
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        guard let value = String(data: data, encoding: .utf8) else {
            throw NeteaseError.invalidResponse
        }
        return value
    }

    private func cookiePairs(from response: HTTPURLResponse) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "(?:^|[,\\n])\\s*([^=;,\\s]+)=([^;,]*)")
        let ignored: Set<String> = [
            "path", "expires", "max-age", "domain", "secure", "httponly", "samesite"
        ]
        var pairs = [String]()
        for (key, value) in response.allHeaderFields {
            guard
                let name = key as? String,
                name.caseInsensitiveCompare("Set-Cookie") == .orderedSame
            else { continue }
            let headers: [String]
            if let header = value as? String {
                headers = [header]
            } else if let values = value as? [String] {
                headers = values
            } else {
                continue
            }
            for header in headers {
                let range = NSRange(header.startIndex..<header.endIndex, in: header)
                for match in pattern.matches(in: header, range: range) {
                    guard
                        let nameRange = Range(match.range(at: 1), in: header),
                        let valueRange = Range(match.range(at: 2), in: header)
                    else { continue }
                    let cookieName = String(header[nameRange])
                    if ignored.contains(cookieName.lowercased()) { continue }
                    let cookieValue = String(header[valueRange])
                    pairs.append("\(cookieName)=\(cookieValue)")
                }
            }
        }
        return pairs
    }

    private func mergeCookies(_ pairs: [String]) {
        var values = [String: String]()
        for pair in cookies.split(separator: ";") {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            values[String(trimmed[..<equals])] = String(trimmed[trimmed.index(after: equals)...])
        }
        for pair in pairs {
            guard let equals = pair.firstIndex(of: "=") else { continue }
            values[String(pair[..<equals])] = String(pair[pair.index(after: equals)...])
        }
        replaceCookies(with: values.map { "\($0.key)=\($0.value)" }.joined(separator: "; "))
    }

    private func replaceCookies(with value: String) {
        let normalized = value
            .replacingOccurrences(of: "\n", with: "; ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var values = [String: String]()
        for pair in normalized.split(separator: ";") {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            values[String(trimmed[..<equals])] = String(trimmed[trimmed.index(after: equals)...])
        }
        cookies = values.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        UserDefaults.standard.set(cookies, forKey: cookieKey)
    }

    private func secureURL(_ raw: String) -> URL? {
        if raw.hasPrefix("http://") {
            return URL(string: "https://" + String(raw.dropFirst("http://".count)))
        }
        return URL(string: raw)
    }
}

private struct DailySongsEnvelope: Decodable {
    let code: Int
    let data: DailySongsData?
}

private struct DailySongsData: Decodable {
    let dailySongs: [Track]
}

private struct SimilarSongsResponse: Decodable {
    let code: Int
    let songs: [Track]
}