import Foundation
import IO

public struct ConcatenationCorpusRefresh: Sendable {
    public let document: ConcatenationDocument
    public let snapshot: ConcatenationSourceSnapshot
    public let delta: ConcatenationSourceDelta?

    public init(
        document: ConcatenationDocument,
        snapshot: ConcatenationSourceSnapshot,
        delta: ConcatenationSourceDelta?
    ) {
        self.document = document
        self.snapshot = snapshot
        self.delta = delta
    }

    public var isInitial: Bool {
        delta == nil
    }
}

public struct ConcatenationCorpusReconciliation: Sendable {
    public let previousSnapshot: ConcatenationSourceSnapshot?
    public let snapshot: ConcatenationSourceSnapshot
    public let delta: ConcatenationSourceDelta?
    public let statistics: ConcatenationStatistics.Cache

    public init(
        previousSnapshot: ConcatenationSourceSnapshot?,
        snapshot: ConcatenationSourceSnapshot,
        delta: ConcatenationSourceDelta?,
        statistics: ConcatenationStatistics.Cache
    ) {
        self.previousSnapshot = previousSnapshot
        self.snapshot = snapshot
        self.delta = delta
        self.statistics = statistics
    }

    public var isInitial: Bool {
        previousSnapshot == nil
    }
}

public struct ConcatenationCorpusSource:
    Sendable,
    Codable
{
    public let record: ConcatenationSourceRecord
    public let section: ConcatenationSection

    public init(
        record: ConcatenationSourceRecord,
        section: ConcatenationSection
    ) {
        self.record = record
        self.section = section
    }
}

public struct ConcatenationCorpusMaterialization:
    Sendable,
    Codable
{
    public let snapshot: ConcatenationSourceSnapshot
    public let sources: [ConcatenationCorpusSource]

    public init(
        snapshot: ConcatenationSourceSnapshot,
        sources: [ConcatenationCorpusSource]
    ) {
        self.snapshot = snapshot
        self.sources = sources
    }

    public var count: Int {
        sources.count
    }

    public var isEmpty: Bool {
        sources.isEmpty
    }
}

public enum ConcatenationCorpusError:
    Error,
    Sendable,
    Hashable
{
    case missingSnapshot(URL)
    case refreshDidNotProduceSnapshot(URL)
    case missingSection(String)
    case differentLocation(
        expected: URL,
        actual: URL
    )
    case staleDelta(
        expected: ContentFingerprint,
        actual: ContentFingerprint
    )
}
