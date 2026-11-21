import Concatenation
import ConcatenationLegacy
import Foundation
import IO
import TestFlows
import Writers

extension ConcatenationFlowSuite {
    static var conAnyLoweringFlow: TestFlow {
        TestFlow(
            "con-any-lowering",
            tags: [
                "con",
                "conany",
                "conignore",
                "definition",
            ]
        ) {
            Step(
                ".conignore entries keep their whole-path glob semantics as excludes"
            ) {
                let root = URL(
                    fileURLWithPath: NSTemporaryDirectory(),
                    isDirectory: true
                )
                .appendingPathComponent(
                    "concatenation-conany-lowering-\(UUID().uuidString)",
                    isDirectory: true
                )
                .standardizedFileURL

                defer {
                    try? FileSystem.default.remove(
                        root
                    )
                }

                for (path, text) in [
                    ("src/main.swift", "let a = 1"),
                    ("src/debug.log", "log"),
                    ("src/trace.lo1", "log"),
                    ("vendor/lib.swift", "let b = 2"),
                ] {
                    _ = try StandardWriter(
                        root.appendingPathComponent(
                            path,
                            isDirectory: false
                        )
                    ).write(
                        text,
                        options: .overwriteWithoutBackup
                    )
                }

                let configURL = root.appendingPathComponent(
                    ".conany",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    configURL
                ).write(
                    """
                    file("all.txt") {
                        include(from: "\(root.path)", show: .relativeToBase) {
                            "**/*"
                        }
                    }
                    """,
                    options: .overwriteWithoutBackup
                )

                // `*.log` and `*.lo?` matched before; `vendor` and `src/` never
                // matched an absolute path, so they must not start excluding now.
                let ignoreMap = try IgnoreMap(
                    ignoreFiles: ["*.log", "*.lo?"],
                    ignoreDirectories: ["vendor", "src/"],
                    obscureValues: [:]
                )

                let execution = try ConcatenationExecution(
                    conAnyAt: configURL,
                    ignoreMap: ignoreMap,
                    options: .init(
                        protectSecrets: false,
                        deepSecretInspection: false
                    )
                )

                let resolved = try execution.resolve()

                try Expect.equal(
                    resolved.count,
                    1,
                    "conany.lowering.output-count"
                )

                try Expect.equal(
                    resolved[0].sources.map(\.presentedPath),
                    [
                        "./src/main.swift",
                        "./vendor/lib.swift",
                    ],
                    "conany.lowering.conignore-excludes"
                )

                try Expect.equal(
                    resolved[0].outputURL,
                    root.appendingPathComponent(
                        "all.txt",
                        isDirectory: false
                    ),
                    "conany.lowering.destination"
                )
            }
        }
    }
}
