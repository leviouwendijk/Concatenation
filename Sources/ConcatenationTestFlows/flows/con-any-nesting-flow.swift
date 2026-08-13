import Foundation
import Concatenation
import IO
import Readers
import Writers
import TestFlows

extension ConcatenationFlowSuite {
    static var conAnyNestingFlow: TestFlow {
        TestFlow(
            "con-any-nesting",
            tags: [
                "con",
                "conany",
                "nesting",
                "cache",
            ]
        ) {
            Step("recursive directory blocks preserve output hierarchy") {
                let config = try ConAnyParser.parse(
                    """
                    directory("one") {
                        file("root.txt") {
                        }

                        directory("two") {
                            file("middle.txt") {
                            }

                            directory("three") {
                                file("deep.txt") {
                                }
                            }
                        }
                    }
                    """
                )

                try Expect.equal(
                    config.renderables
                        .map(\.output)
                        .sorted(),
                    [
                        "one/root.txt",
                        "one/two/middle.txt",
                        "one/two/three/deep.txt",
                    ],
                    "conany.nesting.outputs"
                )
            }

            Step("nested output preserves artifact and cache hierarchy") {
                let root = URL(
                    fileURLWithPath: NSTemporaryDirectory(),
                    isDirectory: true
                )
                .appendingPathComponent(
                    "concatenation-conany-nesting-\(UUID().uuidString)",
                    isDirectory: true
                )

                defer {
                    try? FileSystem.default.remove(
                        root
                    )
                }

                try FileSystem.default.directory.create(
                    root
                )

                let source = root.appendingPathComponent(
                    "source.txt",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    source
                ).write(
                    """
                    alpha
                    beta
                    gamma
                    """,
                    options: .overwriteWithoutBackup
                )

                let config = try ConAnyParser.parse(
                    """
                    directory("one") {
                        directory("two") {
                            directory("three") {
                                file("deep.txt") {
                                }
                            }
                        }
                    }
                    """
                )

                try Expect.equal(
                    config.renderables.count,
                    1,
                    "conany.nesting.renderable-count"
                )

                let renderable = config.renderables[0]

                let resolver = ConAnyResolver(
                    baseDir: root.path
                )

                let output = resolver.outputURL(
                    for: renderable
                )

                let expectedOutput = root
                    .appendingPathComponent(
                        "one",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "two",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "three",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "deep.txt",
                        isDirectory: false
                    )

                try Expect.equal(
                    output,
                    expectedOutput,
                    "conany.nesting.output-url"
                )

                let workspace = ConcatenationWorkspace(
                    root: root
                )

                let concatenator = FileConcatenator(
                    inputFiles: [
                        source,
                    ],
                    outputURL: output,
                    workspace: workspace,
                    presentedPathByFile: [
                        source: "source.txt",
                    ],
                    delimiterStyle: .comment,
                    maxLinesPerFile: nil,
                    trimBlankLines: true,
                    relativePaths: false,
                    includeSourceLineNumbers: true,
                    includeSourceModifiedAt: false,
                    protectSecrets: false
                )

                let cold = try concatenator.write()

                try Expect.true(
                    cold.performedRender,
                    "conany.nesting.cold-render"
                )

                try Expect.true(
                    cold.performedWrite,
                    "conany.nesting.cold-write"
                )

                let outputMetadata = try FileInspector(
                    output
                ).inspect()

                try Expect.true(
                    outputMetadata.existed,
                    "conany.nesting.output-exists"
                )

                let rendered = try TextFileReader(
                    output
                ).read().text

                try Expect.true(
                    rendered.contains(
                        "# source.txt"
                    ),
                    "conany.nesting.rendered-source"
                )

                try Expect.true(
                    rendered.contains(
                        "1 | alpha"
                    ),
                    "conany.nesting.rendered-content"
                )

                let expectedManifest = workspace.cache
                    .appendingPathComponent(
                        "one",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "two",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "three",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "deep.txt.json",
                        isDirectory: false
                    )

                try Expect.equal(
                    workspace.cacheManifest(
                        for: output
                    ),
                    expectedManifest,
                    "conany.nesting.cache-manifest-path"
                )

                let manifestMetadata = try FileInspector(
                    expectedManifest
                ).inspect()

                try Expect.true(
                    manifestMetadata.existed,
                    "conany.nesting.cache-manifest-exists"
                )

                let sections = workspace.cachedSections(
                    for: output
                )

                let sectionsMetadata = try FileInspector(
                    sections
                ).inspect()

                try Expect.true(
                    sectionsMetadata.existed,
                    "conany.nesting.sections-exist"
                )

                let cachedSections = try FileSystem.default
                    .directory
                    .contents(
                        sections
                    )
                    .filter {
                        $0.pathExtension == "json"
                    }

                try Expect.equal(
                    cachedSections.count,
                    1,
                    "conany.nesting.cached-section-count"
                )

                let warm = try concatenator.write()

                try Expect.true(
                    !warm.performedRender,
                    "conany.nesting.warm-no-render"
                )

                try Expect.true(
                    !warm.performedWrite,
                    "conany.nesting.warm-no-write"
                )
            }
        }
    }
}
