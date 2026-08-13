import Arguments
import Concatenation

enum ConcatAnyCopyCommand:
    RunnableArgumentCommand
{
    static let name = "copy"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Render .conany outputs and copy them to the clipboard without writing artifacts."
            ),
            opt(
                "config",
                as: String.self,
                help: "Path to .conany."
            ),
            opt(
                "depth",
                short: "d",
                as: Int.self,
                help: "Limit recursive source traversal depth."
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
            cwd: cwd
        )

        let verbose = try invocation.flag(
            "verbose"
        )

        let execution = try ConAnyExecution(
            configURL: configURL,
            options: .init(
                maxDepth: try invocation.value(
                    "depth",
                    as: Int.self
                ),
                includeDotfiles: try invocation.flag(
                    "dot"
                ),
                ignoreMap: ignoreMap,
                delimiterStyle: .comment,
                delimiterClosure: false,
                maxLinesPerFile: nil,
                rawOutput: false,
                outputFormat: .text,
                includeSourceLineNumbers: true,
                includeSourceModifiedAt: false,
                verboseResolution: verbose,
                verboseOutput: verbose,
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
        )

        let result = try await execution.copy()

        if verbose {
            for skipped in result.skipped {
                print(
                    "No files matched block → \(skipped.name)"
                )
            }
        }

        printConAnyWarnings(
            result.warnings
        )

        print(
            "Copied \(result.outputCount) "
                + (
                    result.outputCount == 1
                        ? ".conany output"
                        : ".conany outputs"
                )
                + " containing \(result.fileCount) "
                + (
                    result.fileCount == 1
                        ? "file"
                        : "files"
                )
                + " to clipboard."
        )
    }
}

private func printConAnyWarnings(
    _ warnings: [ConcatenationWarning]
) {
    for warning in warnings {
        switch warning.kind {
        case .blockedByPolicy:
            print(
                "Excluded protected file: \(warning.file.path)"
            )

            print(
                "  \(warning.message)"
            )

        case .truncated:
            print(
                warning.message
            )
        }
    }

    if warnings.contains(
        where: {
            $0.kind == .blockedByPolicy
        }
    ) {
        print(
            "Use --allow-secrets to override"
        )
    }
}
