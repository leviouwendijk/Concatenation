import Foundation
import IO

public struct ConcatenationSourceRecord:
    Sendable,
    Codable,
    Hashable
{
    public let metadata: FileMetadataSnapshot
    public let contentFingerprint: ContentFingerprint
    public let transformationFingerprint: ContentFingerprint

    public init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        transformationFingerprint: ContentFingerprint
    ) {
        self.metadata = metadata
        self.contentFingerprint = contentFingerprint
        self.transformationFingerprint = transformationFingerprint
    }

    public init(
        _ source: ConcatenationCachedSource
    ) {
        self.init(
            metadata: source.metadata,
            contentFingerprint: source.contentFingerprint,
            transformationFingerprint:
                source.transformationFingerprint
        )
    }

    public var file: URL {
        metadata.url.standardizedFileURL
    }

    public var sectionKey: String {
        ConcatenationCachedSource(
            metadata: metadata,
            contentFingerprint: contentFingerprint,
            transformationFingerprint:
                transformationFingerprint
        )
        .sectionKey
    }

    var identityKey: String {
        [
            file.path,
            transformationFingerprint.algorithm,
            transformationFingerprint.value,
        ]
        .joined(
            separator: "\u{1F}"
        )
    }
}

public struct ConcatenationSourceSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public let scope: URL
    public let fingerprint: ContentFingerprint
    public let sources: [ConcatenationSourceRecord]

    public init(
        scope: URL,
        sources: [ConcatenationSourceRecord]
    ) {
        let scope = scope.standardizedFileURL
        let sources = sources.sorted(
            by: Self.areInCanonicalOrder
        )

        self.scope = scope
        self.sources = sources
        self.fingerprint = Self.fingerprint(
            scope: scope,
            sources: sources
        )
    }

    public var count: Int {
        sources.count
    }

    public var isEmpty: Bool {
        sources.isEmpty
    }
}

public extension ConcatenationCacheBinding {
    func sourceSnapshot() throws
        -> ConcatenationSourceSnapshot?
    {
        guard let manifest = try load() else {
            return nil
        }

        return ConcatenationSourceSnapshot(
            scope: scope,
            sources: manifest.sources.map(
                ConcatenationSourceRecord.init
            )
        )
    }
}

private extension ConcatenationSourceSnapshot {
    static func areInCanonicalOrder(
        _ lhs: ConcatenationSourceRecord,
        _ rhs: ConcatenationSourceRecord
    ) -> Bool {
        if lhs.file.path != rhs.file.path {
            return lhs.file.path < rhs.file.path
        }

        if lhs.transformationFingerprint.algorithm
            != rhs.transformationFingerprint.algorithm
        {
            return lhs.transformationFingerprint.algorithm
                < rhs.transformationFingerprint.algorithm
        }

        if lhs.transformationFingerprint.value
            != rhs.transformationFingerprint.value
        {
            return lhs.transformationFingerprint.value
                < rhs.transformationFingerprint.value
        }

        return lhs.sectionKey < rhs.sectionKey
    }

    static func fingerprint(
        scope: URL,
        sources: [ConcatenationSourceRecord]
    ) -> ContentFingerprint {
        let records = sources.map { source in
            [
                source.file.path,
                source.contentFingerprint.algorithm,
                source.contentFingerprint.value,
                source.transformationFingerprint.algorithm,
                source.transformationFingerprint.value,
            ]
            .joined(
                separator: "\u{1F}"
            )
        }
        .joined(
            separator: "\u{1E}"
        )

        return .fingerprint(
            for: [
                scope.path,
                records,
            ]
            .joined(
                separator: "\u{1D}"
            )
        )
    }
}
