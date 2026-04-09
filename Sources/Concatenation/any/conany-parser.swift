import Foundation
import PathParsing

public struct ConAnyIncludeBlock: Sendable, Codable, Equatable {
    public let base: String?
    public let show: ConAnyShowStyle
    public let includes: [String]
    public let selections: [String]

    public init(
        base: String? = nil,
        show: ConAnyShowStyle = .full,
        includes: [String] = [],
        selections: [String] = []
    ) {
        self.base = base?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.show = show
        self.includes = includes
        self.selections = selections
    }

    public var patterns: [String] {
        includes + selections
    }
}

public enum ConAnyShowStyle: Sendable, Codable, Equatable {
    case full
    case relativeToBase
    case relativeToCWD
    case basename
    case middleEllipsis(
        keepFirst: Int,
        keepLast: Int
    )
    case dropFirst(Int)
}

public struct ConAnyRenderableObject: Sendable, Codable, Equatable {
    public let output: String
    public let includeBlocks: [ConAnyIncludeBlock]
    public let exclude: [String]
    public let context: ConcatenationContext?

    public init(
        output: String,
        includeBlocks: [ConAnyIncludeBlock],
        exclude: [String],
        context: ConcatenationContext?
    ) {
        self.output = output
        self.includeBlocks = includeBlocks
        self.exclude = exclude
        self.context = context
    }
}

public extension ConAnyRenderableObject {
    var include: [String] {
        includeBlocks.flatMap(\.includes)
    }

    var selections: [String] {
        includeBlocks.flatMap(\.selections)
    }

    var allIncludeEntries: [String] {
        includeBlocks.flatMap(\.patterns)
    }
}

public struct ConAnyConfig: Sendable, Codable, Equatable {
    public let renderables: [ConAnyRenderableObject]

    public init(
        renderables: [ConAnyRenderableObject]
    ) {
        self.renderables = renderables
    }
}

public enum ConAnyParseError: Error, LocalizedError, Equatable {
    case noneFound
    case missingRenderableObjectName
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .noneFound:
            return "No file(...), render(...), or directory(...) blocks found."

        case .missingRenderableObjectName:
            return "Missing name in parentheses."

        case .malformed(let message):
            return "Malformed .conany: \(message)"
        }
    }
}

public enum ConAnyParser {
    public static func parseFile(
        at url: URL
    ) throws -> ConAnyConfig {
        let raw = try String(
            contentsOf: url,
            encoding: .utf8
        )

        return try parse(raw)
    }

    public static func parse(
        _ text: String
    ) throws -> ConAnyConfig {
        let joined = preprocess(text)

        var renderables: [ConAnyRenderableObject] = []

        let directoryBlocks = try findNamedBlocks(
            named: "directory",
            in: joined,
            allowsBareBlock: false
        )

        for directory in directoryBlocks {
            let directoryName = parseSingleValueArgument(directory.argument)

            renderables.append(
                contentsOf: try parseRenderableBlocks(
                    in: directory.body,
                    outputPrefix: directoryName
                )
            )
        }

        let occupiedRanges = directoryBlocks.map(\.range)

        renderables.append(
            contentsOf: try parseRenderableBlocks(
                in: joined,
                outputPrefix: nil,
                skippingIfContainedIn: occupiedRanges
            )
        )

        guard !renderables.isEmpty else {
            throw ConAnyParseError.noneFound
        }

        return ConAnyConfig(
            renderables: renderables
        )
    }
}

private extension ConAnyParser {
    struct BlockMatch {
        let name: String
        let argument: String?
        let body: String
        let range: Range<String.Index>
    }

    static func parseRenderableBlocks(
        in text: String,
        outputPrefix: String?,
        skippingIfContainedIn skippedRanges: [Range<String.Index>] = []
    ) throws -> [ConAnyRenderableObject] {
        let fileBlocks = try findNamedBlocks(
            named: "file",
            in: text,
            allowsBareBlock: false
        )

        let renderBlocks = try findNamedBlocks(
            named: "render",
            in: text,
            allowsBareBlock: false
        )

        let matches = (fileBlocks + renderBlocks)
            .sorted { $0.range.lowerBound < $1.range.lowerBound }

        var out: [ConAnyRenderableObject] = []

        for match in matches {
            if skippedRanges.contains(where: { $0.contains(match.range.lowerBound) }) {
                continue
            }

            let rawOutput = parseSingleValueArgument(match.argument)

            guard !rawOutput.isEmpty else {
                throw ConAnyParseError.missingRenderableObjectName
            }

            let output = joinedPathPrefix(
                outputPrefix,
                rawOutput
            )

            let modernIncludes = try parseIncludeBlocks(
                in: match.body
            )

            let includeBlocks: [ConAnyIncludeBlock]
            if !modernIncludes.isEmpty {
                includeBlocks = modernIncludes
            } else {
                let legacyIncludes = parseListManual(
                    "include",
                    in: match.body
                )

                let split = try splitIncludeEntries(
                    legacyIncludes
                )

                includeBlocks = legacyIncludes.isEmpty
                    ? []
                    : [
                        .init(
                            base: nil,
                            show: .full,
                            includes: split.includes,
                            selections: split.selections
                        )
                    ]
            }

            let modernExcludes = parseBareStringBlocks(
                named: "exclude",
                in: match.body
            )

            let legacyExcludes = parseListManual(
                "exclude",
                in: match.body
            )

            let exclude = deduplicatedStrings(
                modernExcludes + legacyExcludes
            )

            let context = parseContext(
                in: match.body,
                with: output
            )

            out.append(
                .init(
                    output: output,
                    includeBlocks: includeBlocks,
                    exclude: exclude,
                    context: context
                )
            )
        }

        return out
    }

    static func parseIncludeBlocks(
        in text: String
    ) throws -> [ConAnyIncludeBlock] {
        let blocks = try findNamedBlocks(
            named: "include",
            in: text,
            allowsBareBlock: true
        )

        var out: [ConAnyIncludeBlock] = []

        for block in blocks {
            let args = parseArgumentMap(block.argument)

            let base = args["from"].flatMap(parseOptionalScalar)
            let show = try parseShowStyle(
                args["show"]
            )

            let entries = parseStringListBody(block.body)
            let split = try splitIncludeEntries(entries)

            out.append(
                .init(
                    base: base,
                    show: show,
                    includes: split.includes,
                    selections: split.selections
                )
            )
        }

        return out
    }

    static func splitIncludeEntries(
        _ entries: [String]
    ) throws -> (includes: [String], selections: [String]) {
        var includes: [String] = []
        var selections: [String] = []

        for entry in entries {
            let parsed = try PathParse.selectionExpression(entry)

            if parsed.content != nil {
                selections.append(entry)
            } else {
                includes.append(entry)
            }
        }

        return (includes, selections)
    }

    static func parseContext(
        in text: String,
        with output: String
    ) -> ConcatenationContext? {
        guard let block = try? findNamedBlocks(
            named: "context",
            in: text,
            allowsBareBlock: true
        ).first else {
            return nil
        }

        let body = block.body

        let title = parseAssignedScalar(
            named: "title",
            in: body
        )

        let details =
            parseTripleQuotedAssignment(
                named: "details",
                in: body
            )
            ?? parseBareBlockText(
                named: "details",
                in: body
            )
            ?? parseAssignedScalar(
                named: "details",
                in: body
            )

        let dependencies: [String]? = {
            let modern = parseBareStringBlocks(
                named: "dependencies",
                in: body
            )

            if !modern.isEmpty {
                return modern
            }

            let legacy = parseListManual(
                "dependencies",
                in: body
            )

            return legacy.isEmpty ? nil : legacy
        }()

        if title == nil,
           details == nil,
           dependencies == nil {
            return nil
        }

        return ConcatenationContext(
            title: title,
            details: details,
            dependencies: dependencies,
            concatenatedFile: output
        )
    }

    static func preprocess(
        _ text: String
    ) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { rawLine in
                stripComments(from: String(rawLine))
            }
            .joined(separator: "\n")
    }

    static func stripComments(
        from line: String
    ) -> String {
        var result = ""
        var index = line.startIndex

        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        while index < line.endIndex {
            let character = line[index]
            let nextIndex = line.index(after: index)
            let nextCharacter: Character? =
                nextIndex < line.endIndex ? line[nextIndex] : nil

            if escaped {
                result.append(character)
                escaped = false
                index = nextIndex
                continue
            }

            if character == "\\" {
                result.append(character)
                escaped = true
                index = nextIndex
                continue
            }

            if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                result.append(character)
                index = nextIndex
                continue
            }

            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                result.append(character)
                index = nextIndex
                continue
            }

            if !inSingleQuote && !inDoubleQuote {
                if character == "#" {
                    break
                }

                if character == "/", nextCharacter == "/" {
                    break
                }
            }

            result.append(character)
            index = nextIndex
        }

        return result
    }

    static func findNamedBlocks(
        named keyword: String,
        in text: String,
        allowsBareBlock: Bool
    ) throws -> [BlockMatch] {
        var matches: [BlockMatch] = []
        var searchIndex = text.startIndex

        while let keywordRange = text.range(
            of: keyword,
            range: searchIndex..<text.endIndex
        ) {
            guard isWordBoundary(
                boundaryBefore: keywordRange.lowerBound,
                in: text
            ),
            isWordBoundary(
                boundaryAfter: keywordRange.upperBound,
                in: text
            ) else {
                searchIndex = keywordRange.upperBound
                continue
            }

            var cursor = keywordRange.upperBound
            skipTrivia(
                in: text,
                at: &cursor
            )

            var argument: String?
            if cursor < text.endIndex, text[cursor] == "(" {
                guard let parenClose = findMatchingClose(
                    in: text,
                    openAt: cursor,
                    openChar: "(",
                    closeChar: ")"
                ) else {
                    throw ConAnyParseError.malformed(
                        "Unclosed '(' after \(keyword)"
                    )
                }

                argument = String(
                    text[text.index(after: cursor)..<parenClose]
                )

                cursor = text.index(after: parenClose)
                skipTrivia(
                    in: text,
                    at: &cursor
                )
            } else if !allowsBareBlock {
                searchIndex = keywordRange.upperBound
                continue
            }

            guard cursor < text.endIndex, text[cursor] == "{" else {
                searchIndex = keywordRange.upperBound
                continue
            }

            guard let braceClose = findMatchingClose(
                in: text,
                openAt: cursor,
                openChar: "{",
                closeChar: "}"
            ) else {
                throw ConAnyParseError.malformed(
                    "Unclosed '{' after \(keyword)"
                )
            }

            let body = String(
                text[text.index(after: cursor)..<braceClose]
            )

            matches.append(
                .init(
                    name: keyword,
                    argument: argument,
                    body: body,
                    range: keywordRange.lowerBound..<text.index(after: braceClose)
                )
            )

            searchIndex = text.index(after: braceClose)
        }

        return matches
    }

    static func findMatchingClose(
        in text: String,
        openAt openIndex: String.Index,
        openChar: Character,
        closeChar: Character
    ) -> String.Index? {
        var depth = 0
        var index = openIndex

        var inSingleQuote = false
        var inDoubleQuote = false
        var inTripleQuote = false
        var escaped = false

        while index < text.endIndex {
            let character = text[index]

            if escaped {
                escaped = false
                index = text.index(after: index)
                continue
            }

            if character == "\\" && !inSingleQuote && !inTripleQuote {
                escaped = true
                index = text.index(after: index)
                continue
            }

            if !inSingleQuote {
                if text[index...].hasPrefix("\"\"\"") {
                    inTripleQuote.toggle()
                    index = text.index(index, offsetBy: 3)
                    continue
                }
            }

            if !inTripleQuote {
                if character == "\"" && !inSingleQuote {
                    inDoubleQuote.toggle()
                    index = text.index(after: index)
                    continue
                }

                if character == "'" && !inDoubleQuote {
                    inSingleQuote.toggle()
                    index = text.index(after: index)
                    continue
                }
            }

            if inSingleQuote || inDoubleQuote || inTripleQuote {
                index = text.index(after: index)
                continue
            }

            if character == openChar {
                depth += 1
            } else if character == closeChar {
                depth -= 1

                if depth == 0 {
                    return index
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    static func parseArgumentMap(
        _ raw: String?
    ) -> [String: String] {
        guard let raw else {
            return [:]
        }

        let pieces = splitTopLevel(
            raw,
            separator: ","
        )

        var out: [String: String] = [:]

        for piece in pieces {
            guard let separator = firstTopLevelColon(in: piece) else {
                continue
            }

            let key = String(
                piece[..<separator]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            let value = String(
                piece[piece.index(after: separator)...]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if !key.isEmpty {
                out[key] = value
            }
        }

        return out
    }

    static func parseShowStyle(
        _ raw: String?
    ) throws -> ConAnyShowStyle {
        guard let raw else {
            return .full
        }

        let value = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch value {
        case "", ".full", "full":
            return .full

        case ".relativeToBase", "relativeToBase":
            return .relativeToBase

        case ".relativeToCWD", "relativeToCWD":
            return .relativeToCWD

        case ".basename", "basename":
            return .basename

        default:
            if let parsed = parseDropFirstShowStyle(value) {
                return parsed
            }

            if let parsed = parseMiddleEllipsisShowStyle(value) {
                return parsed
            }

            throw ConAnyParseError.malformed(
                "Unsupported include(show:) value: \(value)"
            )
        }
    }

    static func parseDropFirstShowStyle(
        _ raw: String
    ) -> ConAnyShowStyle? {
        guard let range = raw.range(
            of: #"^\.?dropFirst\(\s*(\d+)\s*\)$"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let text = String(raw[range])

        guard let count = firstInteger(in: text) else {
            return nil
        }

        return .dropFirst(count)
    }

    static func parseMiddleEllipsisShowStyle(
        _ raw: String
    ) -> ConAnyShowStyle? {
        guard raw.range(
            of: #"^\.?middleEllipsis\("#,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        guard
            let keepFirst = integerValue(
                named: "keepFirst",
                in: raw
            ),
            let keepLast = integerValue(
                named: "keepLast",
                in: raw
            )
        else {
            return nil
        }

        return .middleEllipsis(
            keepFirst: keepFirst,
            keepLast: keepLast
        )
    }

    static func parseSingleValueArgument(
        _ raw: String?
    ) -> String {
        guard let raw else {
            return ""
        }

        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return ""
        }

        return unquoted(trimmed) ?? trimmed
    }

    static func parseOptionalScalar(
        _ raw: String
    ) -> String? {
        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty, trimmed != "_" else {
            return nil
        }

        return unquoted(trimmed) ?? trimmed
    }

    static func parseAssignedScalar(
        named key: String,
        in text: String
    ) -> String? {
        let pattern = #"(?m)\b\#(key)\s*=\s*(.+)$"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(
                    text.startIndex..<text.endIndex,
                    in: text
                )
            ),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let raw = String(text[range])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return parseOptionalScalar(raw)
    }

    static func parseTripleQuotedAssignment(
        named key: String,
        in text: String
    ) -> String? {
        let pattern = #"(?s)\b\#(key)\s*=\s*\"\"\"(.*?)\"\"\""#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(
                    text.startIndex..<text.endIndex,
                    in: text
                )
            ),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let raw = String(text[range])

        let trimmed = raw.trimmingCharacters(
            in: .newlines
        )

        guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              trimmed.trimmingCharacters(in: .whitespacesAndNewlines) != "_" else {
            return nil
        }

        return dedent(trimmed)
    }

    static func parseBareBlockText(
        named key: String,
        in text: String
    ) -> String? {
        guard let block = try? findNamedBlocks(
            named: key,
            in: text,
            allowsBareBlock: true
        ).first else {
            return nil
        }

        let trimmed = block.body.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty, trimmed != "_" else {
            return nil
        }

        return dedent(trimmed)
    }

    static func parseBareStringBlocks(
        named key: String,
        in text: String
    ) -> [String] {
        guard let blocks = try? findNamedBlocks(
            named: key,
            in: text,
            allowsBareBlock: true
        ) else {
            return []
        }

        return deduplicatedStrings(
            blocks.flatMap {
                parseStringListBody($0.body)
            }
        )
    }

    static func parseStringListBody(
        _ body: String
    ) -> [String] {
        body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .map {
                $0.hasSuffix(",") ? String($0.dropLast()) : $0
            }
            .compactMap { line -> String? in
                guard !line.isEmpty, line != "_" else {
                    return nil
                }

                return unquoted(line) ?? line
            }
    }

    static func parseListManual(
        _ keyword: String,
        in text: String
    ) -> [String] {
        var out: [String] = []
        var searchIndex = text.startIndex

        while let keywordRange = text.range(
            of: keyword,
            range: searchIndex..<text.endIndex
        ) {
            guard isWordBoundary(
                boundaryBefore: keywordRange.lowerBound,
                in: text
            ),
            isWordBoundary(
                boundaryAfter: keywordRange.upperBound,
                in: text
            ) else {
                searchIndex = keywordRange.upperBound
                continue
            }

            var cursor = keywordRange.upperBound
            skipTrivia(
                in: text,
                at: &cursor
            )

            guard cursor < text.endIndex, text[cursor] == "[" else {
                searchIndex = keywordRange.upperBound
                continue
            }

            guard let close = findMatchingClose(
                in: text,
                openAt: cursor,
                openChar: "[",
                closeChar: "]"
            ) else {
                searchIndex = keywordRange.upperBound
                continue
            }

            let body = String(
                text[text.index(after: cursor)..<close]
            )

            out.append(
                contentsOf: parseStringListBody(body)
            )

            searchIndex = text.index(after: close)
        }

        return deduplicatedStrings(out)
    }

    static func splitTopLevel(
        _ raw: String,
        separator: Character
    ) -> [String] {
        var parts: [String] = []
        var current = ""

        var depthParen = 0
        var depthBrace = 0
        var depthBracket = 0

        var inSingleQuote = false
        var inDoubleQuote = false
        var inTripleQuote = false
        var escaped = false

        var index = raw.startIndex

        while index < raw.endIndex {
            if escaped {
                current.append(raw[index])
                escaped = false
                index = raw.index(after: index)
                continue
            }

            if raw[index] == "\\" && !inSingleQuote && !inTripleQuote {
                current.append(raw[index])
                escaped = true
                index = raw.index(after: index)
                continue
            }

            if !inSingleQuote && raw[index...].hasPrefix("\"\"\"") {
                current += "\"\"\""
                inTripleQuote.toggle()
                index = raw.index(index, offsetBy: 3)
                continue
            }

            let character = raw[index]

            if !inTripleQuote {
                if character == "\"" && !inSingleQuote {
                    inDoubleQuote.toggle()
                    current.append(character)
                    index = raw.index(after: index)
                    continue
                }

                if character == "'" && !inDoubleQuote {
                    inSingleQuote.toggle()
                    current.append(character)
                    index = raw.index(after: index)
                    continue
                }
            }

            if inSingleQuote || inDoubleQuote || inTripleQuote {
                current.append(character)
                index = raw.index(after: index)
                continue
            }

            switch character {
            case "(":
                depthParen += 1
            case ")":
                depthParen -= 1
            case "{":
                depthBrace += 1
            case "}":
                depthBrace -= 1
            case "[":
                depthBracket += 1
            case "]":
                depthBracket -= 1
            default:
                break
            }

            if character == separator,
               depthParen == 0,
               depthBrace == 0,
               depthBracket == 0 {
                parts.append(
                    current.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )
                current = ""
            } else {
                current.append(character)
            }

            index = raw.index(after: index)
        }

        let final = current.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !final.isEmpty {
            parts.append(final)
        }

        return parts
    }

    static func firstTopLevelColon(
        in raw: String
    ) -> String.Index? {
        var depthParen = 0
        var depthBrace = 0
        var depthBracket = 0

        var inSingleQuote = false
        var inDoubleQuote = false
        var inTripleQuote = false
        var escaped = false

        var index = raw.startIndex

        while index < raw.endIndex {
            if escaped {
                escaped = false
                index = raw.index(after: index)
                continue
            }

            if raw[index] == "\\" && !inSingleQuote && !inTripleQuote {
                escaped = true
                index = raw.index(after: index)
                continue
            }

            if !inSingleQuote && raw[index...].hasPrefix("\"\"\"") {
                inTripleQuote.toggle()
                index = raw.index(index, offsetBy: 3)
                continue
            }

            let character = raw[index]

            if !inTripleQuote {
                if character == "\"" && !inSingleQuote {
                    inDoubleQuote.toggle()
                    index = raw.index(after: index)
                    continue
                }

                if character == "'" && !inDoubleQuote {
                    inSingleQuote.toggle()
                    index = raw.index(after: index)
                    continue
                }
            }

            if inSingleQuote || inDoubleQuote || inTripleQuote {
                index = raw.index(after: index)
                continue
            }

            switch character {
            case "(":
                depthParen += 1
            case ")":
                depthParen -= 1
            case "{":
                depthBrace += 1
            case "}":
                depthBrace -= 1
            case "[":
                depthBracket += 1
            case "]":
                depthBracket -= 1
            case ":" where depthParen == 0 && depthBrace == 0 && depthBracket == 0:
                return index
            default:
                break
            }

            index = raw.index(after: index)
        }

        return nil
    }

    static func firstInteger(
        in raw: String
    ) -> Int? {
        let digits = raw.filter(\.isNumber)
        return Int(digits)
    }

    static func integerValue(
        named key: String,
        in raw: String
    ) -> Int? {
        let pattern = #"\#(key)\s*:\s*(\d+)"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: raw,
                range: NSRange(
                    raw.startIndex..<raw.endIndex,
                    in: raw
                )
            ),
            let range = Range(match.range(at: 1), in: raw)
        else {
            return nil
        }

        return Int(raw[range])
    }

    static func skipTrivia(
        in text: String,
        at index: inout String.Index
    ) {
        while index < text.endIndex,
              text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    static func isWordBoundary(
        boundaryBefore index: String.Index,
        in text: String
    ) -> Bool {
        guard index > text.startIndex else {
            return true
        }

        let before = text[text.index(before: index)]

        return !(before.isLetter || before.isNumber || before == "_")
    }

    static func isWordBoundary(
        boundaryAfter index: String.Index,
        in text: String
    ) -> Bool {
        guard index < text.endIndex else {
            return true
        }

        let after = text[index]

        return !(after.isLetter || after.isNumber || after == "_")
    }

    static func unquoted(
        _ raw: String
    ) -> String? {
        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("\"\"\""), trimmed.hasSuffix("\"\"\""), trimmed.count >= 6 {
            return String(
                trimmed.dropFirst(3).dropLast(3)
            )
        }

        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(
                trimmed.dropFirst().dropLast()
            )
        }

        return nil
    }

    static func joinedPathPrefix(
        _ prefix: String?,
        _ output: String
    ) -> String {
        guard let prefix,
              !prefix.isEmpty else {
            return output
        }

        let lhs = prefix.hasSuffix("/")
            ? String(prefix.dropLast())
            : prefix
        let rhs = output.hasPrefix("/")
            ? String(output.dropFirst())
            : output

        return lhs + "/" + rhs
    }

    static func deduplicatedStrings(
        _ values: [String]
    ) -> [String] {
        var out: [String] = []
        var seen: Set<String> = []

        for value in values {
            let trimmed = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !trimmed.isEmpty else {
                continue
            }

            if seen.insert(trimmed).inserted {
                out.append(trimmed)
            }
        }

        return out
    }

    static func dedent(
        _ string: String
    ) -> String {
        let lines = string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let nonEmpty = lines.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }

        let minIndent = nonEmpty.map { line -> Int in
            var count = 0

            for character in line {
                if character == " " {
                    count += 1
                } else {
                    break
                }
            }

            return count
        }.min() ?? 0

        if minIndent == 0 {
            return string
        }

        return lines
            .map { line in
                if line.count >= minIndent {
                    return String(line.dropFirst(minIndent))
                }

                return line
            }
            .joined(separator: "\n")
    }
}
