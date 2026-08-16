import Foundation
import IO
import Readers
import Writers

public struct ConcatenationCacheStore:
    ConcatenationCache,
    Sendable
{
    public let workspace: ConcatenationWorkspace

    public init(
        workspace: ConcatenationWorkspace
    ) {
        self.workspace = workspace
    }

    public func load(
        for output: URL
    ) throws -> ConcatenationCacheManifest? {
        let output = output.standardizedFileURL
        let url = workspace.cacheManifest(
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
        let url = workspace.cacheManifest(
            for: manifest.output
        )

        try FileSystem.default.directory.create(
            url.deletingLastPathComponent()
        )

        let data = try encoder().encode(
            manifest
        )

        try StandardWriter(
            url
        ).write(
            data,
            options: .overwriteWithoutBackup
        )

        try pruneSections(
            referencedBy: manifest
        )
    }

    public func loadSection(
        for output: URL,
        key: String
    ) throws -> ConcatenationSection? {
        let url = workspace.cachedSection(
            for: output,
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
        let url = workspace.cachedSection(
            for: output,
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
    func pruneSections(
        referencedBy manifest: ConcatenationCacheManifest
    ) throws {
        let directory = workspace.cachedSections(
            for: manifest.output
        )

        guard FileManager.default.fileExists(
            atPath: directory.path
        ) else {
            return
        }

        let referenced = Set(
            manifest.sources.map {
                $0.sectionKey + ".json"
            }
        )

        let cached = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [
                .skipsHiddenFiles,
            ]
        )

        for url in cached {
            guard url.pathExtension == "json",
                  !referenced.contains(
                    url.lastPathComponent
                  )
            else {
                continue
            }

            try FileSystem.default.remove(
                url
            )
        }
    }

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
