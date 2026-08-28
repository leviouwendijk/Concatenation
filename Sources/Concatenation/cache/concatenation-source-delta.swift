import Foundation
import IO

public struct ConcatenationSourceChange:
    Sendable,
    Codable,
    Hashable
{
    public let previous: ConcatenationSourceRecord
    public let current: ConcatenationSourceRecord

    public init(
        previous: ConcatenationSourceRecord,
        current: ConcatenationSourceRecord
    ) {
        self.previous = previous
        self.current = current
    }
}

public struct ConcatenationSourceDelta:
    Sendable,
    Codable,
    Hashable
{
    public let scope: URL
    public let baseFingerprint: ContentFingerprint
    public let fingerprint: ContentFingerprint
    public let added: [ConcatenationSourceRecord]
    public let changed: [ConcatenationSourceChange]
    public let removed: [ConcatenationSourceRecord]
    public let unchangedCount: Int

    public init(
        scope: URL,
        baseFingerprint: ContentFingerprint,
        fingerprint: ContentFingerprint,
        added: [ConcatenationSourceRecord],
        changed: [ConcatenationSourceChange],
        removed: [ConcatenationSourceRecord],
        unchangedCount: Int
    ) {
        self.scope = scope.standardizedFileURL
        self.baseFingerprint = baseFingerprint
        self.fingerprint = fingerprint
        self.added = added
        self.changed = changed
        self.removed = removed
        self.unchangedCount = unchangedCount
    }

    public var isEmpty: Bool {
        added.isEmpty
            && changed.isEmpty
            && removed.isEmpty
    }
}

public enum ConcatenationSourceDeltaError:
    Error,
    Sendable,
    Hashable
{
    case differentScopes(
        previous: URL,
        current: URL
    )
}

public extension ConcatenationSourceSnapshot {
    func delta(
        to current: Self
    ) throws -> ConcatenationSourceDelta {
        let previousScope = scope.standardizedFileURL
        let currentScope = current.scope.standardizedFileURL

        guard previousScope == currentScope else {
            throw ConcatenationSourceDeltaError
                .differentScopes(
                    previous: previousScope,
                    current: currentScope
                )
        }

        var currentByIdentity: [
            String: [ConcatenationSourceRecord]
        ] = [:]

        for source in current.sources {
            currentByIdentity[
                source.identityKey,
                default: []
            ]
            .append(
                source
            )
        }

        var changed: [ConcatenationSourceChange] = []
        var removed: [ConcatenationSourceRecord] = []
        var unchangedCount = 0

        for previous in sources {
            guard var candidates = currentByIdentity[
                previous.identityKey
            ],
            !candidates.isEmpty else {
                removed.append(
                    previous
                )
                continue
            }

            let index = candidates.firstIndex {
                $0.sectionKey == previous.sectionKey
            } ?? candidates.startIndex

            let next = candidates.remove(
                at: index
            )

            if candidates.isEmpty {
                currentByIdentity.removeValue(
                    forKey: previous.identityKey
                )
            } else {
                currentByIdentity[
                    previous.identityKey
                ] = candidates
            }

            if previous.sectionKey == next.sectionKey {
                unchangedCount += 1
            } else {
                changed.append(
                    ConcatenationSourceChange(
                        previous: previous,
                        current: next
                    )
                )
            }
        }

        let added = currentByIdentity.values
            .flatMap { $0 }
            .sorted {
                Self.sourceOrder(
                    $0,
                    $1
                )
            }

        changed.sort {
            Self.sourceOrder(
                $0.current,
                $1.current
            )
        }
        removed.sort {
            Self.sourceOrder(
                $0,
                $1
            )
        }

        return ConcatenationSourceDelta(
            scope: currentScope,
            baseFingerprint: fingerprint,
            fingerprint: current.fingerprint,
            added: added,
            changed: changed,
            removed: removed,
            unchangedCount: unchangedCount
        )
    }
}

private extension ConcatenationSourceSnapshot {
    static func sourceOrder(
        _ lhs: ConcatenationSourceRecord,
        _ rhs: ConcatenationSourceRecord
    ) -> Bool {
        if lhs.file.path != rhs.file.path {
            return lhs.file.path < rhs.file.path
        }

        if lhs.identityKey != rhs.identityKey {
            return lhs.identityKey < rhs.identityKey
        }

        return lhs.sectionKey < rhs.sectionKey
    }
}
