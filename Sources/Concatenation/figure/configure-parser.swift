import Foundation

public enum Glob {
    public static func match(_ pattern: String, _ path: String) -> Bool {
        let esc = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            let re = try! NSRegularExpression(
                pattern: "^\(esc)$",
                options: []
            )
            let range = NSRange(path.startIndex..<path.endIndex, in: path)
            return re.firstMatch(in: path, options: [], range: range) != nil
    }
}

public struct ConfigureParser {
    public struct Filter {
        public let glob: String
        public let anchor: String
        public let offset: Int
        public let count: Int
    }

    public static func parse(_ content: String) -> [Filter] {
        var filters = [Filter]()
        var inSection = false

        for raw in content.split(separator: "\n").map(String.init) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line == "[Filters]" {
                inSection = true
                continue
            }
            guard inSection, let eq = line.firstIndex(of: "=") else { continue }

            let left = line[..<eq].trimmingCharacters(in: .whitespaces)
            let right = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)

            let parts = right.split(separator: " ", maxSplits: 1).map(String.init)
            let anchor = parts[0]
            var offset = 0, count = 1
            if parts.count > 1 {
                let rest = parts[1]
                let offCount = rest
                .split(separator: ":", maxSplits: 1)
                .map(String.init)
                if offCount[0].hasPrefix("+"), let o = Int(offCount[0].dropFirst()) {
                    offset = o
                }
                if offCount.count>1, let c = Int(offCount[1]) {
                    count = c
                }
            }

            filters.append(.init(glob: left, anchor: anchor, offset: offset, count: count))
        }

        return filters
    }

    public static func parseFile(at url: URL) throws -> [Filter] {
        let txt = try String(contentsOf: url)
            return parse(txt)
    }
}
