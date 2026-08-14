import Concatenation
import Darwin
import Foundation
import Terminal

struct ConcatenationRunIdentity:
    Sendable
{
    let value: String
    let startedAt: Date

    init(
        value: String = String(
            UUID()
                .uuidString
                .replacingOccurrences(
                    of: "-",
                    with: ""
                )
                .prefix(8)
        )
        .uppercased(),
        startedAt: Date = Date()
    ) {
        self.value = value
        self.startedAt = startedAt
    }

    var tagged: String {
        "#\(value)"
    }
}

private let concatenationRunStatusFrames = [
    "⠋",
    "⠙",
    "⠹",
    "⠸",
    "⠼",
    "⠴",
    "⠦",
    "⠧",
    "⠇",
    "⠏",
]

private let concatenationRunStatusFrameInterval:
    TimeInterval = 0.09

func makeConcatenationRunStatus(
    identity: ConcatenationRunIdentity,
    outputCount: Int,
    verbose: Bool
) -> TerminalLiveStatusLine? {
    guard concatenationRunStatusEnabled(
        verbose: verbose
    ) else {
        return nil
    }

    let outputWord =
        outputCount == 1
            ? "output"
            : "outputs"

    let label =
        "Concatenating "
        + "\(outputCount) "
        + outputWord
        + " · \(identity.tagged)"

    let frames = concatenationRunStatusFrames
    let frameInterval =
        concatenationRunStatusFrameInterval

    return TerminalLiveStatusLine(
        stream: .standardOutput,
        refreshIntervalNanoseconds: 90_000_000,
        hidesCursor: true
    ) { frame in
        let index =
            Int(
                frame.elapsedSeconds
                / frameInterval
            )
            % frames.count

        return frames[index]
            + " "
            + label
            + " · "
            + frame.elapsedText
    }
}

func concatenationRunStatusEnabled(
    verbose: Bool
) -> Bool {
    !verbose
        && isatty(
            STDOUT_FILENO
        ) == 1
}

func printConAnyRunSummary(
    _ result: ConAnyWriteBatchResult,
    identity: ConcatenationRunIdentity,
    completedAt: Date = Date(),
    verbose: Bool
) {
    let state: String

    switch result.executionKind {
    case .unchanged:
        state = "Unchanged"

    case .updated:
        state = "Updated"

    case .rebuilt:
        state = "Rebuilt"
    }

    let outputWord =
        result.outputCount == 1
            ? "output"
            : "outputs"

    let fileWord =
        result.fileCount == 1
            ? "file"
            : "files"

    print(
        "✓ \(state)"
            + " · \(formattedCount(result.outputCount)) \(outputWord)"
            + " · \(formattedCount(result.fileCount)) \(fileWord)"
            + " · \(formattedCount(result.totalLineCount)) lines"
    )

    print(
        "  resolution: "
            + formattedDuration(
                result.resolution.duration
            )
            + " · \(formattedCount(result.resolution.scanRequestCount)) specs"
            + " · \(formattedCount(result.resolution.plannedTraversalCount)) logical traversals"
            + " · \(formattedCount(result.resolution.physicalTraversalCount)) physical traversals"
            + " · \(formattedCount(result.resolution.uniqueRootCount)) unique roots"
            + " · \(formattedCount(result.resolution.unmatchedOutputCount)) unmatched"
    )

    let slowestPhysicalTraversals =
        result
        .resolution
        .physicalTraversals
        .sorted {
            lhs,
            rhs in

            if lhs.duration != rhs.duration {
                return lhs.duration
                    > rhs.duration
            }

            if lhs.entryCount != rhs.entryCount {
                return lhs.entryCount
                    > rhs.entryCount
            }

            return lhs.root.path
                < rhs.root.path
        }
        .prefix(
            8
        )

    if result.resolution.duration >= 0.5,
       !slowestPhysicalTraversals.isEmpty {
        print(
            "  slowest physical walks:"
        )

        for walk in slowestPhysicalTraversals {
            let entryWord =
                walk.entryCount == 1
                    ? "entry"
                    : "entries"

            let logicalRootWord =
                walk.logicalRootCount == 1
                    ? "logical root"
                    : "logical roots"

            print(
                "    "
                    + formattedDuration(
                        walk.duration
                    )
                    + " · \(formattedCount(walk.entryCount)) \(entryWord)"
                    + " · \(formattedCount(walk.logicalRootCount)) \(logicalRootWord)"
                    + " · \(walk.root.path)"
            )
        }
    }

    print(
        "  cache: "
            + "\(formattedCount(result.reusedSourceCount)) reused"
            + " · \(formattedCount(result.cache.rebuilds)) rebuilt"
            + " · \(formattedCount(result.cache.sourceReads)) source reads"
            + " · \(formattedCount(result.writtenOutputCount)) outputs written"
    )

    if verbose {
        print(
            "  cache detail: "
                + "\(formattedCount(result.cache.metadataHits)) metadata hits"
                + " · \(formattedCount(result.cache.contentHits)) content hits"
                + " · \(formattedCount(result.cache.metadataInspections)) inspections"
        )

        print(
            "                "
                + "\(formattedCount(result.cache.safeguardHits)) safeguard hits"
                + " · \(formattedCount(result.cache.safeguardReads)) safeguard reads"
                + " · \(formattedCount(result.renderedOutputCount)) outputs rendered"
        )
    }

    let elapsed = max(
        0,
        completedAt.timeIntervalSince(
            identity.startedAt
        )
    )

    print(
        "Done"
            + " · \(formattedDuration(elapsed))"
            + " · \(formattedTimestamp(completedAt))"
            + " · \(identity.tagged)"
    )
}

private func formattedDuration(
    _ seconds: TimeInterval
) -> String {
    if seconds < 10 {
        return String(
            format: "%.2fs",
            seconds
        )
    }

    if seconds < 60 {
        return String(
            format: "%.1fs",
            seconds
        )
    }

    let minutes = Int(
        seconds / 60
    )

    let remaining =
        seconds
        - Double(
            minutes * 60
        )

    return String(
        format: "%dm %.1fs",
        minutes,
        remaining
    )
}

private func formattedTimestamp(
    _ date: Date
) -> String {
    let formatter = DateFormatter()

    formatter.locale = Locale(
        identifier: "en_US_POSIX"
    )

    formatter.calendar = Calendar(
        identifier: .gregorian
    )

    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

    return formatter.string(
        from: date
    )
}

private func formattedCount(
    _ value: Int
) -> String {
    let formatter = NumberFormatter()

    formatter.locale = Locale(
        identifier: "en_US_POSIX"
    )

    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = ","
    formatter.maximumFractionDigits = 0

    return formatter.string(
        from: NSNumber(
            value: value
        )
    ) ?? "\(value)"
}
