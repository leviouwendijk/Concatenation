import Foundation

public struct ConignoreParser {
    private enum Section {
        case none, ignoreFiles, ignoreDirectories, obscure
    }

    public static func parse(_ content: String) throws -> IgnoreMap {
        var fileGlobs: [String] = []
        var dirGlobs: [String] = []
        var obscureMap: [String: String] = [:]
        var section: Section = .none

        for rawLine in content.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            switch line {
            case "[IgnoreFiles]":
                section = .ignoreFiles
                continue
            case "[IgnoreDirectories]":
                section = .ignoreDirectories
                continue
            case "[Obscure]":
                section = .obscure
                continue
            default:
                break
            }

            switch section {
            case .ignoreFiles:
                fileGlobs.append(line)
            case .ignoreDirectories:
                dirGlobs.append(line)
            case .obscure:
                let parts = line.split(separator: ":", maxSplits: 1)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2 {
                    obscureMap[parts[0]] = parts[1]
                } else if parts.count == 1 {
                    obscureMap[parts[0]] = "redact"
                }
            case .none:
                continue
            }
        }

        return try IgnoreMap(
            ignoreFiles: fileGlobs,
            ignoreDirectories: dirGlobs,
            obscureValues: obscureMap
        )
    }

    public static func parseFile(at url: URL) throws -> IgnoreMap {
        let rawContent = try String(contentsOf: url, encoding: .utf8)
        return try parse(rawContent)
    }
}
