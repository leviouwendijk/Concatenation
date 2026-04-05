import Foundation

public struct ConAnyRenderableObject {
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
        case .noneFound:
            return "No render(...) blocks found."

        case .missingRenderableObjectName:
            return "No name in parentheses. Use 'render(<object_name.txt>) {}."

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
        var searchIndex = joined.startIndex

        while let renderRange = joined.range(
            of: "render",
            range: searchIndex..<joined.endIndex
        ) {
            if !isWordBoundary(
                boundaryBefore: renderRange.lowerBound,
                in: joined
            ) || !isWordBoundary(
                boundaryAfter: renderRange.upperBound,
                in: joined
            ) {
                searchIndex = renderRange.upperBound
                continue
            }

            guard let parenOpen = indexOfCharacter(
                "(",
                in: joined,
                from: renderRange.upperBound
            ) else {
                searchIndex = renderRange.upperBound
                continue
            }

            guard let parenClose = findMatchingClose(
                in: joined,
                openAt: parenOpen,
                openChar: "(",
                closeChar: ")"
            ) else {
                throw ConAnyParseError.malformed(
                    "Unclosed '(' after render"
                )
            }

            let insideParens = joined[
                joined.index(after: parenOpen)..<parenClose
            ]

            var outputToken = insideParens
                .trimmingCharacters(in: .whitespacesAndNewlines)
            outputToken = outputToken.trimmingCharacters(
                in: CharacterSet(charactersIn: "\"'")
            )

            guard let braceOpen = indexOfCharacter(
                "{",
                in: joined,
                from: parenClose
            ) else {
                throw ConAnyParseError.malformed(
                    "Expected '{' after render(...)"
                )
            }

            let openIndexAfterBrace = joined.index(after: braceOpen)

            guard let body = sliceBlockBody(
                from: joined,
                at: openIndexAfterBrace
            ) else {
                throw ConAnyParseError.malformed(
                    "Unclosed render { } block."
                )
            }

            if outputToken.isEmpty {
                throw ConAnyParseError.missingRenderableObjectName
            }

            let include = parseListManual(
                "include",
                in: body
            )
            let exclude = parseListManual(
                "exclude",
                in: body
            )
            let context = parseContext(
                in: body,
                with: outputToken
            )

            renderables.append(
                .init(
                    output: outputToken,
                    include: include,
                    exclude: exclude,
                    context: context
                )
            )

            if let nextSearchPos = joined.range(
                of: body,
                range: openIndexAfterBrace..<joined.endIndex
            )?.upperBound {
                searchIndex = nextSearchPos
            } else {
                searchIndex = joined.index(after: braceOpen)
            }
        }

        guard !renderables.isEmpty else {
            throw ConAnyParseError.noneFound
        }

        return ConAnyConfig(
            renderables: renderables
        )
    }

    private static func preprocess(
        _ text: String
    ) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { rawLine in
                stripComments(from: String(rawLine))
                    .trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
    }

    private static func stripComments(
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

    private static func isWordBoundary(
        boundaryBefore index: String.Index,
        in text: String
    ) -> Bool {
        if index == text.startIndex {
            return true
        }

        let before = text.index(before: index)
        let character = text[before]

        return character.isWhitespace
            || character == "\n"
            || character == "{"
            || character == "}"
            || character == "("
            || character == ")"
            || character == "["
            || character == "]"
    }

    private static func isWordBoundary(
        boundaryAfter index: String.Index,
        in text: String
    ) -> Bool {
        if index == text.endIndex {
            return true
        }

        let character = text[index]

        return character.isWhitespace
            || character == "\n"
            || character == "{"
            || character == "}"
            || character == "("
            || character == ")"
            || character == "["
            || character == "]"
    }

    private static func indexOfCharacter(
        _ target: Character,
        in text: String,
        from start: String.Index
    ) -> String.Index? {
        var index = start

        while index < text.endIndex {
            if text[index] == target {
                return index
            }
            index = text.index(after: index)
        }

        return nil
    }

    private static func findMatchingClose(
        in text: String,
        openAt start: String.Index,
        openChar: Character,
        closeChar: Character
    ) -> String.Index? {
        var depth = 0
        var index = start

        while index < text.endIndex {
            let character = text[index]

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

    private static func findKeywordRange(
        _ keyword: String,
        in text: String
    ) -> Range<String.Index>? {
        var search = text.startIndex

        while let range = text.range(
            of: keyword,
            range: search..<text.endIndex
        ) {
            if isWordBoundary(
                boundaryBefore: range.lowerBound,
                in: text
            ) && isWordBoundary(
                boundaryAfter: range.upperBound,
                in: text
            ) {
                return range
            }

            search = range.upperBound
        }

        return nil
    }

    private static func readToLineEnd(
        from start: String.Index,
        in text: String
    ) -> Substring {
        var index = start

        while index < text.endIndex,
              text[index].isWhitespace,
              text[index] != "\n" {
            index = text.index(after: index)
        }

        var end = index
        while end < text.endIndex, text[end] != "\n" {
            end = text.index(after: end)
        }

        return text[index..<end]
    }

    private static func parseListManual(
        _ keyword: String,
        in body: String
    ) -> [String] {
        guard let keywordRange = findKeywordRange(
            keyword,
            in: body
        ) else {
            return []
        }

        var index = keywordRange.upperBound
        while index < body.endIndex && body[index].isWhitespace {
            index = body.index(after: index)
        }

        guard index < body.endIndex, body[index] == "[" else {
            return []
        }

        guard let closeIndex = findMatchingClose(
            in: body,
            openAt: index,
            openChar: "[",
            closeChar: "]"
        ) else {
            return []
        }

        let inner = body[body.index(after: index)..<closeIndex]

        return inner
            .split { $0 == "," || $0 == "\n" }
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .map {
                $0.trimmingCharacters(
                    in: CharacterSet(charactersIn: "\"'")
                )
            }
            .filter { !$0.isEmpty }
    }

    private static func parseContext(
        in body: String,
        with outputToken: String
    ) -> ConcatenationContext? {
        guard let contextRange = findKeywordRange(
            "context",
            in: body
        ) else {
            return nil
        }

        guard let braceIndex = indexOfCharacter(
            "{",
            in: body,
            from: contextRange.upperBound
        ) else {
            return nil
        }

        let innerStart = body.index(after: braceIndex)

        guard let inner = sliceBlockBody(
            from: body,
            at: innerStart
        ) else {
            return nil
        }

        var title: String?
        if let titleRange = findKeywordRange(
            "title",
            in: inner
        ) {
            var index = titleRange.upperBound

            while index < inner.endIndex && inner[index].isWhitespace {
                index = inner.index(after: index)
            }

            if index < inner.endIndex && inner[index] == "=" {
                let afterEquals = inner.index(after: index)
                let raw = readToLineEnd(
                    from: afterEquals,
                    in: inner
                )

                var value = raw.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                value = value.trimmingCharacters(
                    in: CharacterSet(charactersIn: "\"'")
                )

                if !value.isEmpty {
                    title = value
                }
            }
        }

        var details: String?
        if let detailsRange = findKeywordRange(
            "details",
            in: inner
        ) {
            if let detailsBrace = indexOfCharacter(
                "{",
                in: inner,
                from: detailsRange.upperBound
            ) {
                let detailsInnerStart = inner.index(after: detailsBrace)
                if let detailsInner = sliceBlockBody(
                    from: inner,
                    at: detailsInnerStart
                ) {
                    let text = dedent(detailsInner)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        details = text
                    }
                }
            }
        }

        var dependencies: [String]?
        let parsedDependencies = parseListManual(
            "dependencies",
            in: inner
        )
        if !parsedDependencies.isEmpty {
            dependencies = parsedDependencies
        }

        if title == nil,
           details == nil,
           dependencies == nil {
            return nil
        }

        return ConcatenationContext(
            title: title,
            details: details,
            dependencies: dependencies,
            concatenatedFile: outputToken
        )
    }

    private static func sliceBlockBody(
        from text: String,
        at openBraceIndex: String.Index
    ) -> String? {
        var depth = 1
        var index = openBraceIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "{" {
                depth += 1
            }

            if character == "}" {
                depth -= 1
                if depth == 0 {
                    let start = openBraceIndex
                    let end = text.index(before: index)
                    return String(text[start...end])
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    private static func dedent(
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
            .map { String($0.dropFirst(minIndent)) }
            .joined(separator: "\n")
    }
}
