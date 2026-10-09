import Foundation
import IO

public struct ConcatenationCorpusOptions:
    Sendable,
    Codable,
    Hashable
{
    public var protectSecrets: Bool
    public var allowSecrets: Bool
    public var failOnBlockedFiles: Bool
    public var deepSecretInspection: Bool

    public init(
        protectSecrets: Bool = true,
        allowSecrets: Bool = false,
        failOnBlockedFiles: Bool = false,
        deepSecretInspection: Bool = false
    ) {
        self.protectSecrets = protectSecrets
        self.allowSecrets = allowSecrets
        self.failOnBlockedFiles = failOnBlockedFiles
        self.deepSecretInspection = deepSecretInspection
    }

    public static let defaults: Self = .init()
}

public struct ConcatenationCorpus: Sendable {
    public let location: URL
    public let plan: ConcatenationPlan
    public let cache: ConcatenationCacheBinding
    public let options: ConcatenationCorpusOptions

    public init(
        location: URL,
        plan: ConcatenationPlan,
        session: ConcatenationSession = .init(),
        options: ConcatenationCorpusOptions = .defaults
    ) {
        let location = location.standardizedFileURL

        self.location = location
        self.plan = plan
        self.cache = session.binding(
            for: location
        )
        self.options = options
    }

    public func snapshot() throws
        -> ConcatenationSourceSnapshot?
    {
        try cache.sourceSnapshot()
    }

    public func reconcile() throws
        -> ConcatenationCorpusReconciliation
    {
        let previous = try snapshot()
        let reconciliation = try concatenator()
            .reconcileSourceCache()
        guard let current = try snapshot() else {
            throw ConcatenationCorpusError.missingSnapshot(
                location
            )
        }
        let delta = try previous.map {
            try $0.delta(
                to: current
            )
        }

        return ConcatenationCorpusReconciliation(
            previousSnapshot: previous,
            snapshot: current,
            delta: delta,
            statistics: reconciliation.statistics
        )
    }

    public func refresh() throws
        -> ConcatenationCorpusRefresh
    {
        let previous = try snapshot()
        let document = try concatenator().document()
        let current = try currentSnapshotAfterRefresh()
        let delta = try previous.map {
            try $0.delta(
                to: current
            )
        }

        return ConcatenationCorpusRefresh(
            document: document,
            snapshot: current,
            delta: delta
        )
    }

    public func refresh(
        concurrency: IOConcurrency
    ) async throws -> ConcatenationCorpusRefresh {
        let previous = try snapshot()
        let document = try await concatenator().document(
            concurrency: concurrency
        )
        let current = try currentSnapshotAfterRefresh()
        let delta = try previous.map {
            try $0.delta(
                to: current
            )
        }

        return ConcatenationCorpusRefresh(
            document: document,
            snapshot: current,
            delta: delta
        )
    }

    public func materialize() throws
        -> ConcatenationCorpusMaterialization?
    {
        guard let snapshot = try snapshot() else {
            return nil
        }

        return try materialize(
            snapshot.sources,
            snapshot: snapshot
        )
    }

    public func materialize(
        _ delta: ConcatenationSourceDelta
    ) throws -> ConcatenationCorpusMaterialization {
        let scope = delta.scope.standardizedFileURL

        guard scope == location else {
            throw ConcatenationCorpusError.differentLocation(
                expected: location,
                actual: scope
            )
        }

        guard let snapshot = try snapshot() else {
            throw ConcatenationCorpusError.missingSnapshot(
                location
            )
        }

        guard snapshot.fingerprint == delta.fingerprint else {
            throw ConcatenationCorpusError.staleDelta(
                expected: delta.fingerprint,
                actual: snapshot.fingerprint
            )
        }

        let records = (
            delta.added
            + delta.changed.map(\.current)
        )
        .sorted(
            by: sourceOrder
        )

        return try materialize(
            records,
            snapshot: snapshot
        )
    }

    public func invalidate(
        source: URL
    ) throws {
        try cache.invalidate(
            source: source
        )
    }

    public func invalidate(
        sources: [URL]
    ) throws {
        try cache.invalidate(
            sources: sources
        )
    }
}

private extension ConcatenationCorpus {
    func concatenator() -> FileConcatenator {
        FileConcatenator(
            plan: plan,
            cache: cache,
            copyToClipboard: false,
            verbose: false,
            reportWarnings: false,
            protectSecrets: options.protectSecrets,
            allowSecrets: options.allowSecrets,
            failOnBlockedFiles: options.failOnBlockedFiles,
            deepSecretInspection:
                options.deepSecretInspection
        )
    }

    func currentSnapshotAfterRefresh() throws
        -> ConcatenationSourceSnapshot
    {
        guard let snapshot = try snapshot() else {
            throw ConcatenationCorpusError
                .refreshDidNotProduceSnapshot(
                    location
                )
        }

        return snapshot
    }

    func materialize(
        _ records: [ConcatenationSourceRecord],
        snapshot: ConcatenationSourceSnapshot
    ) throws -> ConcatenationCorpusMaterialization {
        var sources: [ConcatenationCorpusSource] = []

        sources.reserveCapacity(
            records.count
        )

        for record in records {
            guard let section = try cache.loadSection(
                key: record.sectionKey
            ) else {
                throw ConcatenationCorpusError.missingSection(
                    record.sectionKey
                )
            }

            sources.append(
                ConcatenationCorpusSource(
                    record: record,
                    section: section
                )
            )
        }

        return ConcatenationCorpusMaterialization(
            snapshot: snapshot,
            sources: sources
        )
    }

    func sourceOrder(
        _ lhs: ConcatenationSourceRecord,
        _ rhs: ConcatenationSourceRecord
    ) -> Bool {
        if lhs.file.path != rhs.file.path {
            return lhs.file.path < rhs.file.path
        }

        return lhs.sectionKey < rhs.sectionKey
    }
}
