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
            return message.isEmpty ? "网易云接口错误（\(code)）" : message
        case .invalidResponse:
            return "服务器返回了无法解析的数据"
        case .unavailable(let message):
            return message
        }
    }
}

actor NeteaseClient {
    static let shared = NeteaseClient()

    private struct RawResponse {
        let data: Data
        let response: HTTPURLResponse
        let url: URL
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var cookies: String
    private let deviceId = NeteaseCrypto.md5("Apple_iPhone15,2_D73AP")

    private let eapiHost = "https://interface.music.163.com"
    private let webHost = "https://music.163.com"
    private let cookieKey = "melodia.netease.cookies"

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        session = URLSession(configuration: configuration)
        cookies = UserDefaults.standard.string(forKey: cookieKey) ?? ""
    }

    func loggedIn() -> Bool {
        cookies.contains("MUSIC_U=")
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

    func searchSongs(keyword: String, limit: Int = 30, offset: Int = 0) async throws -> [Track] {
        let response: SearchResponse = try await postEAPI(
            "/eapi/cloudsearch/pc",
            payload: ["s": keyword, "type": 1, "limit": limit, "offset": offset]
        )
        guard response.code == 200 else {
            throw NeteaseError.server(response.code, "")
        }
        return response.result?.songs ?? []
    }

    func songURL(id: Int64) async throws -> URL {
        let ids = "[\(id)]"
        let response: SongURLResponse = try await postEAPI(
            "/eapi/song/enhance/player/url/v1",
            payload: ["ids": ids, "level": "standard", "encodeType": "flac"]
        )
        guard response.code == 200, let item = response.data.first else {
            throw NeteaseError.server(response.code, "无法获取播放地址")
        }
        guard let rawURL = item.url, !rawURL.isEmpty, let url = URL(string: rawURL) else {
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

    func qrKey() async throws -> String {
        let response: QRKeyResponse = try await postWEAPI(
            "/weapi/login/qrcode/unikey",
            payload: ["type": 1],
            includeCookies: false
        )
        guard response.code == 200, !response.unikey.isEmpty else {
            throw NeteaseError.server(response.code, "无法生成登录二维码")
        }
        return response.unikey
    }

    func qrStatus(key: String) async throws -> QRCheckResponse {
        let raw: RawResponse = try await postWEAPIRaw(
            "/weapi/login/qrcode/client/login",
            payload: ["key": key, "type": 1],
            includeCookies: false
        )
        let result = try decoder.decode(QRCheckResponse.self, from: raw.data)
        if result.code == 803 {
            let pairs = cookiePairs(from: raw.response)
            if !pairs.isEmpty {
                mergeCookies(pairs)
            }
        }
        return result
    }

    private func postEAPI<T: Decodable>(
        _ path: String,
        payload: [String: Any]
    ) async throws -> T {
        var root = payload
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        root["header"] = [
            "osver": "17.0",
            "deviceId": deviceId,
            "os": "android",
            "appver": "9.0.90",
            "versioncode": "140",
            "mobilename": "iPhone15,2",
            "buildver": String(now / 1000),
            "resolution": "1920x1080",
            "requestId": "\(now)_\(Int.random(in: 1000...9999))"
        ]
        root["e_r"] = false

        let json = try jsonString(root)
        let apiPath = path.replacingOccurrences(of: "/eapi/", with: "/api/")
        let params = NeteaseCrypto.eapi(apiPath: apiPath, json: json)
        guard !params.isEmpty else {
            throw NeteaseError.invalidResponse
        }

        let raw = try await postForm(
            url: eapiHost + path,
            fields: ["params": params],
            headers: eapiHeaders()
        )
        return try decoder.decode(T.self, from: raw.data)
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
            headers["Cookie"] = cookieHeader(useAndroid: false)
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
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
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
        let userAgent = "NeteaseMusic/9.0.90 (Linux; U; Android 17.0; zh_CN; iPhone15,2)"
        return [
            "User-Agent": userAgent,
            "Cookie": cookieHeader(useAndroid: true)
        ]
    }

    private func webHeaders() -> [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://music.163.com"
        ]
    }

    private func cookieHeader(useAndroid: Bool) -> String {
        var parts = cookies
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("os=") }
        if useAndroid {
            parts.append("os=android")
            parts.append("appver=9.0.90")
            parts.append("osver=17.0")
        } else {
            parts.append("os=pc")
            parts.append("osver=Microsoft-Windows-10-Professional-build-10512-64bit")
            parts.append("appver=3.0.1.201552")
        }
        return parts.joined(separator: "; ")
    }

    private func csrfToken() -> String {
        guard let range = cookies.range(of: "__csrf=") else { return "" }
        let rest = cookies[range.upperBound...]
        return String(rest.prefix { $0 != ";" })
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
                    let cookieValue = String(header[valueRange])
                    if cookieName.caseInsensitiveCompare("Path") == .orderedSame { continue }
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
        cookies = value
            .replacingOccurrences(of: "\n", with: "; ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cookies, forKey: cookieKey)
    }
}

private struct DailySongsEnvelope: Decodable {
    let code: Int
    let data: DailySongsData?
}

private struct DailySongsData: Decodable {
    let dailySongs: [Track]
}
