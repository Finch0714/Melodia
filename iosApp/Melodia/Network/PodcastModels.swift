import Foundation

// MARK: - Podcast domain

struct PodcastCategory: Identifiable, Hashable {
    let id: Int64
    let name: String
}

struct PodcastRadio: Identifiable, Hashable {
    let id: Int64
    let name: String
    let picUrl: String
    let programCount: Int
    let subCount: Int64
    let djName: String
    let recommendText: String
    let lastProgramName: String
    let lastProgramCreateTimeMs: Int64

    var coverURL: URL? { URL(string: picUrl) }

    var metaText: String {
        var parts: [String] = []
        if programCount > 0 { parts.append("\(programCount) 期") }
        let subs = podcastCountText(subCount)
        if !subs.isEmpty { parts.append(subs) }
        return parts.joined(separator: " · ")
    }
}

struct PodcastCategoryGroup: Identifiable, Hashable {
    let categoryId: Int64
    let categoryName: String
    let radios: [PodcastRadio]

    var id: Int64 { categoryId }
}

struct PodcastProgram: Identifiable, Hashable {
    let id: Int64
    let songId: Int64
    let name: String
    let coverUrl: String
    let durationMs: Int64
    let createTimeMs: Int64
    let listenerCount: Int64
    let serialNum: Int
    let radioId: Int64
    let radioName: String
    let djName: String
    let description: String

    var track: Track {
        Track(
            id: songId,
            name: name,
            artists: [Artist(id: 0, name: djName.isEmpty ? radioName : djName)],
            album: Album(id: 0, name: radioName, picUrl: coverUrl),
            durationMs: durationMs
        )
    }

    var sourceText: String {
        let parts = [radioName, djName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return parts.joined(separator: " · ")
    }
}

struct PodcastRadioDetail: Identifiable, Hashable {
    let id: Int64
    let name: String
    let picUrl: String
    let desc: String
    let category: String
    let programCount: Int
    let subCount: Int64
    let djName: String
    let djAvatarUrl: String
    var subscribed: Bool

    var coverURL: URL? { URL(string: picUrl) }
    var djAvatarURL: URL? { URL(string: djAvatarUrl) }
}

struct PodcastProgramPage {
    let items: [PodcastProgram]
    let hasMore: Bool
}

struct PodcastRadioPage {
    let items: [PodcastRadio]
    let hasMore: Bool
}

// MARK: - DTOs

struct PodcastCategoryDTO: Decodable {
    let id: Int64
    let name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case id, name }
}

struct PodcastDjDTO: Decodable {
    let nickname: String?
    let avatarUrl: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try? container.decodeIfPresent(String.self, forKey: .nickname)
        avatarUrl = try? container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }

    private enum CodingKeys: String, CodingKey { case nickname, avatarUrl }
}

struct PodcastRadioDTO: Decodable {
    let id: Int64
    let name: String
    let picUrl: String?
    let desc: String?
    let rcmdtext: String?
    let rcmdText: String?
    let programCount: Int
    let subCount: Int64
    let category: String?
    let dj: PodcastDjDTO?
    let lastProgramName: String?
    let lastProgramCreateTime: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = try? container.decodeIfPresent(String.self, forKey: .picUrl)
        desc = try? container.decodeIfPresent(String.self, forKey: .desc)
        rcmdtext = try? container.decodeIfPresent(String.self, forKey: .rcmdtext)
        rcmdText = try? container.decodeIfPresent(String.self, forKey: .rcmdText)
        programCount = (try? container.decode(Int.self, forKey: .programCount)) ?? 0
        subCount = (try? container.decode(Int64.self, forKey: .subCount)) ?? 0
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        dj = try? container.decodeIfPresent(PodcastDjDTO.self, forKey: .dj)
        lastProgramName = try? container.decodeIfPresent(String.self, forKey: .lastProgramName)
        lastProgramCreateTime = (try? container.decode(Int64.self, forKey: .lastProgramCreateTime)) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, desc, rcmdtext, rcmdText, programCount, subCount
        case category, dj, lastProgramName, lastProgramCreateTime
    }

    var domain: PodcastRadio? {
        guard id > 0, !name.isEmpty else { return nil }
        let picture = picUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !picture.isEmpty else { return nil }
        let recommendation = (rcmdText?.isEmpty == false ? rcmdText : rcmdtext) ?? ""
        return PodcastRadio(
            id: id,
            name: name,
            picUrl: picture,
            programCount: programCount,
            subCount: subCount,
            djName: dj?.nickname ?? "",
            recommendText: podcastFlatten(recommendation),
            lastProgramName: lastProgramName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            lastProgramCreateTimeMs: lastProgramCreateTime
        )
    }
}

struct PodcastMainSongDTO: Decodable {
    let id: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case id }
}

struct PodcastProgramDTO: Decodable {
    let id: Int64
    let name: String
    let coverUrl: String?
    let duration: Int64
    let createTime: Int64
    let listenerCount: Int64
    let serialNum: Int64
    let description: String?
    let mainSong: PodcastMainSongDTO?
    let radio: PodcastRadioDTO?
    let dj: PodcastDjDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        coverUrl = try? container.decodeIfPresent(String.self, forKey: .coverUrl)
        duration = (try? container.decode(Int64.self, forKey: .duration)) ?? 0
        createTime = (try? container.decode(Int64.self, forKey: .createTime)) ?? 0
        listenerCount = (try? container.decode(Int64.self, forKey: .listenerCount)) ?? 0
        serialNum = (try? container.decode(Int64.self, forKey: .serialNum)) ?? 0
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        mainSong = try? container.decodeIfPresent(PodcastMainSongDTO.self, forKey: .mainSong)
        radio = try? container.decodeIfPresent(PodcastRadioDTO.self, forKey: .radio)
        dj = try? container.decodeIfPresent(PodcastDjDTO.self, forKey: .dj)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, coverUrl, duration, createTime, listenerCount, serialNum
        case description, mainSong, radio, dj
    }

    var domain: PodcastProgram? {
        guard id > 0, !name.isEmpty, let songID = mainSong?.id, songID > 0 else { return nil }
        let cover = coverUrl?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? radio?.picUrl?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let cover else { return nil }
        let serial = serialNum > 0 && serialNum <= 100_000 ? Int(serialNum) : 0
        let djName = dj?.nickname?.nilIfEmpty ?? radio?.dj?.nickname ?? ""
        return PodcastProgram(
            id: id,
            songId: songID,
            name: name,
            coverUrl: cover,
            durationMs: duration,
            createTimeMs: createTime,
            listenerCount: listenerCount,
            serialNum: serial,
            radioId: radio?.id ?? 0,
            radioName: radio?.name ?? "",
            djName: djName,
            description: podcastFlatten(description ?? "")
        )
    }
}

struct PodcastCategoryGroupDTO: Decodable {
    let categoryId: Int64
    let categoryName: String
    let radios: [PodcastRadioDTO]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryId = (try? container.decode(Int64.self, forKey: .categoryId)) ?? 0
        categoryName = (try? container.decode(String.self, forKey: .categoryName)) ?? ""
        radios = (try? container.decode([PodcastRadioDTO].self, forKey: .radios)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case categoryId, categoryName, radios }

    var domain: PodcastCategoryGroup? {
        let items = radios.compactMap(\.domain)
        guard categoryId > 0, !categoryName.isEmpty, !items.isEmpty else { return nil }
        return PodcastCategoryGroup(categoryId: categoryId, categoryName: categoryName, radios: items)
    }
}

struct PodcastRadioDetailDTO: Decodable {
    let id: Int64
    let name: String
    let picUrl: String?
    let desc: String?
    let category: String?
    let programCount: Int
    let subCount: Int64
    let dj: PodcastDjDTO?
    let subed: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        picUrl = try? container.decodeIfPresent(String.self, forKey: .picUrl)
        desc = try? container.decodeIfPresent(String.self, forKey: .desc)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        programCount = (try? container.decode(Int.self, forKey: .programCount)) ?? 0
        subCount = (try? container.decode(Int64.self, forKey: .subCount)) ?? 0
        dj = try? container.decodeIfPresent(PodcastDjDTO.self, forKey: .dj)
        subed = (try? container.decode(Bool.self, forKey: .subed)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, picUrl, desc, category, programCount, subCount, dj, subed
    }

    var domain: PodcastRadioDetail? {
        guard id > 0, !name.isEmpty else { return nil }
        return PodcastRadioDetail(
            id: id,
            name: name,
            picUrl: picUrl ?? "",
            desc: podcastFlatten(desc ?? ""),
            category: category ?? "",
            programCount: programCount,
            subCount: subCount,
            djName: dj?.nickname ?? "",
            djAvatarUrl: dj?.avatarUrl ?? "",
            subscribed: subed
        )
    }
}

// MARK: - Response envelopes

struct PodcastCategoriesResponse: Decodable {
    let code: Int
    let categories: [PodcastCategoryDTO]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        categories = (try? container.decode([PodcastCategoryDTO].self, forKey: .categories)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, categories }
}

struct PodcastRecommendProgramsResponse: Decodable {
    let code: Int
    let programs: [PodcastProgramDTO]
    let more: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        programs = (try? container.decode([PodcastProgramDTO].self, forKey: .programs)) ?? []
        more = (try? container.decode(Bool.self, forKey: .more)) ?? false
    }

    private enum CodingKeys: String, CodingKey { case code, programs, more }
}

struct PodcastCategoryGroupsResponse: Decodable {
    let code: Int
    let data: [PodcastCategoryGroupDTO]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = (try? container.decode([PodcastCategoryGroupDTO].self, forKey: .data)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, data }
}

struct PodcastToplistResponse: Decodable {
    let code: Int
    let toplist: [PodcastRadioDTO]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        toplist = (try? container.decode([PodcastRadioDTO].self, forKey: .toplist)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case code, toplist }
}

struct PodcastSubscribedResponse: Decodable {
    let code: Int
    let djRadios: [PodcastRadioDTO]
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        djRadios = (try? container.decode([PodcastRadioDTO].self, forKey: .djRadios)) ?? []
        hasMore = (try? container.decode(Bool.self, forKey: .hasMore)) ?? false
    }

    private enum CodingKeys: String, CodingKey { case code, djRadios, hasMore }
}

struct PodcastCategoryHotResponse: Decodable {
    let code: Int
    let djRadios: [PodcastRadioDTO]
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        djRadios = (try? container.decode([PodcastRadioDTO].self, forKey: .djRadios)) ?? []
        hasMore = (try? container.decode(Bool.self, forKey: .hasMore)) ?? false
    }

    private enum CodingKeys: String, CodingKey { case code, djRadios, hasMore }
}

struct PodcastRadioDetailResponse: Decodable {
    let code: Int
    let data: PodcastRadioDetailDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(PodcastRadioDetailDTO.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case code, data }
}

struct PodcastProgramsResponse: Decodable {
    let code: Int
    let programs: [PodcastProgramDTO]
    let count: Int
    let more: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        programs = (try? container.decode([PodcastProgramDTO].self, forKey: .programs)) ?? []
        count = (try? container.decode(Int.self, forKey: .count)) ?? 0
        more = (try? container.decode(Bool.self, forKey: .more)) ?? false
    }

    private enum CodingKeys: String, CodingKey { case code, programs, count, more }
}

struct PodcastSubscribeResponse: Decodable {
    let code: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case code }
}
// MARK: - Formatting helpers

func podcastFlatten(_ value: String) -> String {
    value
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

func podcastCountText(_ value: Int64) -> String {
    if value >= 100_000_000 {
        return String(format: "%.1f亿", Double(value) / 100_000_000)
    }
    if value >= 10_000 {
        return String(format: "%.1f万", Double(value) / 10_000)
    }
    return value > 0 ? "\(value)" : ""
}

func podcastDurationText(_ milliseconds: Int64) -> String {
    guard milliseconds > 0 else { return "" }
    let total = milliseconds / 1000
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}

func podcastDateText(_ milliseconds: Int64) -> String {
    guard milliseconds > 0 else { return "" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy.MM.dd"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000))
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}