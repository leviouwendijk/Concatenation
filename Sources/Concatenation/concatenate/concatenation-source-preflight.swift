import Foundation
import IO

struct ConcatenationSourcePreflight:
    Sendable
{
    let resolvedBySource:
        [URL: URL]

    let metadataByResolvedSource:
        [URL: FileMetadataSnapshot]

    static func inspect(
        sources: [URL],
        concurrency: IOConcurrency
    ) async throws -> ConcatenationSourcePreflightResult {
        var uniqueSources: [URL] = []
        var seenSources: Set<URL> = []

        uniqueSources.reserveCapacity(
            sources.count
        )

        for source in sources {
            let standardized =
                source.standardizedFileURL

            guard seenSources.insert(
                standardized
            ).inserted else {
                continue
            }

            uniqueSources.append(
                standardized
            )
        }

        let resolutions = try await IOExecutor(
            concurrency: concurrency
        ).map(
            uniqueSources
        ) { source in
            ConcatenationSourceResolution(
                source: source,
                resolved: try? resolveSymlink(
                    at: source
                )
            )
        }

        var resolvedBySource:
            [URL: URL] = [:]

        resolvedBySource.reserveCapacity(
            resolutions.count
        )

        var uniqueResolvedSources: [URL] = []
        var seenResolvedSources: Set<URL> = []

        for resolution in resolutions {
            guard let resolved =
                    resolution.resolved?
                    .standardizedFileURL
            else {
                continue
            }

            resolvedBySource[
                resolution.source
            ] = resolved

            if seenResolvedSources.insert(
                resolved
            ).inserted {
                uniqueResolvedSources.append(
                    resolved
                )
            }
        }

        let inspections = try await IOExecutor(
            concurrency: concurrency
        ).map(
            uniqueResolvedSources
        ) { resolved in
            ConcatenationResolvedSourceInspection(
                resolved: resolved,
                metadata: try? FileInspector(
                    resolved
                ).inspect()
            )
        }

        var metadataByResolvedSource:
            [URL: FileMetadataSnapshot] = [:]

        metadataByResolvedSource.reserveCapacity(
            inspections.count
        )

        for inspection in inspections {
            guard let metadata =
                    inspection.metadata
            else {
                continue
            }

            metadataByResolvedSource[
                inspection.resolved
            ] = metadata
        }

        let usableReferenceCount =
            sources.reduce(
                0
            ) {
                partial,
                source in

                let source =
                    source.standardizedFileURL

                guard let resolved =
                        resolvedBySource[
                            source
                        ],
                      metadataByResolvedSource[
                        resolved
                      ] != nil
                else {
                    return partial
                }

                return partial + 1
            }

        return .init(
            preflight: .init(
                resolvedBySource:
                    resolvedBySource,
                metadataByResolvedSource:
                    metadataByResolvedSource
            ),
            sourceReferenceCount:
                sources.count,
            uniqueSourceCount:
                uniqueSources.count,
            uniqueResolvedSourceCount:
                uniqueResolvedSources.count,
            metadataInspectionCount:
                uniqueResolvedSources.count,
            sharedMetadataReuseCount:
                max(
                    0,
                    usableReferenceCount
                        - metadataByResolvedSource.count
                )
        )
    }

    func resolvedURL(
        for source: URL
    ) -> URL? {
        resolvedBySource[
            source.standardizedFileURL
        ]
    }

    func metadata(
        for resolved: URL
    ) -> FileMetadataSnapshot? {
        metadataByResolvedSource[
            resolved.standardizedFileURL
        ]
    }
}

struct ConcatenationSourcePreflightResult:
    Sendable
{
    let preflight:
        ConcatenationSourcePreflight

    let sourceReferenceCount: Int
    let uniqueSourceCount: Int
    let uniqueResolvedSourceCount: Int
    let metadataInspectionCount: Int
    let sharedMetadataReuseCount: Int
}

private struct ConcatenationSourceResolution:
    Sendable
{
    let source: URL
    let resolved: URL?
}

private struct ConcatenationResolvedSourceInspection:
    Sendable
{
    let resolved: URL
    let metadata: FileMetadataSnapshot?
}
