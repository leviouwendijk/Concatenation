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
            ContentFingerprint
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
        compute: () throws -> ContentFingerprint
    ) throws -> ContentFingerprint {
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
