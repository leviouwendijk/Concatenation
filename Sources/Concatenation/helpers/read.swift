import Foundation

public func readLines(from url: URL) throws -> [String] {
    let raw = try String(contentsOf: url, encoding: .utf8)
    return raw.components(separatedBy: .newlines)
}

public func processBlankLines(_ lines: [String], trim: Bool) -> ([String], (header: String, footer: String)) {
    guard trim else {
        return (lines, ("", ""))
    }
    let arr = lines
    var lead = 0, trail = 0

    while lead < arr.count, arr[lead].trimmingCharacters(in: .whitespaces).isEmpty {
        lead += 1
    }
    while trail < arr.count - lead,
          arr[arr.count - 1 - trail].trimmingCharacters(in: .whitespaces).isEmpty {
        trail += 1
    }

    let header = lead > 0 ? "(!): \(lead) blank lines\n" : ""
    let footer = trail > 0 ? "\n(!): \(trail) blank lines\n" : ""
    let trimmed = Array(arr.dropFirst(lead).dropLast(trail))
    return (trimmed, (header, footer))
}
