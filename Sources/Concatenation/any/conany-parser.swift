import Foundation

public struct ConAnyRenderableObject {
    // public let output: String?
    public let output: String
    public let include: [String]
    public let exclude: [String]
    public let context: ConcatenationContext?
}

public struct ConAnyConfig {
    public let renderables: [ConAnyRenderableObject]
}

public enum ConAnyParseError: Error, LocalizedError {
    case noneFound
    case missingRenderableObjectName
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .noneFound: return "No render(...) blocks found."
        case .missingRenderableObjectName: return "No name in parentheses. Use 'render(<object_name.txt>) {}."
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
        // strip comments and normalize newlines
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { s -> String in
                let line = String(s)
                if let i = line.firstIndex(of: "#") { return String(line[..<i]).trimmingCharacters(in: .whitespaces) }
                return line.trimmingCharacters(in: .whitespaces)
            }

        let joined = lines.joined(separator: "\n")

        var renderables: [ConAnyRenderableObject] = []
        var searchIndex = joined.startIndex

        while let rRange = joined.range(of: "render", range: searchIndex..<joined.endIndex) {
            // ensure 'render' is a standalone token (preceded/ended by boundary)
            if !isWordBoundary(boundaryBefore: rRange.lowerBound, in: joined) ||
                !isWordBoundary(boundaryAfter: rRange.upperBound, in: joined) {
                searchIndex = rRange.upperBound
                continue
            }

            // find '(' after 'render'
            guard let parenOpen = indexOfCharacter("(", in: joined, from: rRange.upperBound) else {
                searchIndex = rRange.upperBound
                continue
            }

            // find matching ')' for the parenOpen
            guard let parenClose = findMatchingClose(in: joined, openAt: parenOpen, openChar: "(", closeChar: ")") else {
                throw ConAnyParseError.malformed("Unclosed '(' after render")
            }

            // extract output token inside parentheses
            let insideParens = joined[joined.index(after: parenOpen)..<parenClose]
            var outputToken = insideParens.trimmingCharacters(in: .whitespacesAndNewlines)
            outputToken = outputToken.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            // find the brace '{' that starts the block (skip whitespace between ) and {)
            guard let braceOpen = indexOfCharacter("{", in: joined, from: parenClose) else {
                throw ConAnyParseError.malformed("Expected '{' after render(...)")
            }

            // slice block body using your existing helper (expects index right after '{')
            let openIndexAfterBrace = joined.index(after: braceOpen)
            guard let body = sliceBlockBody(from: joined, at: openIndexAfterBrace) else {
                throw ConAnyParseError.malformed("Unclosed render { } block.")
            }

            if outputToken.isEmpty {
                throw ConAnyParseError.missingRenderableObjectName
            }

            let include = parseListManual("include", in: body)
            let exclude = parseListManual("exclude", in: body)
            let context = parseContext(in: body, with: outputToken)

            renderables.append(
                .init(
                    // output: outputToken.isEmpty ? nil : outputToken,
                    output: outputToken,
                    include: include,
                    exclude: exclude,
                    context: context
                )
            )

            // continue search after the closing brace of this block
            // find position of the '}' that closed the block; sliceBlockBody returned inner text,
            // so we can compute the index of the closing brace by searching for the body substring
            if let nextSearchPos = joined.range(of: body, range: openIndexAfterBrace..<joined.endIndex)?.upperBound {
                // this points just after the inner body; advance to continue searching safely
                searchIndex = nextSearchPos
            } else {
                searchIndex = joined.index(after: braceOpen)
            }
        }

        guard !renderables.isEmpty else { throw ConAnyParseError.noneFound }
        return ConAnyConfig(renderables: renderables)
    }

    // -----------------------
    // Manual helpers (fast, minimal allocations)
    // -----------------------

    // Is the location a word boundary (start or whitespace or newline or punctuation)?
    private static func isWordBoundary(boundaryBefore idx: String.Index, in text: String) -> Bool {
        if idx == text.startIndex { return true }
        let before = text.index(before: idx)
        let ch = text[before]
        return ch.isWhitespace || ch == "\n" || ch == "{" || ch == "}" || ch == "(" || ch == ")" || ch == "[" || ch == "]"
    }

    private static func isWordBoundary(boundaryAfter idx: String.Index, in text: String) -> Bool {
        if idx == text.endIndex { return true }
        let ch = text[idx]
        return ch.isWhitespace || ch == "\n" || ch == "{" || ch == "}" || ch == "(" || ch == ")" || ch == "[" || ch == "]"
    }

    // Return the first index of a character from a start index (skips nothing).
    private static func indexOfCharacter(_ target: Character, in text: String, from: String.Index) -> String.Index? {
        var i = from
        while i < text.endIndex {
            if text[i] == target { return i }
            i = text.index(after: i)
        }
        return nil
    }

    // Find matching close char with nesting support (works for (), {}, []), returns index of closing char
    private static func findMatchingClose(in text: String, openAt: String.Index, openChar: Character, closeChar: Character) -> String.Index? {
        var depth = 0
        var i = openAt
        while i < text.endIndex {
            let ch = text[i]
            if ch == openChar { depth += 1 }
            else if ch == closeChar {
                depth -= 1
                if depth == 0 { return i }
            }
            i = text.index(after: i)
        }
        return nil
    }

    // Find a standalone keyword (returns the range of the keyword) — makes sure it isn't nested in another word
    private static func findKeywordRange(_ keyword: String, in text: String) -> Range<String.Index>? {
        var search = text.startIndex
        while let r = text.range(of: keyword, range: search..<text.endIndex) {
            if isWordBoundary(boundaryBefore: r.lowerBound, in: text) && isWordBoundary(boundaryAfter: r.upperBound, in: text) {
                return r
            }
            search = r.upperBound
        }
        return nil
    }

    // Read from an index (after '=') up to end of current line
    private static func readToLineEnd(from idx: String.Index, in text: String) -> Substring {
        var i = idx
        // skip leading whitespace
        while i < text.endIndex, text[i].isWhitespace, text[i] != "\n" {
            i = text.index(after: i)
        }
        var j = i
        while j < text.endIndex, text[j] != "\n" {
            j = text.index(after: j)
        }
        return text[i..<j]
    }

    // Parse a bracketed list like: include [ ... ] — returns array of trimmed strings
    private static func parseListManual(_ keyword: String, in body: String) -> [String] {
        guard let kwRange = findKeywordRange(keyword, in: body) else { return [] }
        // find '[' after keyword
        var idx = kwRange.upperBound
        // skip whitespace/newlines
        while idx < body.endIndex && body[idx].isWhitespace { idx = body.index(after: idx) }
        guard idx < body.endIndex && body[idx] == "[" else { return [] }
        // find matching ']'
        guard let closeIdx = findMatchingClose(in: body, openAt: idx, openChar: "[", closeChar: "]") else { return [] }
        let inner = body[body.index(after: idx)..<closeIdx]
        // split on commas and newlines
        let parts = inner.split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
        return parts
    }

    // -----------------------
    // context parser (explicitly scoped to `context { ... }`)
    // -----------------------
    private static func parseContext(in body: String, with outputToken: String) -> ConcatenationContext? {
        guard let ctxRange = findKeywordRange("context", in: body) else {
            return nil
        }

        guard let braceIdx = indexOfCharacter("{", in: body, from: ctxRange.upperBound) else {
            return nil
        }

        let innerStart = body.index(after: braceIdx)
        guard let inner = sliceBlockBody(from: body, at: innerStart) else {
            return nil
        }

        var title: String? = nil
        if let tRange = findKeywordRange("title", in: inner) {
            var i = tRange.upperBound
            while i < inner.endIndex && inner[i].isWhitespace { i = inner.index(after: i) }
            if i < inner.endIndex && inner[i] == "=" {
                let afterEq = inner.index(after: i)
                let raw = readToLineEnd(from: afterEq, in: inner)
                var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !s.isEmpty { title = s }
            }
        }

        var details: String? = nil
        if let dRange = findKeywordRange("details", in: inner) {
            if let dBrace = indexOfCharacter("{", in: inner, from: dRange.upperBound) {
                let dInnerStart = inner.index(after: dBrace)
                if let dInner = sliceBlockBody(from: inner, at: dInnerStart) {
                    let text = dedent(dInner).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { details = text }
                }
            }
        }

        var dependencies: [String]? = nil
        let deps = parseListManual("dependencies", in: inner)
        if !deps.isEmpty {
            dependencies = deps
        }

        if title == nil && details == nil && dependencies == nil { return nil }
        return ConcatenationContext(
            title: title,
            details: details,
            dependencies: dependencies,
            concatenatedFile: outputToken
        )
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

    private static func dedent(_ s: String) -> String {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let minIndent = nonEmpty.map { line -> Int in
            var count = 0
            for c in line {
                if c == " " { count += 1 } else { break }
            }
            return count
        }.min() ?? 0
        if minIndent == 0 { return s }
        return lines.map { String($0.dropFirst(minIndent)) }.joined(separator: "\n")
    }
}

// public enum ConAnyParser {
//     public static func parseFile(at url: URL) throws -> ConAnyConfig {
//         let raw = try String(contentsOf: url, encoding: .utf8)
//         return try parse(raw)
//     }

//     public static func parse(_ text: String) throws -> ConAnyConfig {
//         // strip comments
//         let lines = text
//             .replacingOccurrences(of: "\r\n", with: "\n")
//             .split(separator: "\n", omittingEmptySubsequences: false)
//             .map { s -> String in
//                 let line = String(s)
//                 if let i = line.firstIndex(of: "#") { return String(line[..<i]).trimmingCharacters(in: .whitespaces) }
//                 return line.trimmingCharacters(in: .whitespaces)
//             }

//         let joined = lines.joined(separator: "\n")
//         let renderRe = try NSRegularExpression(pattern: #"render\s*\(\s*([^\)\n]+?)\s*\)\s*\{"#, options: [])

//         let matches = renderRe.matches(in: joined, options: [], range: NSRange(joined.startIndex..., in: joined))
//         guard !matches.isEmpty else { throw ConAnyParseError.noneFound }

//         var renderables: [ConAnyRenderableObject] = []

//         for m in matches {
//             let outRange = Range(m.range(at: 1), in: joined)!
//             let outputToken = joined[outRange].trimmingCharacters(in: .whitespacesAndNewlines)
//                 .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

//             let openIdx = Range(m.range, in: joined)!.upperBound
//             guard let body = sliceBlockBody(from: joined, at: openIdx) else {
//                 throw ConAnyParseError.malformed("Unclosed render { } block.")
//             }

//             let include = try parseList("include", in: body)
//             let exclude = try parseList("exclude", in: body)
//             let context = parseContext(in: body)

//             renderables.append(
//                 .init(
//                     output: outputToken.isEmpty ? nil : outputToken,
//                     include: include,
//                     exclude: exclude,
//                     context: context
//                 )
//             )
//         }

//         return ConAnyConfig(renderables: renderables)
//     }

//     private static func parseList(_ keyword: String, in body: String) throws -> [String] {
//         let re = try NSRegularExpression(pattern: "\(keyword)\\s*\\[([\\s\\S]*?)\\]", options: [])
//         guard let mm = re.firstMatch(in: body, options: [], range: NSRange(body.startIndex..., in: body)) else {
//             return []
//         }
//         let r = Range(mm.range(at: 1), in: body)!
//         let payload = body[r]
//         return payload
//             .split { $0 == "," || $0.isNewline }
//             .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
//             .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
//             .filter { !$0.isEmpty }
//     }

//     private static func sliceBlockBody(from text: String, at openBraceIndex: String.Index) -> String? {
//         var depth = 1
//         var i = openBraceIndex
//         while i < text.endIndex {
//             let ch = text[i]
//             if ch == "{" { depth += 1 }
//             if ch == "}" {
//                 depth -= 1
//                 if depth == 0 {
//                     let start = openBraceIndex
//                     let end = text.index(before: i)
//                     return String(text[start...end])
//                 }
//             }
//             i = text.index(after: i)
//         }
//         return nil
//     }

//     private static func parseContext(in body: String) -> ConcatenationContext? {

//     }

//     private static func dedent(_ s: String) -> String {
//         let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
//         // compute minimum indentation of non-empty lines
//         let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
//         let minIndent = nonEmpty.map { line -> Int in
//             var count = 0
//             for c in line {
//                 if c == " " { count += 1 } else { break }
//             }
//             return count
//         }.min() ?? 0
//         if minIndent == 0 { return s }
//         return lines.map { String($0.dropFirst(minIndent)) }.joined(separator: "\n")
//     }
// }
