import Foundation
import IO
import Path

/// Where Concatenation keeps everything that can be thrown away: the shared
/// section pool, one manifest per output, the duplicate index and the
/// service socket.
///
/// `$CON_CACHE_DIR`, else `$XDG_CACHE_HOME/concatenation`, else
/// `~/.cache/concatenation`, the same on macOS and Linux.
public struct ConcatenationCacheRoot:
    Sendable,
    Codable,
    Hashable
{
    public let url: URL

    public init(
        url: URL
    ) {
        self.url = url.standardizedFileURL
    }

    public static var `default`: Self {
        resolved(
            environment: ProcessInfo.processInfo.environment,
            home: StandardPath.home.directory_url
        )
    }

    @_spi(Testing)
    public static func resolved(
        environment: [String: String],
        home: URL
    ) -> Self {
        if let explicit = environment["CON_CACHE_DIR"],
           !explicit.isEmpty {
            return .init(
                url: URL(
                    fileURLWithPath: explicit,
                    isDirectory: true
                )
            )
        }

        let base: URL

        if let xdg = environment["XDG_CACHE_HOME"],
           xdg.hasPrefix("/") {
            base = URL(
                fileURLWithPath: xdg,
                isDirectory: true
            )
        } else {
            base = home.appendingPathComponent(
                ".cache",
                isDirectory: true
            )
        }

        return .init(
            url: base.appendingPathComponent(
                "concatenation",
                isDirectory: true
            )
        )
    }
}

public extension ConcatenationCacheRoot {
    var caches: URL {
        url.appendingPathComponent(
            "caches",
            isDirectory: true
        )
    }

    var sections: URL {
        caches.appendingPathComponent(
            "sections",
            isDirectory: true
        )
    }

    var manifests: URL {
        caches.appendingPathComponent(
            "manifests",
            isDirectory: true
        )
    }

    var index: URL {
        url.appendingPathComponent(
            "index",
            isDirectory: true
        )
    }

    var serviceSocket: URL {
        url.appendingPathComponent(
            "service.sock",
            isDirectory: false
        )
    }

    /// `manifests/<fingerprint of the output path>.json`.
    func manifest(
        for output: URL
    ) -> URL {
        manifests.appendingPathComponent(
            ContentFingerprint.fingerprint(
                for: output.standardizedFileURL.path
            ).value + ".json",
            isDirectory: false
        )
    }

    /// `sections/<key[0..2]>/<key>.json`, shared by every output.
    func section(
        key: String
    ) -> URL {
        sections
            .appendingPathComponent(
                String(key.prefix(2)),
                isDirectory: true
            )
            .appendingPathComponent(
                key + ".json",
                isDirectory: false
            )
    }

    /// Creates the root when it is missing and, on macOS, excludes it from
    /// Time Machine. Costs one `stat` when the root exists.
    func prepare() throws {
        guard !FileSystem.default.exists(url) else {
            return
        }

        try FileSystem.default.directory.create(
            url
        )

        try FileSystem.default.excludeFromBackup(
            url
        )
    }
}
