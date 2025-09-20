import Foundation

public struct ConcatenationContext {
    public let title: String?
    public let details: String?
    public let dependencies: [String]?
    public let concatenatedFile: String?
    
    public init(
        title: String?,
        details: String?,
        dependencies: [String]? = nil,
        concatenatedFile: String? = nil
    ) {
        self.title = title
        self.details = details
        self.dependencies = dependencies
        self.concatenatedFile = concatenatedFile
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }()

    public func jsonEncodedString(_ s: String) -> String {
        if let data = try? encoder.encode(s), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    func jsonEncodedArray(_ arr: [String]) -> String {
        if let data = try? encoder.encode(arr), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[" + arr.map { jsonEncodedString($0) }.joined(separator: ", ") + "]"
    }

    private func indentFollowingLines(_ multiLine: String, by spaces: Int) -> String {
        guard let nlRange = multiLine.firstIndex(of: "\n") else { return multiLine }
        let firstLine = String(multiLine[..<nlRange])
        let rest = String(multiLine[multiLine.index(after: nlRange)...])
        let restIndented = rest.indent(spaces)
        return firstLine + "\n" + restIndented
    }

    public func header(outputURL: URL) -> String {
        let iso = ISO8601DateFormatter().string(from: Date())

        var pairs: [(String, String)] = []
        if let t = self.title { pairs.append(("title", jsonEncodedString(t))) }
        if let d = self.details { pairs.append(("details", jsonEncodedString(d))) }
        if let deps = self.dependencies, !deps.isEmpty { pairs.append(("dependencies", jsonEncodedArray(deps))) }
        if let cf = self.concatenatedFile { pairs.append(("concatenated_file", jsonEncodedString(cf))) }
        pairs.append(("output", jsonEncodedString(outputURL.path)))
        pairs.append(("generated_at", jsonEncodedString(iso)))

        var lines: [String] = []
        lines.append("---CONTEXT-HEADER-BEGIN---")
        lines.append("{")
        for (i, kv) in pairs.enumerated() {
            let (k, v) = kv
            let comma = (i == pairs.count - 1) ? "" : ","
            if v.contains("\n") {
                // put first line inline, indent following lines by 2 spaces (parent indent)
                let indented = indentFollowingLines(v, by: 2)
                lines.append("  \"\(k)\" : \(indented)\(comma)")
            } else {
                lines.append("  \"\(k)\" : \(v)\(comma)")
            }
        }
        lines.append("}")
        lines.append("---CONTEXT-HEADER-END---")

        return lines.joined(separator: "\n")
    }

    public func object(outputURL: URL) -> String {
        let iso = ISO8601DateFormatter().string(from: Date())

        var pairs: [(String, String)] = []
        if let t = self.title { pairs.append(("title", jsonEncodedString(t))) }
        if let d = self.details { pairs.append(("details", jsonEncodedString(d))) }
        if let deps = self.dependencies, !deps.isEmpty { pairs.append(("dependencies", jsonEncodedArray(deps))) }
        if let cf = self.concatenatedFile { pairs.append(("concatenated_file", jsonEncodedString(cf))) }
        pairs.append(("output", jsonEncodedString(outputURL.path)))
        pairs.append(("generated_at", jsonEncodedString(iso)))

        var lines: [String] = []
        lines.append("{")
        for (i, kv) in pairs.enumerated() {
            let (k, v) = kv
            let comma = (i == pairs.count - 1) ? "" : ","
            if v.contains("\n") {
                // put first line inline, indent following lines by 2 spaces (parent indent)
                let indented = indentFollowingLines(v, by: 2)
                lines.append("  \"\(k)\" : \(indented)\(comma)")
            } else {
                lines.append("  \"\(k)\" : \(v)\(comma)")
            }
        }
        lines.append("}")

        return lines.joined(separator: "\n")
    }
}
