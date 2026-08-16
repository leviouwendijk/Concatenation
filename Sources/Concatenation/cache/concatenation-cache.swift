import Foundation

public protocol ConcatenationCache: Sendable {
    func load(
        for scope: URL
    ) throws -> ConcatenationCacheManifest?

    func save(
        _ manifest: ConcatenationCacheManifest
    ) throws

    func loadSection(
        for scope: URL,
        key: String
    ) throws -> ConcatenationSection?

    func saveSection(
        _ section: ConcatenationSection,
        for scope: URL,
        key: String
    ) throws
}

public extension ConcatenationCache {
    func invalidate(
        source: URL,
        in scope: URL
    ) throws {
        try invalidate(
            sources: [
                source,
            ],
            in: scope
        )
    }

    func invalidate(
        sources: [URL],
        in scope: URL
    ) throws {
        guard !sources.isEmpty,
              let manifest = try load(
                for: scope
              )
        else {
            return
        }

        let paths = Set(
            sources.map {
                $0.standardizedFileURL.path
            }
        )

        let retainedSources =
            manifest.sources.filter {
                !paths.contains(
                    $0.file
                        .standardizedFileURL
                        .path
                )
            }

        let retainedSafeguards =
            manifest.safeguards.filter {
                !paths.contains(
                    $0.file
                        .standardizedFileURL
                        .path
                )
            }

        guard retainedSources.count
                != manifest.sources.count
            || retainedSafeguards.count
                != manifest.safeguards.count
        else {
            return
        }

        try save(
            .init(
                version:
                    manifest.version,
                output:
                    manifest.output,
                sources:
                    retainedSources,
                safeguards:
                    retainedSafeguards,
                artifact:
                    nil
            )
        )
    }
}

public struct ConcatenationCacheBinding:
    Sendable
{
    public let storage:
        any ConcatenationCache

    public let scope: URL

    public init(
        storage: any ConcatenationCache,
        scope: URL
    ) {
        self.storage =
            storage

        self.scope =
            scope.standardizedFileURL
    }

    public func load() throws
        -> ConcatenationCacheManifest?
    {
        try storage.load(
            for: scope
        )
    }

    public func save(
        sources: [ConcatenationCachedSource],
        safeguards: [ConcatenationCachedSafeguard],
        artifact: ConcatenationCachedArtifact?
    ) throws {
        try storage.save(
            .init(
                output:
                    scope,
                sources:
                    sources,
                safeguards:
                    safeguards,
                artifact:
                    artifact
            )
        )
    }

    public func loadSection(
        key: String
    ) throws -> ConcatenationSection? {
        try storage.loadSection(
            for: scope,
            key: key
        )
    }

    public func saveSection(
        _ section: ConcatenationSection,
        key: String
    ) throws {
        try storage.saveSection(
            section,
            for: scope,
            key: key
        )
    }

    public func invalidate(
        source: URL
    ) throws {
        try storage.invalidate(
            source: source,
            in: scope
        )
    }

    public func invalidate(
        sources: [URL]
    ) throws {
        try storage.invalidate(
            sources: sources,
            in: scope
        )
    }
}

public final class ConcatenationMemoryCache:
    ConcatenationCache,
    @unchecked Sendable
{
    private let lock =
        NSLock()

    private var manifests:
        [String: ConcatenationCacheManifest] = [:]

    private var sections:
        [
            String:
                [String: ConcatenationSection]
        ] = [:]

    public init() {}

    public func load(
        for scope: URL
    ) throws -> ConcatenationCacheManifest? {
        withLock {
            manifests[
                storageKey(
                    for: scope
                )
            ]
        }
    }

    public func save(
        _ manifest: ConcatenationCacheManifest
    ) throws {
        withLock {
            let scope =
                storageKey(
                    for: manifest.output
                )

            manifests[scope] =
                manifest

            let referenced = Set(
                manifest.sources.map(
                    \.sectionKey
                )
            )

            if let cached =
                sections[scope]
            {
                sections[scope] =
                    cached.filter {
                        referenced.contains(
                            $0.key
                        )
                    }
            }
        }
    }

    public func loadSection(
        for scope: URL,
        key: String
    ) throws -> ConcatenationSection? {
        withLock {
            sections[
                storageKey(
                    for: scope
                )
            ]?[
                key
            ]
        }
    }

    public func saveSection(
        _ section: ConcatenationSection,
        for scope: URL,
        key: String
    ) throws {
        withLock {
            sections[
                storageKey(
                    for: scope
                ),
                default: [:]
            ][
                key
            ] = section
        }
    }

    public func removeAll() {
        withLock {
            manifests.removeAll(
                keepingCapacity: true
            )

            sections.removeAll(
                keepingCapacity: true
            )
        }
    }
}

private extension ConcatenationMemoryCache {
    func storageKey(
        for scope: URL
    ) -> String {
        scope
            .standardizedFileURL
            .path
    }

    func withLock<Result>(
        _ body: () throws -> Result
    ) rethrows -> Result {
        lock.lock()

        defer {
            lock.unlock()
        }

        return try body()
    }
}

public typealias ConcatenationDiskCache =
    ConcatenationCacheStore

public struct ConcatenationHybridCache:
    ConcatenationCache,
    Sendable
{
    public let memory:
        ConcatenationMemoryCache

    public let disk:
        ConcatenationDiskCache

    public init(
        memory:
            ConcatenationMemoryCache = .init(),
        disk:
            ConcatenationDiskCache
    ) {
        self.memory =
            memory

        self.disk =
            disk
    }

    public func load(
        for scope: URL
    ) throws -> ConcatenationCacheManifest? {
        if let cached =
            try memory.load(
                for: scope
            )
        {
            return cached
        }

        guard let cached =
            try disk.load(
                for: scope
            )
        else {
            return nil
        }

        try memory.save(
            cached
        )

        return cached
    }

    public func save(
        _ manifest: ConcatenationCacheManifest
    ) throws {
        try disk.save(
            manifest
        )

        try memory.save(
            manifest
        )
    }

    public func loadSection(
        for scope: URL,
        key: String
    ) throws -> ConcatenationSection? {
        if let cached =
            try memory.loadSection(
                for: scope,
                key: key
            )
        {
            return cached
        }

        guard let cached =
            try disk.loadSection(
                for: scope,
                key: key
            )
        else {
            return nil
        }

        try memory.saveSection(
            cached,
            for: scope,
            key: key
        )

        return cached
    }

    public func saveSection(
        _ section: ConcatenationSection,
        for scope: URL,
        key: String
    ) throws {
        try disk.saveSection(
            section,
            for: scope,
            key: key
        )

        try memory.saveSection(
            section,
            for: scope,
            key: key
        )
    }
}

public final class ConcatenationSession:
    @unchecked Sendable
{
    public let cache:
        any ConcatenationCache

    private let lock =
        NSLock()

    private var scopes:
        Set<URL> = []

    public init(
        cache:
            any ConcatenationCache =
                ConcatenationMemoryCache()
    ) {
        self.cache =
            cache
    }

    public func binding(
        for scope: URL
    ) -> ConcatenationCacheBinding {
        let scope =
            scope.standardizedFileURL

        withLock {
            _ = scopes.insert(
                scope
            )
        }

        return .init(
            storage:
                cache,
            scope:
                scope
        )
    }

    public func invalidate(
        source: URL
    ) throws {
        try invalidate(
            sources: [
                source,
            ]
        )
    }

    public func invalidate(
        sources: [URL]
    ) throws {
        guard !sources.isEmpty else {
            return
        }

        let scopes =
            withLock {
                Array(
                    self.scopes
                )
            }

        for scope in scopes {
            try cache.invalidate(
                sources:
                    sources,
                in:
                    scope
            )
        }
    }

    public func invalidate(
        source: URL,
        in scope: URL
    ) throws {
        try binding(
            for: scope
        ).invalidate(
            source:
                source
        )
    }

    public func invalidate(
        sources: [URL],
        in scope: URL
    ) throws {
        try binding(
            for: scope
        ).invalidate(
            sources:
                sources
        )
    }
}

private extension ConcatenationSession {
    func withLock<Result>(
        _ body: () throws -> Result
    ) rethrows -> Result {
        lock.lock()

        defer {
            lock.unlock()
        }

        return try body()
    }
}
