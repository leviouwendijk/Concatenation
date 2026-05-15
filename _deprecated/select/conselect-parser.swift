import Foundation

public struct ConselectParser {
    private enum Section { case none, patterns, directories, files }

    public static func parse(_ content: String) -> Conselect {
        var patterns   = [String]()
        var directories = [String]()
        var files      = [String]()
        var section: Section = .none

        for raw in content.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            switch line {
                case "[Patterns]":    section = .patterns;    continue
                case "[Directories]": section = .directories; continue
                case "[Files]":       section = .files;       continue
                default: break
            }

            switch section {
                case .patterns:    patterns.append(line)
                case .directories: directories.append(line)
                case .files:       files.append(line)
                case .none:        continue
            }
        }

        return Conselect(
            patterns: patterns,
            directories: directories,
            files: files
        )
    }

    public static func parseFile(at url: URL) throws -> Conselect {
        let raw = try String(contentsOf: url, encoding: .utf8)
        return parse(raw)
    }
}
