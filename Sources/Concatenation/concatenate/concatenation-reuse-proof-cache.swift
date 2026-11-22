import Foundation
import IO
import Path
import Selection

struct ConcatenationSectionTransformation:
    Encodable,
    Hashable,
    Sendable
{
    let version: Int
    let presentedPath: String
    let selections: [ContentSelection]
    let trimBlankLines: Bool
    let maxLinesPerFile: Int?
    let obscurations: [String: String]
    let modifiedAt: Date?

    /// What changes the section's lines: everything except the header
    /// (`presentedPath`, `modifiedAt`). Keys the shared section pool, so one
    /// body serves every output that shows the same content differently.
    var body: ConcatenationSectionBodyTransformation {
        .init(
            version: 1,
            selections: selections,
            trimBlankLines: trimBlankLines,
            maxLinesPerFile: maxLinesPerFile,
            obscurations: obscurations
        )
    }
}

struct ConcatenationSectionBodyTransformation:
    Encodable,
    Hashable,
    Sendable
{
    let version: Int
    let selections: [ContentSelection]
    let trimBlankLines: Bool
    let maxLinesPerFile: Int?
    let obscurations: [String: String]
}

/// The full transformation (decides reuse of a source in an output) and the
/// body transformation (names the shared section file).
struct ConcatenationSectionFingerprint:
    Hashable,
    Sendable
{
    let transformation: ContentFingerprint
    let body: ContentFingerprint
}

struct ConcatenationReuseProofCacheSnapshot:
    Sendable
{
    let lookupCount: Int
    let uniqueProofCount: Int
    let sharedHitCount: Int
    let fingerprintComputationCount: Int
}

final class ConcatenationReuseProofCache:
    @unchecked Sendable
{
    private let lock =
        NSLock()

    private var fingerprints: [
        ConcatenationSectionTransformation:
            ConcatenationSectionFingerprint
    ] = [:]

    private var lookupCount =
        0

    private var sharedHitCount =
        0

    private var fingerprintComputationCount =
        0

    func fingerprint(
        for transformation:
            ConcatenationSectionTransformation,
        compute: () throws -> ConcatenationSectionFingerprint
    ) throws -> ConcatenationSectionFingerprint {
        lock.lock()

        lookupCount += 1

        if let fingerprint =
            fingerprints[transformation]
        {
            sharedHitCount += 1
            lock.unlock()

            return fingerprint
        }

        do {
            let fingerprint =
                try compute()

            fingerprintComputationCount += 1

            fingerprints[transformation] =
                fingerprint

            lock.unlock()

            return fingerprint
        } catch {
            lock.unlock()
            throw error
        }
    }

    func snapshot()
        -> ConcatenationReuseProofCacheSnapshot
    {
        lock.lock()

        defer {
            lock.unlock()
        }

        return .init(
            lookupCount:
                lookupCount,
            uniqueProofCount:
                fingerprints.count,
            sharedHitCount:
                sharedHitCount,
            fingerprintComputationCount:
                fingerprintComputationCount
        )
    }
}
