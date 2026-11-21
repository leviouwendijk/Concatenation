import Arguments
import Clipboard
import Concatenation
import ConcatenationLegacy
import Foundation
import IO

enum ConcatRunCommand: RunnableArgumentCommand {
    static let name = "run"

    static let aliases = [
        "default",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        [
            flag(
                "verbose",
                help: "Show detailed execution output."
            ),
        ] + ConcatOptions.components()
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        var options = try ConcatOptions.parse(
            invocation
        )

        let verbose =
            try invocation.flag(
                "verbose"
            )

        options.verboseOutput =
            options.verboseOutput
            || verbose

        try await runDefaultConcatenation(
            options: options
        )
    }
}

func runDefaultConcatenation(
    options: ConcatOptions
) async throws {
    let cwd = FileManager.default.currentDirectoryPath

    let finalMap: IgnoreMap

    if let parsed = try? ConignoreParser.parseFile(
        at: URL(
            fileURLWithPath:
                cwd + "/.conignore"
        )
    ) {
        finalMap = try IgnoreMap(
            ignoreFiles:
                parsed.ignoreFiles
                + options.excludeFiles,
            ignoreDirectories:
                parsed.ignoreDirectories
                + options.excludeDirs,
            obscureValues:
                parsed.obscureValues
        )
    } else {
        finalMap = try IgnoreMap(
            ignoreFiles:
                options.excludeFiles,
            ignoreDirectories:
                options.excludeDirs,
            obscureValues: [:]
        )
    }

    let outputURL = URL(
        fileURLWithPath:
            cwd
            + "/"
            + (
                options.outputFileName
                ?? "concatenation.txt"
            )
    )
    .standardizedFileURL

    let identity =
        ConcatenationRunIdentity()

    let status =
        makeConcatenationRunStatus(
            identity: identity,
            outputCount: 1,
            verbose:
                options.verboseOutput
        )

    await status?.start()

    let result:
        ConcatenationWriteResult

    do {
        let scanner = try FileScanner(
            concatRoot: cwd,
            maxDepth:
                options.allSubdirectories
                    ? nil
                    : options.depth,
            includePatterns:
                options.includeFiles,
            excludeFilePatterns:
                finalMap.ignoreFiles,
            excludeDirPatterns:
                finalMap.ignoreDirectories,
            includeDotfiles:
                options.includeDotFiles,
            ignoreMap:
                finalMap,
            ignoreStaticDefaults:
                options.includeStaticIgnores
        )

        let urls =
            try scanner.scan()

        let concatenator =
            FileConcatenator(
                inputFiles: urls,
                outputURL: outputURL,
                delimiterStyle:
                    options.delimiterStyle,
                delimiterClosure:
                    options.delimiterClosure,
                maxLinesPerFile:
                    options.limit(),
                trimBlankLines: true,
                relativePaths:
                    options.useRelativePaths,
                rawOutput:
                    options.rawOutput,
                outputFormat:
                    options.outputFormat,
                includeSourceLineNumbers:
                    options.includeSourceLineNumbers,
                includeSourceModifiedAt:
                    options.includeSourceModifiedAt,
                obscureMap:
                    finalMap.obscureValues,
                requiresRenderedText:
                    options.copyToClipboard,
                allowSecrets:
                    options.allowSecrets,
                deepSecretInspection:
                    options.deepInspect
            )

        result =
            try await concatenator.write(
                concurrency: .automatic
            )
    } catch {
        await status?.stop()
        throw error
    }

    await status?.stop()

    var clipboardDuration: TimeInterval = 0

    if options.copyToClipboard,
       let text = result.renderResult?.text
    {
        let clipboardStartedAt = Date()
        text.clipboard()
        clipboardDuration = Date().timeIntervalSince(
            clipboardStartedAt
        )
    }

    printConcatenationWarnings(
        result.warnings
    )

    printConcatenationRunSummary(
        result,
        outputURL: outputURL,
        identity: identity,
        clipboardDuration: clipboardDuration,
        verbose:
            options.verboseOutput
    )
}
