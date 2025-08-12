import Foundation

public struct ConAnyConfig {
    public let output: String?      // as written in file; can be relative to .conany dir
    public let include: [String]
    public let exclude: [String]
}

public enum ConAnyParseError: Error, LocalizedError {
    case missingRender
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .missingRender: return "No render(...) block found."
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
        // Strip comments
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let s = String(line)
                if let hash = s.firstIndex(of: "#") {
                    return String(s[..<hash]).trimmingCharacters(in: .whitespaces)
                }
                return s.trimmingCharacters(in: .whitespaces)
            }

        // Join back to simplify bracket scanning
        let joined = lines.joined(separator: "\n")

        // Find `render(<out>) { ... }`
        let renderRegex = try NSRegularExpression(pattern: #"render\s*\(\s*([^\)\n]+?)\s*\)\s*\{"#, options: [])
        guard let m = renderRegex.firstMatch(in: joined, options: [], range: NSRange(joined.startIndex..., in: joined)) else {
            throw ConAnyParseError.missingRender
        }
        let outRange = Range(m.range(at: 1), in: joined)!
        let outputToken = joined[outRange].trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        // Extract block body (from the '{' we matched to its corresponding '}')
        let openIdx = Range(m.range, in: joined)!.upperBound
        guard let body = sliceBlockBody(from: joined, at: openIdx) else {
            throw ConAnyParseError.malformed("Unclosed render { } block.")
        }

        func parseList(_ keyword: String) throws -> [String] {
            let re = try NSRegularExpression(pattern: "\(keyword)\\s*\\[([\\s\\S]*?)\\]", options: [])
            guard let mm = re.firstMatch(in: body, options: [], range: NSRange(body.startIndex..., in: body)) else {
                return []
            }
            let r = Range(mm.range(at: 1), in: body)!
            let payload = body[r]
            // Split by commas/newlines, keep non-empty
            return payload
                .split { $0 == "," || $0.isNewline }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                .filter { !$0.isEmpty }
        }

        let include = try parseList("include")
        let exclude = try parseList("exclude")

        return ConAnyConfig(output: outputToken.isEmpty ? nil : outputToken,
                            include: include,
                            exclude: exclude)
    }

    private static func sliceBlockBody(from text: String, at openBraceIndex: String.Index) -> String? {
        var depth = 1
        var i = openBraceIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 {
                let start = openBraceIndex
                let end = text.index(before: i) // content without closing brace
                return String(text[start...end])
            }}
            i = text.index(after: i)
        }
        return nil
    }
}
