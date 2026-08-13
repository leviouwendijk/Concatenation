import Concatenation
import Foundation
import IO
import TestFlows
import Writers

extension ConcatenationFlowSuite {
    static var conAnyExecutionFlow: TestFlow {
        TestFlow(
            "con-any-execution",
            tags: [
                "con",
                "conany",
                "execution",
                "render",
                "cache",
            ]
        ) {
            Step(
                "typed execution resolves renders writes and reuses nested outputs"
            ) {
                let root = URL(
                    fileURLWithPath: NSTemporaryDirectory(),
                    isDirectory: true
                )
                .appendingPathComponent(
                    "concatenation-conany-execution-\(UUID().uuidString)",
                    isDirectory: true
                )

                defer {
                    try? FileSystem.default.remove(
                        root
                    )
                }

                let input = root.appendingPathComponent(
                    "input",
                    isDirectory: true
                )

                try FileSystem.default.directory.create(
                    input
                )

                let sourceA = input.appendingPathComponent(
                    "a.txt",
                    isDirectory: false
                )

                let sourceB = input.appendingPathComponent(
                    "b.txt",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    sourceA
                ).write(
                    """
                    alpha
                    beta
                    """,
                    options: .overwriteWithoutBackup
                )

                _ = try StandardWriter(
                    sourceB
                ).write(
                    """
                    gamma
                    delta
                    """,
                    options: .overwriteWithoutBackup
                )

                let configURL = root.appendingPathComponent(
                    ".conany",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    configURL
                ).write(
                    """
                    directory("nested") {
                        file("a-context.txt") {
                            context {
                                title = "A"
                            }

                            include(
                                from: "\(root.path)",
                                show: .relativeToBase
                            ) {
                                "input/a.txt"[2..2]
                            }
                        }
                    }

                    file("b-context.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/b.txt"
                        }
                    }
                    """,
                    options: .overwriteWithoutBackup
                )

                let execution = try ConAnyExecution(
                    configURL: configURL,
                    options: .init(
                        ignoreMap: IgnoreMap(),
                        delimiterStyle: .comment,
                        delimiterClosure: false,
                        maxLinesPerFile: nil,
                        rawOutput: false,
                        outputFormat: .text,
                        includeSourceLineNumbers: true,
                        includeSourceModifiedAt: false,
                        protectSecrets: false,
                        deepSecretInspection: false
                    )
                )

                let resolved = try execution.resolve()

                try Expect.equal(
                    resolved.map(
                        \.name
                    ),
                    [
                        "nested/a-context.txt",
                        "b-context.txt",
                    ],
                    "conany.execution.resolved-order"
                )

                let resolvedA = try Expect.notNil(
                    resolved.first {
                        $0.name
                            == "nested/a-context.txt"
                    },
                    "conany.execution.resolved-a"
                )

                try Expect.equal(
                    resolvedA.fileCount,
                    1,
                    "conany.execution.resolved-a-file-count"
                )

                try Expect.equal(
                    resolvedA.presentedPathByFile[
                        sourceA.standardizedFileURL
                    ] ?? "",
                    "./input/a.txt",
                    "conany.execution.presented-a"
                )

                let selectedA =
                    resolvedA.selectedContentByFile[
                        sourceA.standardizedFileURL
                    ] ?? []

                try Expect.equal(
                    selectedA.count,
                    1,
                    "conany.execution.resolved-a-selection-count"
                )

                let rendered = try await execution.render()

                try Expect.equal(
                    rendered.outputCount,
                    2,
                    "conany.execution.render-output-count"
                )

                try Expect.equal(
                    rendered.fileCount,
                    2,
                    "conany.execution.render-file-count"
                )

                try Expect.equal(
                    rendered.outputs.map(
                        \.name
                    ),
                    [
                        "nested/a-context.txt",
                        "b-context.txt",
                    ],
                    "conany.execution.render-output-order"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "===== .conany output: nested/a-context.txt ====="
                    ),
                    "conany.execution.render-a-boundary"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "===== .conany output: b-context.txt ====="
                    ),
                    "conany.execution.render-b-boundary"
                )

                let aBoundary = try Expect.notNil(
                    rendered.combinedText.range(
                        of: "===== .conany output: nested/a-context.txt ====="
                    ),
                    "conany.execution.render-a-boundary-range"
                )

                let bBoundary = try Expect.notNil(
                    rendered.combinedText.range(
                        of: "===== .conany output: b-context.txt ====="
                    ),
                    "conany.execution.render-b-boundary-range"
                )

                try Expect.true(
                    aBoundary.lowerBound
                        < bBoundary.lowerBound,
                    "conany.execution.render-boundary-order"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "2 | beta"
                    ),
                    "conany.execution.render-a-selected-content"
                )

                try Expect.true(
                    !rendered.combinedText.contains(
                        "1 | alpha"
                    ),
                    "conany.execution.render-a-unselected-content-absent"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "1 | gamma"
                    ),
                    "conany.execution.render-b-content"
                )

                let outputA = root
                    .appendingPathComponent(
                        "nested",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "a-context.txt",
                        isDirectory: false
                    )

                let outputB = root.appendingPathComponent(
                    "b-context.txt",
                    isDirectory: false
                )

                let cache = root.appendingPathComponent(
                    ".concatenation",
                    isDirectory: true
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        outputA
                    ),
                    "conany.execution.render-no-output-a"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        outputB
                    ),
                    "conany.execution.render-no-output-b"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        cache
                    ),
                    "conany.execution.render-no-cache"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        root.appendingPathComponent(
                            "context_index.txt",
                            isDirectory: false
                        )
                    ),
                    "conany.execution.render-no-context-index"
                )

                let cold = try await execution.write()

                try Expect.equal(
                    cold.outputCount,
                    2,
                    "conany.execution.write-output-count"
                )

                try Expect.true(
                    cold.performedWrite,
                    "conany.execution.cold-performed-write"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        outputA
                    ),
                    "conany.execution.write-output-a"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        outputB
                    ),
                    "conany.execution.write-output-b"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        cache
                    ),
                    "conany.execution.write-cache"
                )

                let contextIndex = root.appendingPathComponent(
                    "context_index.txt",
                    isDirectory: false
                )

                try Expect.equal(
                    cold.contextIndexAction,
                    .written(
                        contextIndex
                    ),
                    "conany.execution.context-index-written"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        contextIndex
                    ),
                    "conany.execution.context-index-exists"
                )

                let warm = try await execution.write()

                try Expect.true(
                    !warm.performedWrite,
                    "conany.execution.warm-no-write"
                )

                try Expect.true(
                    warm.outputs.allSatisfy {
                        !$0.result.performedRender
                    },
                    "conany.execution.warm-all-no-render"
                )

                try Expect.true(
                    warm.outputs.allSatisfy {
                        !$0.result.performedWrite
                    },
                    "conany.execution.warm-all-no-write"
                )

                try Expect.equal(
                    warm.contextIndexAction,
                    .unchanged(
                        contextIndex
                    ),
                    "conany.execution.context-index-unchanged"
                )
            }
        }
    }
}
