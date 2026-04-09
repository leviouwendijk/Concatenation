import Foundation
import Path
import PathParsing

public enum ConAnyResolveError: Error, LocalizedError {
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "Path does not exist: \(path)"
        }
    }
}

public struct ConAnyResolver {
    private let baseDir: String

    public init(
        baseDir: String
    ) {
        self.baseDir = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL
        .path
    }

    public func resolve(
        _ renderable: ConAnyRenderableObject,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> [URL] {
        let baseDirectory = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL

        if verbose {
            print("ConAny resolving in \(baseDirectory.path)")
        }

        let specification = try ConAnyPathPorting.makeSpecification(
            from: renderable,
            relativeTo: baseDirectory
        )

        let result = try PathScan.scan(
            specification,
            relativeTo: .directoryURL(baseDirectory),
            configuration: .init(
                maxDepth: maxDepth,
                includeHidden: includeDotfiles,
                followSymlinks: false,
                emitDirectories: false,
                emitFiles: true
            )
        )

        if verbose, !result.warnings.isEmpty {
            print("PathScan warnings: \(result.warnings)")
        }

        var files: [URL] = result.matches.map(\.url)
        files = try ConAnyPathPorting.applyStaticIgnoreDefaults(to: files)
        files = ConAnyPathPorting.applyIgnoreMap(ignoreMap, to: files)
        files = ConAnyPathPorting.deduplicated(files)

        return files.sorted { $0.path < $1.path }
    }

    public func outputURL(
        for renderable: ConAnyRenderableObject
    ) -> URL {
        ConAnyPathPorting.outputURL(
            for: renderable.output,
            relativeTo: URL(
                fileURLWithPath: baseDir,
                isDirectory: true
            )
            .standardizedFileURL
        )
    }

    public func presentedPath(
        for url: URL,
        in renderable: ConAnyRenderableObject
    ) -> String {
        let baseDirectory = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL

        guard let block = bestIncludeBlock(
            for: url,
            in: renderable,
            relativeTo: baseDirectory
        ) else {
            return url.path
        }

        return (try? ConAnyPathPorting.present(
            url.standardizedFileURL,
            using: block,
            relativeTo: baseDirectory
        )) ?? url.path
    }
}

private extension ConAnyResolver {
    func bestIncludeBlock(
        for url: URL,
        in renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) -> ConAnyIncludeBlock? {
        let standardizedURL = url.standardizedFileURL

        let candidates = renderable.includeBlocks.compactMap {
            block -> (ConAnyIncludeBlock, Int)? in
            if let baseURL = try? ConAnyPathPorting.resolvedBaseURL(
                for: block,
                relativeTo: baseDirectory
            ) {
                let basePath = baseURL.standardizedFileURL.path
                let targetPath = standardizedURL.path

                guard targetPath == basePath
                    || targetPath.hasPrefix(basePath + "/") else {
                    return nil
                }

                return (block, basePath.count)
            }

            return (block, -1)
        }

        return candidates
            .sorted { $0.1 > $1.1 }
            .first?
            .0
    }
}
