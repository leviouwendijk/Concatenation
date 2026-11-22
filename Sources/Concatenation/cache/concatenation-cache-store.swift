import Foundation
import IO
import Readers
import Writers

/// Manifests per output and one section pool shared by every output, under
/// a `ConcatenationCacheRoot`. Sections are content-addressed and written
/// atomically, so concurrent runs writing the same key cannot corrupt it;
/// nothing is pruned on save (`con clean` collects garbage).
public struct ConcatenationCacheStore:
    ConcatenationCache,
    Sendable
{
    public let root: ConcatenationCacheRoot

    public init(
        root: ConcatenationCacheRoot = .default
    ) {
        self.root = root
    }

    public func load(
        for output: URL
    ) throws -> ConcatenationCacheManifest? {
        let output = output.standardizedFileURL
        let url = root.manifest(
            for: output
        )

        let metadata = try FileInspector(
            url
        ).inspect()

        guard metadata.existed else {
            return nil
        }

        let data = try DataFileReader(
            url
        ).read(
            inspected: metadata,
            options: .init(
                missingFilePolicy: .throwError,
                cachePolicy: .system
            )
        ).data

        guard
            let manifest = try? decoder().decode(
                ConcatenationCacheManifest.self,
                from: data
            ),
            manifest.version == ConcatenationCacheManifest.currentVersion,
            manifest.output.standardizedFileURL == output
        else {
            return nil
        }

        return manifest
    }

    public func save(
        _ manifest: ConcatenationCacheManifest
    ) throws {
        try root.prepare()

        let url = root.manifest(
            for: manifest.output
        )

        try FileSystem.default.directory.create(
            url.deletingLastPathComponent()
        )

        try StandardWriter(
            url
        ).write(
            try encoder().encode(
                manifest
            ),
            options: .overwriteWithoutBackup
        )
    }

    public func loadSection(
        for output: URL,
        key: String
    ) throws -> ConcatenationSection? {
        let url = root.section(
            key: key
        )

        let metadata = try FileInspector(
            url
        ).inspect()

        guard metadata.existed else {
            return nil
        }

        let data = try DataFileReader(
            url
        ).read(
            inspected: metadata,
            options: .init(
                missingFilePolicy: .throwError,
                cachePolicy: .system
            )
        ).data

        return try? decoder().decode(
            ConcatenationSection.self,
            from: data
        )
    }

    public func saveSection(
        _ section: ConcatenationSection,
        for output: URL,
        key: String
    ) throws {
        try root.prepare()

        let url = root.section(
            key: key
        )

        try FileSystem.default.directory.create(
            url.deletingLastPathComponent()
        )

        try StandardWriter(
            url
        ).write(
            try sectionEncoder().encode(
                section
            ),
            options: .overwriteWithoutBackup
        )
    }

}

private extension ConcatenationCacheStore {
    func sectionEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return encoder
    }

    func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        return encoder
    }

    func decoder() -> JSONDecoder {
        JSONDecoder()
    }
}
