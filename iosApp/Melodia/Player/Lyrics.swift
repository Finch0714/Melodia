import Foundation

struct LyricWord: Hashable {
    let start: TimeInterval
    let duration: TimeInterval
    let text: String

    var end: TimeInterval { start + duration }
}

struct LyricLine: Identifiable, Hashable {
    let id: String
    let time: TimeInterval
    let text: String
    let translation: String?
    let words: [LyricWord]

    init(
        time: TimeInterval,
        text: String,
        translation: String? = nil,
        words: [LyricWord] = []
    ) {
        self.time = time
        self.text = text
        self.translation = translation
        self.words = words
        self.id = "\(Int(time * 1000))-\(text)"
    }

    var endTime: TimeInterval {
        words.last?.end ?? time
    }
}

enum LyricParser {
    private static let yrcLinePattern = try! NSRegularExpression(pattern: "^\\[(\\d+),(\\d+)\\](.*)$")
    private static let lrcTimePattern = try! NSRegularExpression(pattern: "\\[(\\d{1,3}):(\\d{2})(?:[.:](\\d{2,3}))?\\]")
    private static let yrcWordPattern = try! NSRegularExpression(pattern: "\\((\\d+),(\\d+),\\d+\\)")

    static func parse(response: LyricResponse) -> [LyricLine] {
        let yTranslated = response.ytlrc?.lyric?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let translationText = yTranslated.isEmpty ? response.tlyric?.lyric : yTranslated
        let translations = translationMap(from: translationText)
        let translationKeys = translations.keys.sorted()

        let yrcText = response.yrc?.lyric ?? ""
        let lrcText = response.lrc?.lyric ?? ""

        var lines: [LyricLine]
        if containsYRCContent(yrcText) {
            lines = parseAny(yrcText)
        } else {
            lines = parseAny(lrcText)
        }
        if lines.isEmpty {
            lines = parseAny(lrcText)
        }
        guard !lines.isEmpty else { return [] }

        return lines.map { line in
            LyricLine(
                time: line.time,
                text: line.text,
                translation: translation(
                    at: Int((line.time * 1000).rounded()),
                    keys: translationKeys,
                    values: translations
                ),
                words: line.words
            )
        }
    }

    static func parseLRC(_ text: String) -> [LyricLine] {
        parseAny(text)
    }

    private static func parseAny(_ text: String) -> [LyricLine] {
        guard !text.isEmpty else { return [] }
        var result = [LyricLine]()
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("{") {
                if let parsed = parseJSONLine(line) {
                    result.append(parsed)
                }
                continue
            }

            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let yrcMatch = yrcLinePattern.firstMatch(in: line, range: range) {
                guard let start = integer(yrcMatch, group: 1, in: line) else { continue }
                let rawBody = string(yrcMatch, group: 3, in: line)
                let words = yrcWords(in: rawBody)
                let body = words.isEmpty
                    ? rawBody
                        .replacingOccurrences(of: "\\(\\d+,\\d+,\\d+\\)", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    : words.map(\.text).joined()
                guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                result.append(LyricLine(time: Double(start) / 1000, text: body, words: words))
                continue
            }

            let matches = lrcTimePattern.matches(in: line, range: range)
            guard !matches.isEmpty, let last = matches.last, let bodyRange = Range(last.range, in: line) else {
                continue
            }
            let body = String(line[bodyRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }

            for match in matches {
                guard let minute = integer(match, group: 1, in: line), let second = integer(match, group: 2, in: line) else {
                    continue
                }
                let fractionText = string(match, group: 3, in: line)
                let fraction = Int(fractionText) ?? 0
                let milliseconds: Int
                if fractionText.count == 2 {
                    milliseconds = fraction * 10
                } else if fractionText.count == 3 {
                    milliseconds = fraction
                } else {
                    milliseconds = 0
                }
                let seconds = Double(minute * 60 + second) + Double(milliseconds) / 1000
                result.append(LyricLine(time: seconds, text: body))
            }
        }
        return result.sorted { $0.time < $1.time }
    }

    private static func parseJSONLine(_ line: String) -> LyricLine? {
        guard let data = line.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let time = (object["t"] as? NSNumber)?.doubleValue else { return nil }
        guard let tokens = object["c"] as? [[String: Any]] else { return nil }
        let text = tokens
            .compactMap { $0["tx"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return LyricLine(time: time / 1000, text: text)
    }

    private static func yrcWords(in body: String) -> [LyricWord] {
        let whole = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = yrcWordPattern.matches(in: body, range: whole)
        guard !matches.isEmpty else { return [] }

        var words = [LyricWord]()
        for (index, match) in matches.enumerated() {
            guard
                let start = integer(match, group: 1, in: body),
                let duration = integer(match, group: 2, in: body)
            else { continue }

            let textStart = match.range.location + match.range.length
            let textEnd = index + 1 < matches.count ? matches[index + 1].range.location : whole.length
            guard textEnd >= textStart else { continue }

            let textRange = NSRange(location: textStart, length: textEnd - textStart)
            guard let range = Range(textRange, in: body) else { continue }
            let text = String(body[range])
            guard !text.isEmpty else { continue }

            words.append(
                LyricWord(
                    start: Double(start) / 1000,
                    duration: Double(duration) / 1000,
                    text: text
                )
            )
        }
        return words
    }

    private static func containsYRCContent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if yrcLinePattern.firstMatch(in: line, range: range) != nil {
                return true
            }
        }
        return false
    }

    private static func translationMap(from text: String?) -> [Int: String] {
        guard let text, !text.isEmpty else { return [:] }
        var result = [Int: String]()
        for line in parseAny(text) {
            let value = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            result[Int((line.time * 1000).rounded())] = value
        }
        return result
    }

    private static func translation(at time: Int, keys: [Int], values: [Int: String]) -> String? {
        if let exact = values[time], !exact.isEmpty {
            return exact
        }
        var closest: Int?
        var closestDistance = Int.max
        for key in keys {
            let distance = abs(key - time)
            if distance < closestDistance {
                closest = key
                closestDistance = distance
            }
            if key > time + 250 { break }
        }
        guard closestDistance <= 180, let closest else { return nil }
        let value = values[closest]
        return value?.isEmpty == false ? value : nil
    }

    private static func integer(_ match: NSTextCheckingResult, group: Int, in text: String) -> Int? {
        guard let range = Range(match.range(at: group), in: text) else { return nil }
        return Int(text[range])
    }

    private static func string(_ match: NSTextCheckingResult, group: Int, in text: String) -> String {
        guard let range = Range(match.range(at: group), in: text) else { return "" }
        return String(text[range])
    }
}