import Foundation

public func compilePatterns(_ globs: [String]) throws -> [NSRegularExpression] {
    return try globs.map { glob in
        let escaped = NSRegularExpression.escapedPattern(for: glob)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        let pattern = "^\(escaped)$"
        do {
            return try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            throw ConcatError.patternCompilationFailed(pattern: glob, underlying: error)
        }
    }
}

public func matchesAny(_ regexes: [NSRegularExpression], url: URL) -> Bool {
    let path = url.path
    return regexes.contains { regex in
        regex.firstMatch(in: path, options: [], range: NSRange(path.startIndex..<path.endIndex, in: path)) != nil
    }
}

public func loadIgnoreMap(
    from url: URL
) throws -> IgnoreMap {
    do {
        return try ConignoreParser.parseFile(
            at: url
        )
    } catch {
        throw ConcatError.ignoreMapLoadFailed(
            url: url,
            underlying: error
        )
    }
}

public func shouldIgnore(_ url: URL, using map: IgnoreMap) -> Bool {
    return map.shouldIgnore(url)
}
