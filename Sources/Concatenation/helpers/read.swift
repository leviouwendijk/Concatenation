import Foundation
import Readers

public func readLines(
    from url: URL
) throws -> [String] {
    let result = try LineReader(url).read(
        options: .init(
            text: .init(
                decoding: .commonTextFallbacks,
                missingFilePolicy: .throwError,
                newlineNormalization: .unix
            )
        )
    )

    return result.lines
}

public func processBlankLines(
    _ lines: [String],
    trim: Bool
) -> ([String], (header: String, footer: String)) {
    guard trim else {
        return (lines, ("", ""))
    }

    let arr = lines
    var lead = 0
    var trail = 0

    while lead < arr.count,
          arr[lead]
            .trimmingCharacters(in: .whitespaces)
            .isEmpty {
        lead += 1
    }

    while trail < arr.count - lead,
          arr[arr.count - 1 - trail]
            .trimmingCharacters(in: .whitespaces)
            .isEmpty {
        trail += 1
    }

    let header = lead > 0
        ? "(!): \(lead) blank lines\n"
        : ""

    let footer = trail > 0
        ? "\n(!): \(trail) blank lines\n"
        : ""

    let trimmed = Array(
        arr.dropFirst(lead).dropLast(trail)
    )

    return (trimmed, (header, footer))
}
