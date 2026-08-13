import Arguments
import Concatenation
import Foundation
import IO

enum ConcatCopyCommand:
    RunnableArgumentCommand
{
    static let name = "copy"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Concatenate a file or directory and copy it to the clipboard."
            ),
            arg(
                "source",
                as: String.self,
                help: "File or directory to concatenate."
            ),
            opt(
                "depth",
                short: "d",
                as: Int.self,
                help: "Limit recursive directory traversal depth."
            ),
            flag(
                "dot",
                help: "Include dotfiles and dot directories."
            ),
            flag(
                "allow-secrets",
                short: "a",
                help: "Allow files otherwise blocked by protection defaults."
            ),
            flag(
                "no-deep-inspect",
                short: "n",
                help: "Disable deep content inspection for protected material."
            ),
            flag(
                "verbose",
                short: "v",
                help: "Print resolution and copy details."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        guard let rawSource = try invocation.value(
            "source",
            as: String.self
        ) else {
            throw ConcatCopyCommandError.missingSource
        }

        let source = resolvedCopySource(
            rawSource
        )

        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: source.path,
            isDirectory: &isDirectory
        ) else {
            throw ConcatCopyCommandError.sourceNotFound(
                source.path
            )
        }

        let directory = isDirectory.boolValue

        let ignoreMap = try copyIgnoreMap(
            for: source,
            isDirectory: directory
        )

        let files: [URL]

        if directory {
            let scanner = try FileScanner(
                root: source.path,
                maxDepth: try invocation.value(
                    "depth",
                    as: Int.self
                ),
                includePatterns: [
                    "*",
                ],
                excludeFilePatterns: ignoreMap.ignoreFiles,
                excludeDirPatterns: ignoreMap.ignoreDirectories,
                includeDotfiles: try invocation.flag(
                    "dot"
                ),
                includeEmpty: false,
                ignoreMap: ignoreMap,
                ignoreStaticDefaults: true
            )

            files = try scanner.scan()
                .map(
                    \.standardizedFileURL
                )
                .sorted {
                    $0.path < $1.path
                }
        } else {
            files = [
                source,
            ]
        }

        guard !files.isEmpty else {
            throw ConcatCopyCommandError.noFiles(
                source.path
            )
        }

        let presentedPathByFile = Dictionary(
            uniqueKeysWithValues: files.map { file in
                (
                    file.standardizedFileURL,
                    directory
                        ? copyPresentedPath(
                            file,
                            relativeTo: source
                        )
                        : file.lastPathComponent
                )
            }
        )

        let verbose = try invocation.flag(
            "verbose"
        )

        if verbose {
            print(
                "Copy source: \(source.path)"
            )

            print(
                "Resolved files: \(files.count)"
            )
        }

        let concatenator = FileConcatenator(
            inputFiles: files,
            presentedPathByFile: presentedPathByFile,
            delimiterStyle: .comment,
            delimiterClosure: false,
            maxLinesPerFile: nil,
            trimBlankLines: true,
            relativePaths: false,
            rawOutput: false,
            outputFormat: .text,
            includeSourceLineNumbers: true,
            includeSourceModifiedAt: false,
            obscureMap: ignoreMap.obscureValues,
            verbose: verbose,
            protectSecrets: true,
            allowSecrets: try invocation.flag(
                "allow-secrets"
            ),
            failOnBlockedFiles: false,
            deepSecretInspection: !(
                try invocation.flag(
                    "no-deep-inspect"
                )
            )
        )

        let result = try await concatenator.copy(
            concurrency: .automatic
        )

        let count = result.document.sections.count

        print(
            "Copied \(count) "
                + (
                    count == 1
                        ? "file"
                        : "files"
                )
                + " to clipboard."
        )
    }
}

private enum ConcatCopyCommandError:
    Error,
    LocalizedError
{
    case missingSource
    case sourceNotFound(String)
    case noFiles(String)

    var errorDescription: String? {
        switch self {
        case .missingSource:
            return "A file or directory is required."

        case .sourceNotFound(let path):
            return "Path does not exist: \(path)"

        case .noFiles(let path):
            return "No files found under: \(path)"
        }
    }
}

private func resolvedCopySource(
    _ raw: String
) -> URL {
    let expanded = NSString(
        string: raw
    ).expandingTildeInPath

    let url: URL

    if expanded.hasPrefix("/") {
        url = URL(
            fileURLWithPath: expanded
        )
    } else {
        url = URL(
            fileURLWithPath:
                FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        .appendingPathComponent(
            expanded
        )
    }

    return url
        .standardizedFileURL
        .resolvingSymlinksInPath()
}

private func copyIgnoreMap(
    for source: URL,
    isDirectory: Bool
) throws -> IgnoreMap {
    let sourceRoot = isDirectory
        ? source
        : source.deletingLastPathComponent()

    let cwd = URL(
        fileURLWithPath:
            FileManager.default.currentDirectoryPath,
        isDirectory: true
    )
    .standardizedFileURL

    let candidates = [
        sourceRoot,
        cwd,
    ]

    var seen: Set<URL> = []

    for root in candidates {
        let ignore = root
            .appendingPathComponent(
                ".conignore",
                isDirectory: false
            )
            .standardizedFileURL

        guard seen.insert(ignore).inserted else {
            continue
        }

        guard FileManager.default.fileExists(
            atPath: ignore.path
        ) else {
            continue
        }

        return try ConignoreParser.parseFile(
            at: ignore
        )
    }

    return try IgnoreMap(
        ignoreFiles: [],
        ignoreDirectories: [],
        obscureValues: [:]
    )
}

private func copyPresentedPath(
    _ file: URL,
    relativeTo root: URL
) -> String {
    let filePath = file
        .standardizedFileURL
        .path

    let rootPath = root
        .standardizedFileURL
        .path

    if rootPath == "/" {
        return String(
            filePath.dropFirst()
        )
    }

    let prefix = rootPath + "/"

    guard filePath.hasPrefix(
        prefix
    ) else {
        return file.lastPathComponent
    }

    return String(
        filePath.dropFirst(
            prefix.count
        )
    )
}
