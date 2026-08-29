import Concatenation
import Foundation
import Path
import PathParsing
import Position
import Selection
import TestFlows

extension ConcatenationFlowSuite {
    static var conCorpusDefinitionFlow: TestFlow {
        TestFlow(
            "con-corpus-definition",
            tags: [
                "corpus",
                "definition",
                "incremental",
                "path",
                "selection",
            ]
        ) {
            Step(
                "definition resolves Path and Selection without conany"
            ) {
                let fixture = try corpusDefinitionFixture(
                    "resolve"
                )

                defer {
                    fixture.remove()
                }

                let definition = try ConcatenationCorpusDefinition
                    .parsing(
                        includes: [
                            "*.swift",
                        ],
                        excludes: [
                            "B.swift",
                        ]
                    )
                let resolved = try definition.resolve(
                    relativeTo: fixture.root
                )

                try Expect.equal(
                    resolved.sources.count,
                    1,
                    "direct path definition resolves one source after exclusion"
                )
                try Expect.equal(
                    resolved.sources[0].file.lastPathComponent,
                    "A.swift",
                    "direct path definition retains resolved file identity"
                )
                try Expect.true(
                    resolved.sources[0].selections.isEmpty,
                    "plain path include retains whole-file source"
                )

                let lines = LineRange(
                    uncheckedStart: 2,
                    uncheckedEnd: 3
                )
                let selected = ConcatenationCorpusDefinition(
                    selections: [
                        PathSelectionExpression(
                            path: try PathParse.expression(
                                "A.swift"
                            ),
                            content: .lines(
                                lines
                            )
                        ),
                    ]
                )
                let selectedResolved = try selected.resolve(
                    relativeTo: fixture.root
                )

                try Expect.equal(
                    selectedResolved.sources.count,
                    1,
                    "selection-only definition resolves its source"
                )
                try Expect.equal(
                    selectedResolved.sources[0].selections,
                    [
                        .lines(
                            lines
                        ),
                    ],
                    "exact ContentSelection survives definition resolution"
                )
            }

            Step(
                "reconcile re-runs path membership while refresh preserves resolved plan"
            ) {
                let fixture = try corpusDefinitionFixture(
                    "reconcile"
                )

                defer {
                    fixture.remove()
                }

                let service = ConcatenationCorpusService()
                let definition = try ConcatenationCorpusDefinition
                    .parsing(
                        includes: [
                            "*.swift",
                        ]
                    )

                _ = try await service.define(
                    "dynamic",
                    location: fixture.location,
                    definition: definition,
                    relativeTo: fixture.root
                )

                let initial = try await service.refresh(
                    "dynamic"
                )

                try Expect.equal(
                    initial.snapshot.count,
                    2,
                    "initial direct definition retains both matching sources"
                )

                let c = fixture.root.appendingPathComponent(
                    "C.swift",
                    isDirectory: false
                )

                try "gamma\n".write(
                    to: c,
                    atomically: true,
                    encoding: .utf8
                )

                let staticRefresh = try await service.refresh(
                    "dynamic"
                )

                try Expect.equal(
                    staticRefresh.snapshot.count,
                    2,
                    "ordinary refresh preserves already-resolved membership"
                )

                _ = try await service.reconcile(
                    "dynamic"
                )

                let reconciled = try await service.refresh(
                    "dynamic"
                )
                let delta = try Expect.notNil(
                    reconciled.delta,
                    "reconciled refresh compares new membership to retained revision"
                )

                try Expect.equal(
                    reconciled.snapshot.count,
                    3,
                    "reconcile discovers newly matching source"
                )
                try Expect.equal(
                    delta.added.count,
                    1,
                    "reconcile produces one added source"
                )
                try Expect.equal(
                    delta.added[0].file.lastPathComponent,
                    "C.swift",
                    "reconcile delta identifies newly admitted source"
                )
            }

            Step(
                "definition patch narrows broad corpus to exact source selection"
            ) {
                let fixture = try corpusDefinitionFixture(
                    "patch"
                )

                defer {
                    fixture.remove()
                }

                let service = ConcatenationCorpusService()
                let broad = try PathParse.expression(
                    "*.swift"
                )
                let definition = ConcatenationCorpusDefinition(
                    includes: [
                        broad,
                    ]
                )

                _ = try await service.define(
                    "working",
                    location: fixture.location,
                    definition: definition,
                    relativeTo: fixture.root
                )

                let initial = try await service.refresh(
                    "working"
                )

                try Expect.equal(
                    initial.snapshot.count,
                    2,
                    "working corpus starts broad"
                )

                let lines = LineRange(
                    uncheckedStart: 2,
                    uncheckedEnd: 3
                )
                let selection = PathSelectionExpression(
                    path: try PathParse.expression(
                        "A.swift"
                    ),
                    content: .lines(
                        lines
                    )
                )

                _ = try await service.patch(
                    "working",
                    .init(
                        removeIncludes: [
                            broad,
                        ],
                        addSelections: [
                            selection,
                        ]
                    )
                )

                let narrowed = try await service.refresh(
                    "working"
                )
                let delta = try Expect.notNil(
                    narrowed.delta,
                    "definition patch remains revisioned against previous corpus"
                )

                try Expect.equal(
                    narrowed.snapshot.count,
                    1,
                    "patched corpus retains only selected source"
                )
                try Expect.equal(
                    delta.changed.count,
                    0,
                    "selection transformation changes logical retained-source identity"
                )
                try Expect.equal(
                    delta.added.count,
                    1,
                    "narrowing adds one selected-source identity"
                )
                try Expect.equal(
                    delta.added[0].file.lastPathComponent,
                    "A.swift",
                    "narrowing adds selected A source identity"
                )
                try Expect.equal(
                    delta.removed.count,
                    2,
                    "narrowing removes both previous whole-file source identities"
                )
                try Expect.equal(
                    delta.removed.map {
                        $0.file.lastPathComponent
                    },
                    [
                        "A.swift",
                        "B.swift",
                    ],
                    "narrowing removes whole-file A and unrelated B identities"
                )

                let materialization = try Expect.notNil(
                    try await service.materialize(
                        "working"
                    ),
                    "narrowed corpus materializes retained selection"
                )

                try Expect.equal(
                    materialization.count,
                    1,
                    "narrowed corpus materializes one source"
                )
                try Expect.equal(
                    materialization.sources[0].record.file.lastPathComponent,
                    "A.swift",
                    "narrowed materialization preserves source identity"
                )
                try Expect.equal(
                    materialization.sources[0].section.selectedLineCount,
                    2,
                    "narrowed materialization retains only requested line selection"
                )
            }
        }
    }

    private struct CorpusDefinitionFixture {
        let root: URL
        let a: URL
        let b: URL
        let location: URL

        func remove() {
            try? FileManager.default.removeItem(
                at: root
            )
        }
    }

    private static func corpusDefinitionFixture(
        _ name: String
    ) throws -> CorpusDefinitionFixture {
        let suffix = UUID()
            .uuidString
            .prefix(8)
        let root = URL(
            fileURLWithPath: "/tmp",
            isDirectory: true
        )
        .appendingPathComponent(
            "con-def-\(name.prefix(6))-\(suffix)",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let a = root.appendingPathComponent(
            "A.swift",
            isDirectory: false
        )
        let b = root.appendingPathComponent(
            "B.swift",
            isDirectory: false
        )

        try "one\ntwo\nthree\nfour\n".write(
            to: a,
            atomically: true,
            encoding: .utf8
        )
        try "beta\n".write(
            to: b,
            atomically: true,
            encoding: .utf8
        )

        return .init(
            root: root,
            a: a,
            b: b,
            location: root.appendingPathComponent(
                "working-context.txt",
                isDirectory: false
            )
        )
    }
}
