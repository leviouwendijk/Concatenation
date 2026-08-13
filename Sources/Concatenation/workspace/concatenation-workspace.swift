import Foundation
import IO

public struct ConcatenationWorkspace:
    Sendable,
    Codable,
    Hashable
{
    public let root: URL
    public let configuration: URL

    public init(
        root: URL
    ) {
        let root = root.standardizedFileURL

        self.root = root
        self.configuration = root.appendingPathComponent(
            ".conany",
            isDirectory: false
        )
    }

    public init(
        configuration: URL
    ) {
        let configuration = configuration.standardizedFileURL

        self.root = configuration
            .deletingLastPathComponent()
            .standardizedFileURL

        self.configuration = configuration
    }

    public var state: URL {
        root.appendingPathComponent(
            ".concatenation",
            isDirectory: true
        )
    }

    public var cache: URL {
        state.appendingPathComponent(
            "cache",
            isDirectory: true
        )
    }

    public func cacheManifest(
        for output: URL
    ) -> URL {
        let output = output.standardizedFileURL
        let rootPath = root.path
        let outputPath = output.path

        if outputPath.hasPrefix(
            rootPath + "/"
        ) {
            let relativePath = String(
                outputPath.dropFirst(
                    rootPath.count + 1
                )
            )

            let components = relativePath.split(
                separator: "/",
                omittingEmptySubsequences: true
            )

            guard let filename = components.last else {
                return externalCacheManifest(
                    for: output
                )
            }

            let directory = components
                .dropLast()
                .reduce(cache) { url, component in
                    url.appendingPathComponent(
                        String(component),
                        isDirectory: true
                    )
                }

            return directory.appendingPathComponent(
                String(filename) + ".json",
                isDirectory: false
            )
        }

        return externalCacheManifest(
            for: output
        )
    }

    public func cachedSections(
        for output: URL
    ) -> URL {
        let manifest = cacheManifest(
            for: output
        )

        return manifest
            .deletingLastPathComponent()
            .appendingPathComponent(
                manifest
                    .deletingPathExtension()
                    .lastPathComponent
                    + ".sections",
                isDirectory: true
            )
    }

    public func cachedSection(
        for output: URL,
        key: String
    ) -> URL {
        cachedSections(
            for: output
        ).appendingPathComponent(
            key + ".json",
            isDirectory: false
        )
    }

}

private extension ConcatenationWorkspace {
    func externalCacheManifest(
        for output: URL
    ) -> URL {
        let fingerprint = ContentFingerprint.fingerprint(
            for: output.standardizedFileURL.path
        )

        return cache
            .appendingPathComponent(
                "external",
                isDirectory: true
            )
            .appendingPathComponent(
                fingerprint.value + ".json",
                isDirectory: false
            )
    }
}
