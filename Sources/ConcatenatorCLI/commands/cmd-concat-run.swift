import Arguments
import Concatenation
import Foundation

enum ConcatRunCommand: RunnableArgumentCommand {
    static let name = "run"

    static let aliases = [
        "default",
    ]

    static func components() throws -> [CommandComponentLowerable] {
        ConcatOptions.components()
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let options = try ConcatOptions.parse(
            invocation
        )

        try runDefaultConcatenation(
            options: options
        )
    }
}

func runDefaultConcatenation(
    options: ConcatOptions
) throws {
    let cwd = FileManager.default.currentDirectoryPath

    let finalMap: IgnoreMap
    if let parsed = try? ConignoreParser.parseFile(
        at: URL(fileURLWithPath: cwd + "/.conignore")
    ) {
        finalMap = try IgnoreMap(
            ignoreFiles: parsed.ignoreFiles + options.excludeFiles,
            ignoreDirectories: parsed.ignoreDirectories + options.excludeDirs,
            obscureValues: parsed.obscureValues
        )
    } else {
        finalMap = try IgnoreMap(
            ignoreFiles: options.excludeFiles,
            ignoreDirectories: options.excludeDirs,
            obscureValues: [:]
        )
    }

    let scanner = try FileScanner(
        concatRoot: cwd,
        maxDepth: options.allSubdirectories ? nil : options.depth,
        includePatterns: options.includeFiles,
        excludeFilePatterns: finalMap.ignoreFiles,
        excludeDirPatterns: finalMap.ignoreDirectories,
        includeDotfiles: options.includeDotFiles,
        ignoreMap: finalMap,
        ignoreStaticDefaults: options.includeStaticIgnores
    )

    let urls = try scanner.scan()
    let outputPath = cwd + "/" + (options.outputFileName ?? "concatenation.txt")

    let concatenator = FileConcatenator(
        inputFiles: urls,
        outputURL: URL(fileURLWithPath: outputPath),
        delimiterStyle: options.delimiterStyle,
        delimiterClosure: options.delimiterClosure,
        maxLinesPerFile: options.limit(),
        trimBlankLines: true,
        relativePaths: options.useRelativePaths,
        rawOutput: options.rawOutput,
        outputFormat: options.outputFormat,
        includeSourceLineNumbers: options.includeSourceLineNumbers,
        includeSourceModifiedAt: options.includeSourceModifiedAt,
        obscureMap: finalMap.obscureValues,
        copyToClipboard: options.copyToClipboard,
        verbose: options.verboseOutput,
        allowSecrets: options.allowSecrets,
        deepSecretInspection: options.deepInspect
    )

    let total = try concatenator.run()

    printSuccess(
        outputPath: outputPath,
        totalLines: total
    )
}
