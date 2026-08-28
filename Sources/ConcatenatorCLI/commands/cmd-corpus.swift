import Arguments
import Concatenation
import ConcatenationServiceTransport
import Foundation

struct CorpusCommand: ArgumentCommand {
    static let name = "corpus"

    static var defaultChild: CorpusListCommand.Type {
        CorpusListCommand.self
    }

    static var children: [ArgumentCommandType] {
        [
            CorpusAttachCommand.self,
            CorpusImportCommand.self,
            CorpusListCommand.self,
            CorpusStatusCommand.self,
            CorpusRefreshCommand.self,
            CorpusSnapshotCommand.self,
            CorpusMaterializeCommand.self,
            CorpusDetachCommand.self,
        ]
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Interact with retained corpora owned by the persistent Concatenation service."
            ),
        ]
    }
}

struct CorpusAttachCommand: RunnableArgumentCommand {
    static let name = "attach"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Resolve a .conany definition on the persistent host and attach its output as a retained corpus."
            ),
            arg(
                "identifier",
                as: String.self,
                help: "Stable name for the retained corpus."
            ),
            opt(
                "config",
                as: String.self,
                help: "Path to .conany. Defaults to .conany in the current directory."
            ),
            opt(
                "output",
                as: String.self,
                help: "Named .conany output to attach when the configuration has multiple outputs."
            ),
            flag(
                "replace",
                help: "Replace an existing corpus with the same identifier by re-resolving the configuration."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let identifier = try corpusIdentifier(
            invocation
        )
        let configuration = resolvedConAnyConfig(
            try invocation.value(
                "config",
                as: String.self
            ),
            cwd: currentConAnyDirectory()
        )
        let output = try invocation.value(
            "output",
            as: String.self
        )
        let replace = try invocation.flag(
            "replace"
        )

        let status = try await ConcatenationServiceClient()
            .attach(
                identifier,
                configuration: configuration,
                output: output,
                policy: replace
                    ? .replace_existing
                    : .reject_existing
            )

        printCorpusStatus(
            status,
            action: replace ? "replaced" : "attached"
        )
    }
}

struct CorpusImportCommand: RunnableArgumentCommand {
    static let name = "import"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Resolve every output in a .conany catalog on the persistent host and attach each as an independent retained corpus."
            ),
            opt(
                "config",
                as: String.self,
                help: "Path to .conany. Defaults to .conany in the current directory."
            ),
            opt(
                "prefix",
                as: String.self,
                help: "Optional hierarchical prefix prepended to every imported corpus identifier."
            ),
            flag(
                "replace",
                help: "Re-resolve the catalog and replace already-attached corpus identifiers."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let configuration = resolvedConAnyConfig(
            try invocation.value(
                "config",
                as: String.self
            ),
            cwd: currentConAnyDirectory()
        )
        let prefix = try invocation.value(
            "prefix",
            as: String.self
        )
        let replace = try invocation.flag(
            "replace"
        )

        let statuses = try await ConcatenationServiceClient()
            .importCorpora(
                configuration: configuration,
                prefix: prefix,
                policy: replace
                    ? .replace_existing
                    : .reject_existing
            )

        print(
            "\(replace ? "re-imported" : "imported") · \(statuses.count) corpora"
        )

        for status in statuses {
            printCorpusStatus(
                status
            )
        }
    }
}

struct CorpusListCommand: RunnableArgumentCommand {
    static let name = "list"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "List retained corpora attached to the persistent service."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let statuses = try await ConcatenationServiceClient()
            .list()

        guard !statuses.isEmpty else {
            print("No retained corpora attached.")
            return
        }

        for status in statuses {
            printCorpusStatus(
                status
            )
        }
    }
}

struct CorpusStatusCommand: RunnableArgumentCommand {
    static let name = "status"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Show retained state for one corpus."
            ),
            corpusIdentifierArgument(),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let status = try await ConcatenationServiceClient()
            .status(
                try corpusIdentifier(
                    invocation
                )
            )

        printCorpusStatus(
            status
        )
    }
}

struct CorpusRefreshCommand: RunnableArgumentCommand {
    static let name = "refresh"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Incrementally refresh the sources in an already-resolved retained corpus."
            ),
            corpusIdentifierArgument(),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let identifier = try corpusIdentifier(
            invocation
        )
        let refresh = try await ConcatenationServiceClient()
            .refresh(
                identifier
            )

        if let delta = refresh.delta {
            print(
                "\(identifier.rawValue) refreshed · \(refresh.snapshot.count) sources · +\(delta.added.count) ~\(delta.changed.count) -\(delta.removed.count) =\(delta.unchangedCount)"
            )
        } else {
            print(
                "\(identifier.rawValue) refreshed · initial · \(refresh.snapshot.count) sources"
            )
        }
    }
}

struct CorpusSnapshotCommand: RunnableArgumentCommand {
    static let name = "snapshot"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Inspect the current retained source snapshot without materializing section content."
            ),
            corpusIdentifierArgument(),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let identifier = try corpusIdentifier(
            invocation
        )
        let snapshot = try await ConcatenationServiceClient()
            .snapshot(
                identifier
            )

        guard let snapshot else {
            print(
                "\(identifier.rawValue) has no retained snapshot; run corpus refresh first."
            )
            return
        }

        print(
            "\(identifier.rawValue) snapshot · \(snapshot.count) sources · \(snapshot.fingerprint)"
        )

        for source in snapshot.sources {
            print(
                source.file.path
            )
        }
    }
}

struct CorpusMaterializeCommand: RunnableArgumentCommand {
    static let name = "materialize"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Load retained source sections for a corpus and report the materialized source set."
            ),
            corpusIdentifierArgument(),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let identifier = try corpusIdentifier(
            invocation
        )
        let materialization = try await ConcatenationServiceClient()
            .materialize(
                identifier
            )

        guard let materialization else {
            print(
                "\(identifier.rawValue) has no retained snapshot; run corpus refresh first."
            )
            return
        }

        print(
            "\(identifier.rawValue) materialized · \(materialization.count) sources"
        )

        for source in materialization.sources {
            print(
                "\(source.section.presentedPath) · \(source.section.selectedLineCount) selected lines"
            )
        }
    }
}

struct CorpusDetachCommand: RunnableArgumentCommand {
    static let name = "detach"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Detach a named corpus from the persistent service without invalidating its retained cache."
            ),
            corpusIdentifierArgument(),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let status = try await ConcatenationServiceClient()
            .detach(
                try corpusIdentifier(
                    invocation
                )
            )

        printCorpusStatus(
            status,
            action: "detached"
        )
    }
}

private func corpusIdentifierArgument()
    -> CommandComponentLowerable
{
    arg(
        "identifier",
        as: String.self,
        help: "Retained corpus identifier."
    )
}

private func corpusIdentifier(
    _ invocation: ParsedInvocation
) throws -> ConcatenationCorpusIdentifier {
    ConcatenationCorpusIdentifier(
        rawValue: try invocation.require(
            "identifier",
            as: String.self
        )
    )
}

private func printCorpusStatus(
    _ status: ConcatenationCorpusStatus,
    action: String? = nil
) {
    let state = status.hasSnapshot
        ? "retained"
        : "unrefreshed"
    let prefix = action.map {
        "\($0) · "
    } ?? ""

    print(
        "\(prefix)\(status.identifier.rawValue) · \(state) · \(status.sourceCount) sources · \(status.location.path)"
    )
}

