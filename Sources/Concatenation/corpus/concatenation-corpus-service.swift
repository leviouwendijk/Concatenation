import Foundation
import IO

public actor ConcatenationCorpusService {
    private struct Entry: Sendable {
        let identifier: ConcatenationCorpusIdentifier
        let corpus: ConcatenationCorpus
        let definition: ConcatenationCorpusDefinition?
        let anchor: URL?
    }

    private let session: ConcatenationSession
    private var entries: [
        ConcatenationCorpusIdentifier: Entry
    ] = [:]

    public init(
        session: ConcatenationSession = .init()
    ) {
        self.session = session
    }

    @discardableResult
    public func attach(
        _ identifier: ConcatenationCorpusIdentifier,
        location: URL,
        plan: ConcatenationPlan,
        options: ConcatenationCorpusOptions = .defaults,
        policy: ConcatenationCorpusAttachPolicy = .reject_existing
    ) throws -> ConcatenationCorpusStatus {
        try install(
            identifier,
            location: location,
            plan: plan,
            options: options,
            policy: policy,
            definition: nil,
            anchor: nil
        )
    }

    @discardableResult
    public func define(
        _ identifier: ConcatenationCorpusIdentifier,
        location: URL,
        definition: ConcatenationCorpusDefinition,
        relativeTo anchor: URL,
        options: ConcatenationCorpusOptions = .defaults,
        policy: ConcatenationCorpusAttachPolicy = .reject_existing
    ) throws -> ConcatenationCorpusStatus {
        let anchor = anchor.standardizedFileURL
        let resolution = try definition.resolve(
            relativeTo: anchor
        )

        return try install(
            identifier,
            location: location,
            plan: resolution.plan,
            options: options,
            policy: policy,
            definition: definition,
            anchor: anchor
        )
    }

    public func definition(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationCorpusDefinition? {
        try requireEntry(
            identifier
        )
        .definition
    }

    @discardableResult
    public func patch(
        _ identifier: ConcatenationCorpusIdentifier,
        _ patch: ConcatenationCorpusDefinitionPatch
    ) throws -> ConcatenationCorpusStatus {
        let retained = try requireDefinition(
            identifier
        )
        let definition = retained.definition.applying(
            patch
        )
        let resolution = try definition.resolve(
            relativeTo: retained.anchor
        )

        return try install(
            identifier,
            location: retained.entry.corpus.location,
            plan: resolution.plan,
            options: retained.entry.corpus.options,
            policy: .replace_existing,
            definition: definition,
            anchor: retained.anchor
        )
    }

    @discardableResult
    public func reconcile(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationCorpusStatus {
        let retained = try requireDefinition(
            identifier
        )
        let resolution = try retained.definition.resolve(
            relativeTo: retained.anchor
        )

        return try install(
            identifier,
            location: retained.entry.corpus.location,
            plan: resolution.plan,
            options: retained.entry.corpus.options,
            policy: .replace_existing,
            definition: retained.definition,
            anchor: retained.anchor
        )
    }

    public func list() throws
        -> [ConcatenationCorpusStatus]
    {
        try entries.keys
            .sorted {
                $0.rawValue < $1.rawValue
            }
            .map {
                try status(
                    $0
                )
            }
    }

    public func status(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationCorpusStatus {
        let entry = try requireEntry(
            identifier
        )
        let snapshot = try entry.corpus.snapshot()

        return ConcatenationCorpusStatus(
            identifier: identifier,
            location: entry.corpus.location,
            fingerprint: snapshot?.fingerprint,
            sourceCount: snapshot?.count ?? 0
        )
    }

    public func snapshot(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationSourceSnapshot? {
        try requireEntry(
            identifier
        )
        .corpus
        .snapshot()
    }

    public func refresh(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationCorpusRefresh {
        try requireEntry(
            identifier
        )
        .corpus
        .refresh()
    }

    public func refresh(
        _ identifier: ConcatenationCorpusIdentifier,
        concurrency: IOConcurrency
    ) async throws -> ConcatenationCorpusRefresh {
        try await requireEntry(
            identifier
        )
        .corpus
        .refresh(
            concurrency: concurrency
        )
    }

    public func materialize(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationCorpusMaterialization? {
        try requireEntry(
            identifier
        )
        .corpus
        .materialize()
    }

    public func materialize(
        _ identifier: ConcatenationCorpusIdentifier,
        delta: ConcatenationSourceDelta
    ) throws -> ConcatenationCorpusMaterialization {
        try requireEntry(
            identifier
        )
        .corpus
        .materialize(
            delta
        )
    }

    public func invalidate(
        _ identifier: ConcatenationCorpusIdentifier,
        source: URL
    ) throws {
        try requireEntry(
            identifier
        )
        .corpus
        .invalidate(
            source: source
        )
    }

    @discardableResult
    public func detach(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> ConcatenationCorpusStatus {
        let status = try status(
            identifier
        )

        guard entries.removeValue(
            forKey: identifier
        ) != nil else {
            throw ConcatenationCorpusServiceError
                .unknownCorpus(
                    identifier
                )
        }

        return status
    }

    public func contains(
        _ identifier: ConcatenationCorpusIdentifier
    ) -> Bool {
        entries[identifier] != nil
    }
}

private extension ConcatenationCorpusService {
    @discardableResult
    private func install(
        _ identifier: ConcatenationCorpusIdentifier,
        location: URL,
        plan: ConcatenationPlan,
        options: ConcatenationCorpusOptions,
        policy: ConcatenationCorpusAttachPolicy,
        definition: ConcatenationCorpusDefinition?,
        anchor: URL?
    ) throws -> ConcatenationCorpusStatus {
        let location = location.standardizedFileURL

        if let existing = entries[identifier],
           policy == .reject_existing
        {
            throw ConcatenationCorpusServiceError
                .duplicateIdentifier(
                    existing.identifier
                )
        }

        if let existing = entries.values.first(
            where: {
                $0.identifier != identifier
                    && $0.corpus.location == location
            }
        ) {
            throw ConcatenationCorpusServiceError
                .locationAlreadyAttached(
                    location: location,
                    identifier: existing.identifier
                )
        }

        let corpus = ConcatenationCorpus(
            location: location,
            plan: plan,
            session: session,
            options: options
        )

        entries[identifier] = Entry(
            identifier: identifier,
            corpus: corpus,
            definition: definition,
            anchor: anchor?.standardizedFileURL
        )

        return try status(
            identifier
        )
    }

    private func requireEntry(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> Entry {
        guard let entry = entries[identifier] else {
            throw ConcatenationCorpusServiceError
                .unknownCorpus(
                    identifier
                )
        }

        return entry
    }

    private func requireDefinition(
        _ identifier: ConcatenationCorpusIdentifier
    ) throws -> (
        entry: Entry,
        definition: ConcatenationCorpusDefinition,
        anchor: URL
    ) {
        let entry = try requireEntry(
            identifier
        )

        guard let definition = entry.definition,
              let anchor = entry.anchor
        else {
            throw ConcatenationCorpusServiceError
                .definitionUnavailable(
                    identifier
                )
        }

        return (
            entry: entry,
            definition: definition,
            anchor: anchor
        )
    }
}
