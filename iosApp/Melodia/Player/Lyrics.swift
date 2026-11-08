import Foundation

struct LyricLine: Identifiable, Hashable {
    let id: String
    let time: TimeInterval
    let text: String
    let translation: String?

    init(time: TimeInterval, text: String, translation: String? = nil) {
        self.time = time
        self.text = text
        self.translation = translation
        self.id = "\(Int(time * 1000))-\(text)"
    }
}

enum LyricParser {
    private static let yrcLinePattern = try! NSRegularExpression(pattern: "^\\[(\\d+),(\\d+)\\](.*)$")
    private static let lrcTimePattern = try! NSRegularExpression(pattern: "\\[(\\d{1,3}):(\\d{2})(?:[.:](\\d{2,3}))?\\]")

    static func parse(response: LyricResponse) -> [LyricLine] {
        let translationText = response.ytlrc?.lyric ?? response.tlyric?.lyric
        let translations = translationMap(from: translationText)

        var lines: [LyricLine]
        if let yrc = response.yrc?.lyric, !yrc.isEmpty {
            lines = parseYRC(yrc)
        } else {
            lines = []
        }
        if lines.isEmpty, let lrc = response.lrc?.lyric {
            lines = parseLRC(lrc)
        }
        guard !lines.isEmpty else { return [] }

        return lines.map { line in
            let key = Int((line.time * 1000).rounded())
            return LyricLine(
                time: line.time,
                text: line.text,
                translation: translations[key]
            )
        }
    }

    static func parseLRC(_ text: String) -> [LyricLine] {
        var result = [LyricLine]()
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = lrcTimePattern.matches(in: line, range: range)
            guard !matches.isEmpty else { continue }

            guard let last = matches.last, let bodyRange = Range(last.range, in: line) else { continue }
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

    private static func parseYRC(_ text: String) -> [LyricLine] {
        var result = [LyricLine]()
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = yrcLinePattern.firstMatch(in: line, range: range) else { continue }
            guard let start = integer(match, group: 1, in: line) else { continue }
            let body = string(match, group: 3, in: line)
                .replacingOccurrences(of: "\\(\\d+,\\d+,\\d+\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }
            result.append(LyricLine(time: Double(start) / 1000, text: body))
        }
        return result.sorted { $0.time < $1.time }
    }

    private static func translationMap(from text: String?) -> [Int: String] {
        guard let text, !text.isEmpty else { return [:] }
        var result = [Int: String]()
        for line in parseLRC(text) {
            result[Int((line.time * 1000).rounded())] = line.text
        }
        return result
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
