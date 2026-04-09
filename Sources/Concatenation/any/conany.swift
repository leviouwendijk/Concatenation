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

        let specification = try ConAnyPathPorting
            .makeSpecification(from: renderable)

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

        var files: [URL] = result.matches.map { $0.url }
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
}
