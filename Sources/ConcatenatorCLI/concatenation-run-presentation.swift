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
    let stateStyle: TerminalStyle

    switch result.executionKind {
    case .unchanged:
        state = "Unchanged"
        stateStyle = .init(.green, .bold)

    case .updated:
        state = "Updated"
        stateStyle = .init(.cyan, .bold)

    case .rebuilt:
        state = "Rebuilt"
        stateStyle = .init(.yellow, .bold)
    }

    let outputWord =
        result.outputCount == 1
            ? "output"
            : "outputs"

    let fileWord =
        result.fileCount == 1
            ? "file"
            : "files"

    let isTerminal =
        isatty(
            STDOUT_FILENO
        ) == 1

    let theme: TerminalTheme =
        isTerminal
            ? TerminalTheme(
                heading: .bold,
                label: .init(.brightBlack),
                value: .none,
                caption: .init(.brightBlack)
            )
            : .plain

    let layout = TerminalBlockLayout(
        fieldIndent: 2,
        labelWidth: .minimum(16),
        labelValueSpacing: 2,
        blankLinesAfter: 0
    )

    let width = Terminal.size(
        for: .standardOutput
    ).columns

    let styledState =
        isTerminal
            ? stateStyle.apply(state)
            : state

    var sections: [TerminalDetailSection] = [
        .init(
            title: "Resolution",
            items: [
                .field(
                    label: "total",
                    value: formattedDuration(
                        result.resolution.duration
                    )
                ),
                .field(
                    label: "specs",
                    value: formattedCount(
                        result.resolution.scanRequestCount
                    )
                ),
                .field(
                    label: "logical",
                    value: formattedCount(
                        result.resolution.plannedTraversalCount
                    )
                ),
                .field(
                    label: "physical",
                    value: formattedCount(
                        result.resolution.physicalTraversalCount
                    )
                ),
                .field(
                    label: "unique roots",
                    value: formattedCount(
                        result.resolution.uniqueRootCount
                    )
                ),
                .field(
                    label: "unmatched",
                    value: formattedCount(
                        result.resolution.unmatchedOutputCount
                    )
                ),
            ]
        )
    ]

    if result.resolution.duration >= 0.5 {
        let resolver =
            result.resolution.resolver

        let selection =
            resolver.selection

        let pathStages =
            selection.path

        let measuredDuration =
            resolver.specificationDuration
            + resolver.compilationDuration
            + pathStages.planningDuration
            + pathStages.walkingDuration
            + pathStages.dispatchDuration
            + pathStages.resultConstructionDuration
            + selection.resultConstructionDuration
            + resolver.filteringDuration
            + resolver.assemblyDuration
            + result.resolution.outputAssemblyDuration

        let otherDuration =
            max(
                0,
                result.resolution.duration
                    - measuredDuration
            )

        sections.append(
            .init(
                title: "Resolver stages",
                items: [
                    .field(
                        label: "spec",
                        value: formattedDuration(
                            resolver.specificationDuration
                        )
                    ),
                    .field(
                        label: "compile",
                        value: formattedDuration(
                            resolver.compilationDuration
                        )
                    ),
                    .field(
                        label: "path plan",
                        value: formattedDuration(
                            pathStages.planningDuration
                        )
                    ),
                    .field(
                        label: "walk",
                        value: formattedDuration(
                            pathStages.walkingDuration
                        )
                    ),
                    .field(
                        label: "dispatch",
                        value: formattedDuration(
                            pathStages.dispatchDuration
                        )
                    ),
                    .field(
                        label: "path results",
                        value: formattedDuration(
                            pathStages.resultConstructionDuration
                        )
                    ),
                    .field(
                        label: "selection",
                        value: formattedDuration(
                            selection.resultConstructionDuration
                        )
                    ),
                    .field(
                        label: "filter",
                        value: formattedDuration(
                            resolver.filteringDuration
                        )
                    ),
                    .field(
                        label: "resolver",
                        value: formattedDuration(
                            resolver.assemblyDuration
                        )
                    ),
                    .field(
                        label: "output",
                        value: formattedDuration(
                            result.resolution.outputAssemblyDuration
                        )
                    ),
                    .field(
                        label: "other",
                        value: formattedDuration(
                            otherDuration
                        )
                    ),
                ]
            )
        )

        let physicalWalks =
            result
            .resolution
            .physicalTraversals

        let enumerationDuration =
            physicalWalks.reduce(0) {
                $0 + $1.directoryEnumerationDuration
            }

        let inspectionDuration =
            physicalWalks.reduce(0) {
                $0 + $1.metadataInspectionDuration
            }

        let childSortingDuration =
            physicalWalks.reduce(0) {
                $0 + $1.childSortingDuration
            }

        let bookkeepingDuration =
            physicalWalks.reduce(0) {
                $0 + $1.bookkeepingDuration
            }

        let resultSortingDuration =
            physicalWalks.reduce(0) {
                $0 + $1.resultSortingDuration
            }

        let slowestPhysicalTraversals =
            physicalWalks
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
            .prefix(8)

        var walkItems: [TerminalDetailItem] = [
            .field(
                label: "total",
                value: formattedDuration(
                    pathStages.walkingDuration
                )
            ),
            .field(
                label: "enumerate",
                value: formattedDuration(
                    enumerationDuration
                )
            ),
            .field(
                label: "inspect",
                value: formattedDuration(
                    inspectionDuration
                )
            ),
            .field(
                label: "child sort",
                value: formattedDuration(
                    childSortingDuration
                )
            ),
            .field(
                label: "bookkeeping",
                value: formattedDuration(
                    bookkeepingDuration
                )
            ),
            .field(
                label: "final sort",
                value: formattedDuration(
                    resultSortingDuration
                )
            ),
        ]

        if !slowestPhysicalTraversals.isEmpty {
            walkItems.append(
                .list(
                    label: "slowest",
                    values: slowestPhysicalTraversals.map { walk in
                        let entryWord =
                            walk.entryCount == 1
                                ? "entry"
                                : "entries"

                        let logicalRootWord =
                            walk.logicalRootCount == 1
                                ? "logical root"
                                : "logical roots"

                        return formattedDuration(
                            walk.duration
                        )
                            + " · \(formattedCount(walk.entryCount)) \(entryWord)"
                            + " · \(formattedCount(walk.logicalRootCount)) \(logicalRootWord)"
                            + " · \(walk.root.path)"
                    }
                )
            )
        }

        sections.append(
            .init(
                title: "Path walk",
                items: walkItems
            )
        )
    }

    var cacheItems: [TerminalDetailItem] = [
        .field(
            label: "reused",
            value: formattedCount(
                result.reusedSourceCount
            )
        ),
        .field(
            label: "rebuilt",
            value: formattedCount(
                result.cache.rebuilds
            )
        ),
        .field(
            label: "source reads",
            value: formattedCount(
                result.cache.sourceReads
            )
        ),
        .field(
            label: "outputs rendered",
            value: formattedCount(
                result.renderedOutputCount
            )
        ),
        .field(
            label: "outputs written",
            value: formattedCount(
                result.writtenOutputCount
            )
        ),
    ]

    if verbose {
        cacheItems.append(
            contentsOf: [
                .field(
                    label: "metadata hits",
                    value: formattedCount(
                        result.cache.metadataHits
                    )
                ),
                .field(
                    label: "content hits",
                    value: formattedCount(
                        result.cache.contentHits
                    )
                ),
                .field(
                    label: "inspections",
                    value: formattedCount(
                        result.cache.metadataInspections
                    )
                ),
                .field(
                    label: "safeguard hits",
                    value: formattedCount(
                        result.cache.safeguardHits
                    )
                ),
                .field(
                    label: "safeguard reads",
                    value: formattedCount(
                        result.cache.safeguardReads
                    )
                ),
            ]
        )
    }

    sections.append(
        .init(
            title: "Cache",
            items: cacheItems
        )
    )

    let sourcePreflight =
        result.sourcePreflight

    if sourcePreflight.sourceReferenceCount > 0 {
        sections.append(
            .init(
                title: "Source preflight",
                items: [
                    .field(
                        label: "total",
                        value: formattedDuration(
                            sourcePreflight.duration
                        )
                    ),
                    .field(
                        label: "references",
                        value: formattedCount(
                            sourcePreflight
                                .sourceReferenceCount
                        )
                    ),
                    .field(
                        label: "unique paths",
                        value: formattedCount(
                            sourcePreflight
                                .uniqueSourceCount
                        )
                    ),
                    .field(
                        label: "resolved files",
                        value: formattedCount(
                            sourcePreflight
                                .uniqueResolvedSourceCount
                        )
                    ),
                    .field(
                        label: "inspections",
                        value: formattedCount(
                            sourcePreflight
                                .metadataInspectionCount
                        )
                    ),
                    .field(
                        label: "shared hits",
                        value: formattedCount(
                            sourcePreflight
                                .sharedMetadataReuseCount
                        )
                    ),
                ]
            )
        )
    }

    let execution =
        result.statistics

    sections.append(
        .init(
            title: "Execution",
            items: [
                .field(
                    label: "total",
                    value: formattedDuration(
                        execution.duration
                    )
                ),
                .field(
                    label: "resolution",
                    value: formattedDuration(
                        execution.resolutionDuration
                    )
                ),
                .field(
                    label: "outputs",
                    value: formattedDuration(
                        execution.outputDuration
                    )
                ),
                .field(
                    label: "context",
                    value: formattedDuration(
                        execution.contextIndexDuration
                    )
                ),
                .field(
                    label: "other",
                    value: formattedDuration(
                        execution.otherDuration
                    )
                ),
            ]
        )
    )

    let outputWork =
        result.outputStatistics

    var outputItems: [TerminalDetailItem] = [
        .field(
            label: "prepare",
            value: formattedDuration(
                outputWork.preparation.duration
            )
        ),
        .field(
            label: "fingerprint",
            value: formattedDuration(
                outputWork.artifactFingerprintDuration
            )
        ),
        .field(
            label: "artifact check",
            value: formattedDuration(
                outputWork.artifactValidationDuration
            )
        ),
        .field(
            label: "render",
            value: formattedDuration(
                outputWork.renderDuration
            )
        ),
        .field(
            label: "write",
            value: formattedDuration(
                outputWork.outputWriteDuration
            )
        ),
        .field(
            label: "artifact record",
            value: formattedDuration(
                outputWork.artifactCreationDuration
            )
        ),
        .field(
            label: "cache persist",
            value: formattedDuration(
                outputWork.cachePersistenceDuration
            )
        ),
    ]

    if outputWork.clipboardDuration > 0
        || verbose
    {
        outputItems.append(
            .field(
                label: "clipboard",
                value: formattedDuration(
                    outputWork.clipboardDuration
                )
            )
        )
    }

    outputItems.append(
        .field(
            label: "other",
            value: formattedDuration(
                outputWork.otherDuration
            )
        )
    )

    sections.append(
        .init(
            title: "Output pipeline",
            items: outputItems
        )
    )

    let preparation =
        outputWork.preparation

    sections.append(
        .init(
            title: "Preparation",
            items: [
                .field(
                    label: "total",
                    value: formattedDuration(
                        preparation.duration
                    )
                ),
                .field(
                    label: "manifest",
                    value: formattedDuration(
                        preparation.cacheLoadDuration
                    )
                ),
                .field(
                    label: "inspect",
                    value: formattedDuration(
                        preparation.sourceInspectionDuration
                    )
                ),
                .field(
                    label: "safeguard",
                    value: formattedDuration(
                        preparation.safeguardDuration
                    )
                ),
                .field(
                    label: "reuse check",
                    value: formattedDuration(
                        preparation.reuseValidationDuration
                    )
                ),
                .field(
                    label: "section load",
                    value: formattedDuration(
                        preparation.sectionPreloadDuration
                    )
                ),
                .field(
                    label: "preread",
                    value: formattedDuration(
                        preparation.sourcePrereadDuration
                    )
                ),
                .field(
                    label: "assemble",
                    value: formattedDuration(
                        preparation.assemblyDuration
                    )
                ),
                .field(
                    label: "other",
                    value: formattedDuration(
                        preparation.otherDuration
                    )
                ),
            ]
        )
    )

    for section in sections {
        print(
            section.render(
                width: width,
                theme: theme,
                layout: layout
            ),
            terminator: ""
        )
    }

    let sourceActivityEdges:
        [TerminalRelationshipGraph.Edge] =
            result.outputs.flatMap {
                output
                    -> [TerminalRelationshipGraph.Edge] in
            var orderedSources: [URL] = []

            var activityBySource: [
                URL:
                    ConcatenationSourceActivity
            ] = [:]

            for activity
                in output.result.sourceActivities
            {
                let source =
                    activity.source

                if activityBySource[source] == nil {
                    orderedSources.append(
                        source
                    )
                }

                if activity.kind == .rebuilt
                    || activityBySource[source] == nil
                {
                    activityBySource[source] =
                        activity
                }
            }

            return orderedSources.compactMap {
                source
                    -> TerminalRelationshipGraph.Edge? in
                guard let activity =
                    activityBySource[source]
                else {
                    return nil
                }

                let presentedSource =
                    activity.presentedPath
                    ?? source.path

                let activityLabel: String

                switch activity.kind {
                case .reread:
                    activityLabel =
                        "reread"

                case .rebuilt:
                    activityLabel =
                        "rebuilt"
                }

                return TerminalRelationshipGraph.Edge(
                    input:
                        presentedSource
                        + " ["
                        + activityLabel
                        + "]",
                    output:
                        output.resolved.name
                )
            }
        }

    if !sourceActivityEdges.isEmpty {
        let sourceCount =
            Set(
                sourceActivityEdges.map {
                    edge in

                    edge.input
                }
            ).count

        let outputCount =
            Set(
                sourceActivityEdges.map {
                    edge in

                    edge.output
                }
            ).count

        print()

        let heading =
            "Source activity"
            + " · \(formattedCount(sourceCount)) "
            + (
                sourceCount == 1
                    ? "source"
                    : "sources"
            )
            + " → \(formattedCount(outputCount)) "
            + (
                outputCount == 1
                    ? "output"
                    : "outputs"
            )

        print(
            isTerminal
                ? TerminalStyle(
                    .bold
                ).apply(
                    heading
                )
                : heading
        )

        print()

        let graph =
            TerminalRelationshipGraph(
                edges:
                    sourceActivityEdges,
                inputTitle:
                    "Sources",
                outputTitle:
                    "Outputs",
                style:
                    isTerminal
                        ? .standard
                        : .plain
            )

        print(
            graph.render(
                width: width
            )
        )
    }

    let elapsed = max(
        0,
        completedAt.timeIntervalSince(
            identity.startedAt
        )
    )

    print()

    let timestamp =
        formattedTimestamp(
            completedAt
        )

    let completionLine: String

    if isTerminal {
        let subdued =
            TerminalStyle(
                .brightBlack
            )

        completionLine =
            subdued.apply(
                "Done at "
            )
            + timestamp
            + subdued.apply(
                " · \(identity.tagged)"
            )
    } else {
        completionLine =
            "Done at "
            + timestamp
            + " · \(identity.tagged)"
    }

    print(
        completionLine
    )

    print(
        "✓ "
            + styledState
            + " · \(formattedDuration(elapsed))"
            + " · \(formattedCount(result.outputCount)) \(outputWord)"
            + " · \(formattedCount(result.fileCount)) \(fileWord)"
            + " · \(formattedCount(result.totalLineCount)) lines"
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
