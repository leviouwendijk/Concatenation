import Concatenation
import TestFlows

extension ConcatenationFlowSuite {
    static var conLegacyMigrationFlow: TestFlow {
        TestFlow(
            "con-legacy-migration",
            tags: [
                "con",
                "legacy",
                "migration",
                "parser",
            ]
        ) {
            Step("legacy render include list rewrites to file include block") {
                let legacy = """
                render(path.txt) {
                    include [
                        Sources/**/*.swift
                        Package.swift
                    ]

                    exclude [
                        .build/**
                    ]
                }
                """

                let migrated = try ConLegacyMigration.rewrite(
                    legacy
                )

                let expected = """
                file("path.txt") {
                    include {
                        "Sources/**/*.swift"
                        "Package.swift"
                    }

                    exclude {
                        ".build/**"
                    }
                }
                """

                try Expect.equal(
                    migrated,
                    expected,
                    "legacy-render-include-list"
                )
            }

            Step("legacy context dependencies rewrite to modern context block") {
                let legacy = """
                render(output.txt) {
                    context {
                        title = "Legacy"
                        details = "Old syntax"

                        dependencies [
                            Path
                            Selection
                        ]
                    }

                    include [
                        Sources/Thing.swift
                    ]
                }
                """

                let migrated = try ConLegacyMigration.rewrite(
                    legacy
                )

                try Expect.contains(
                    migrated,
                    "file(\"output.txt\")",
                    "legacy-context.file"
                )

                try Expect.contains(
                    migrated,
                    "title = \"Legacy\"",
                    "legacy-context.title"
                )

                try Expect.contains(
                    migrated,
                    "\"Path\"",
                    "legacy-context.path-dependency"
                )

                try Expect.contains(
                    migrated,
                    "\"Selection\"",
                    "legacy-context.selection-dependency"
                )

                try Expect.contains(
                    migrated,
                    "\"Sources/Thing.swift\"",
                    "legacy-context.include"
                )
            }

            Step("migrated output parses as canonical config") {
                let legacy = """
                render(any.txt) {
                    include [
                        Sources/**/*.swift
                    ]
                }
                """

                let migrated = try ConLegacyMigration.rewrite(
                    legacy
                )

                let config = try ConAnyParser.parse(
                    migrated
                )

                try Expect.equal(
                    config.renderables.count,
                    1,
                    "migrated.parse.count"
                )

                try Expect.equal(
                    config.renderables[0].output,
                    "any.txt",
                    "migrated.parse.output"
                )

                try Expect.equal(
                    config.renderables[0].includeBlocks[0].includes,
                    [
                        "Sources/**/*.swift",
                    ],
                    "migrated.parse.includes"
                )
            }
        }
    }
}
