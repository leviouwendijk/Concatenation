import Foundation

public struct ConAnyRenderableObject {
    public let output: String?
    public let include: [String]
    public let exclude: [String]
}

public struct ConAnyConfig {
    public let renderables: [ConAnyRenderableObject]
}

public enum ConAnyParseError: Error, LocalizedError {
    case noneFound
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .noneFound: return "No render(...) blocks found."
        case .malformed(let m): return "Malformed .conany: \(m)"
        }
    }
}

public enum ConAnyParser {
    public static func parseFile(at url: URL) throws -> ConAnyConfig {
        let raw = try String(contentsOf: url, encoding: .utf8)
        return try parse(raw)
    }

    public static func parse(_ text: String) throws -> ConAnyConfig {
        // strip comments
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { s -> String in
                let line = String(s)
                if let i = line.firstIndex(of: "#") { return String(line[..<i]).trimmingCharacters(in: .whitespaces) }
                return line.trimmingCharacters(in: .whitespaces)
            }

        let joined = lines.joined(separator: "\n")
        let renderRe = try NSRegularExpression(pattern: #"render\s*\(\s*([^\)\n]+?)\s*\)\s*\{"#, options: [])

        let matches = renderRe.matches(in: joined, options: [], range: NSRange(joined.startIndex..., in: joined))
        guard !matches.isEmpty else { throw ConAnyParseError.noneFound }

        var renderables: [ConAnyRenderableObject] = []

        for m in matches {
            let outRange = Range(m.range(at: 1), in: joined)!
            let outputToken = joined[outRange].trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            let openIdx = Range(m.range, in: joined)!.upperBound
            guard let body = sliceBlockBody(from: joined, at: openIdx) else {
                throw ConAnyParseError.malformed("Unclosed render { } block.")
            }

            let include = try parseList("include", in: body)
            let exclude = try parseList("exclude", in: body)

            renderables.append(.init(output: outputToken.isEmpty ? nil : outputToken,
                                     include: include,
                                     exclude: exclude))
        }

        return ConAnyConfig(renderables: renderables)
    }

    private static func parseList(_ keyword: String, in body: String) throws -> [String] {
        let re = try NSRegularExpression(pattern: "\(keyword)\\s*\\[([\\s\\S]*?)\\]", options: [])
        guard let mm = re.firstMatch(in: body, options: [], range: NSRange(body.startIndex..., in: body)) else {
            return []
        }
        let r = Range(mm.range(at: 1), in: body)!
        let payload = body[r]
        return payload
            .split { $0 == "," || $0.isNewline }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
    }

    private static func sliceBlockBody(from text: String, at openBraceIndex: String.Index) -> String? {
        var depth = 1
        var i = openBraceIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let start = openBraceIndex
                    let end = text.index(before: i)
                    return String(text[start...end])
                }
            }
            i = text.index(after: i)
        }
        return nil
    }
}
