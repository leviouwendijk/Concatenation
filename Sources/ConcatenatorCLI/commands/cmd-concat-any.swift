import Arguments
import Concatenation
import Foundation

enum ConcatAnyCommand: ArgumentCommand {
    static let name = "any"

    static var defaultChild: ConcatAnyRunCommand.Type {
        ConcatAnyRunCommand.self
    }

    static var children: [ArgumentCommandType] {
        [
            ConcatAnyInitCommand.self,
            ConcatAnyRunCommand.self,
            ConcatAnyCopyCommand.self,
        ]
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Concatenate arbitrary absolute/relative files via .conany."),
        ]
    }
}

enum ConcatAnyInitCommand: RunnableArgumentCommand {
    static let name = "init"

    static func components() throws -> [CommandComponentLowerable] {
        [
            flag(
                "force",
                help: "Force overwrite existing .conany."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let initializer = ConAnyInitializer()

        do {
            try initializer.initialize(
                force: try invocation.flag("force")
            )

            print(
                ".conany created."
            )
        } catch ConAnyInitError.alreadyExists {
            print(
                ".conany already exists. Use --force to overwrite."
            )
        }
    }
}

enum ConcatAnyRunCommand: RunnableArgumentCommand {
    static let name = "run"

    static func components() throws -> [CommandComponentLowerable] {
        [
            opt(
                "config",
                as: String.self,
                help: "Path to .conany."
            ),
            flag(
                "verbose",
                help: "Verbose resolution."
            ),
        ] + ConcatOptions.components(
            includeCopy: false
        )
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let options = try ConcatOptions.parse(
            invocation,
            includeCopy: false
        )

        let cwd = currentConAnyDirectory()

        let configURL = resolvedConAnyConfig(
            try invocation.value(
                "config",
                as: String.self
            ),
            cwd: cwd
        )

        let ignoreMap = try conAnyIgnoreMap(
            configDirectory: configURL
                .deletingLastPathComponent(),
            cwd: cwd,
            extraFiles: options.excludeFiles,
            extraDirectories: options.excludeDirs
        )

        let verboseResolution = try invocation.flag(
            "verbose"
        )

        let execution = try ConAnyExecution(
            configURL: configURL,
            options: .init(
                maxDepth: options.allSubdirectories
                    ? nil
                    : options.depth,
                includeDotfiles: options.includeDotFiles,
                ignoreMap: ignoreMap,
                delimiterStyle: options.delimiterStyle,
                delimiterClosure: options.delimiterClosure,
                maxLinesPerFile: options.limit(),
                rawOutput: options.rawOutput,
                outputFormat: options.outputFormat,
                includeSourceLineNumbers: options.includeSourceLineNumbers,
                includeSourceModifiedAt: options.includeSourceModifiedAt,
                verboseResolution: verboseResolution,
                verboseOutput: options.verboseOutput,
                protectSecrets: true,
                allowSecrets: options.allowSecrets,
                failOnBlockedFiles: false,
                deepSecretInspection: options.deepInspect
            )
        )

        let identity = ConcatenationRunIdentity()

        let verbosePresentation =
            verboseResolution
            || options.verboseOutput

        let configuredOutputCount =
            execution.configuration.renderables.count

        let status = makeConcatenationRunStatus(
            identity: identity,
            outputCount: configuredOutputCount,
            verbose: verbosePresentation
        )

        await status?.start()

        let result: ConAnyWriteBatchResult

        do {
            result = try await execution.write()
        } catch {
            await status?.stop()
            throw error
        }

        await status?.stop()

        for skipped in result.skipped {
            print(
                "No files matched block → \(skipped.name)"
            )
        }

        printConAnyWarnings(
            result.warnings
        )

        if verbosePresentation {
            for output in result.outputs {
                printSuccess(
                    outputPath: output.resolved.outputURL.path,
                    totalLines: output.result.renderedLineCount
                )
            }

            printContextIndexAction(
                result.contextIndexAction
            )
        }

        printConAnyRunSummary(
            result,
            identity: identity,
            verbose: verbosePresentation
        )
    }
}

func currentConAnyDirectory() -> URL {
    URL(
        fileURLWithPath:
            FileManager.default.currentDirectoryPath,
        isDirectory: true
    )
    .standardizedFileURL
}

func resolvedConAnyConfig(
    _ raw: String?,
    cwd: URL
) -> URL {
    guard let raw else {
        return cwd
            .appendingPathComponent(
                ".conany",
                isDirectory: false
            )
            .standardizedFileURL
    }

    let expanded = NSString(
        string: raw
    ).expandingTildeInPath

    if expanded.hasPrefix("/") {
        return URL(
            fileURLWithPath: expanded
        )
        .standardizedFileURL
    }

    return cwd
        .appendingPathComponent(
            expanded,
            isDirectory: false
        )
        .standardizedFileURL
}

func conAnyIgnoreMap(
    configDirectory: URL,
    cwd: URL,
    extraFiles: [String] = [],
    extraDirectories: [String] = []
) throws -> IgnoreMap {
    let candidates = [
        configDirectory.standardizedFileURL,
        cwd.standardizedFileURL,
    ]

    var seen: Set<URL> = []

    for directory in candidates {
        let ignore = directory
            .appendingPathComponent(
                ".conignore",
                isDirectory: false
            )
            .standardizedFileURL

        guard seen.insert(
            ignore
        ).inserted else {
            continue
        }

        guard FileManager.default.fileExists(
            atPath: ignore.path
        ) else {
            continue
        }

        let parsed = try ConignoreParser.parseFile(
            at: ignore
        )

        return try IgnoreMap(
            ignoreFiles:
                parsed.ignoreFiles
                + extraFiles,
            ignoreDirectories:
                parsed.ignoreDirectories
                + extraDirectories,
            obscureValues:
                parsed.obscureValues
        )
    }

    return try IgnoreMap(
        ignoreFiles: extraFiles,
        ignoreDirectories: extraDirectories,
        obscureValues: [:]
    )
}

func printContextIndexAction(
    _ action: ConAnyContextIndexAction
) {
    switch action {
    case .none:
        break

    case .written(let url):
        print(
            "Wrote contexts to \(url.path)"
        )

    case .overwritten(let url):
        print(
            "Overwrote autogenerated contexts at \(url.path)"
        )

    case .removed(let url):
        print(
            "Removed obsolete autogenerated contexts at \(url.path)"
        )

    case .skippedManual(let url):
        print(
            "Skipping contexts write: "
                + "\(url.path) exists and appears manually maintained."
        )

    case .unchanged(let url):
        print(
            "Unchanged autogenerated contexts at \(url.path)"
        )
    }
}
