import Arguments
import Concatenation
import Foundation

struct ConcatOptions: Sendable {
    var outputFileName: String?
    var directories: [String]
    var excludeDirs: [String]
    var depth: Int?
    var allSubdirectories: Bool
    var includeDotFiles: Bool
    var includeFiles: [String]
    var excludeFiles: [String]
    var lineLimit: Int?
    var verboseOutput: Bool
    var delimiterStyle: DelimiterStyle
    var delimiterClosure: Bool
    var useRelativePaths: Bool
    var rawOutput: Bool
    var outputFormat: ConcatenationOutputFormat
    var includeSourceLineNumbers: Bool
    var includeSourceModifiedAt: Bool
    var copyToClipboard: Bool
    var excludeStaticIgnores: Bool
    var allowSecrets: Bool
    var noDeepInspect: Bool

    var deepInspect: Bool {
        !noDeepInspect
    }

    var includeStaticIgnores: Bool {
        !excludeStaticIgnores
    }

    func limit() -> Int? {
        lineLimit == nil ? 10_000 : lineLimit == 0 ? nil : lineLimit
    }
}

extension ConcatOptions {
    static func components() -> [CommandComponentLowerable] {
        [
            opt(
                "output",
                short: "o",
                as: String.self,
                help: "Set output file name."
            ),
            opt(
                "directory",
                aliases: ["directories"],
                short: "d",
                as: String.self,
                take: .many,
                help: "Specify directories to include."
            ),
            opt(
                "de",
                as: String.self,
                take: .many,
                help: "Exclude specified directories from processing."
            ),
            opt(
                "depth",
                short: "s",
                as: Int.self,
                help: "Set maximum scope / depth level to scan."
            ),
            flag(
                "all",
                help: "Iterate over all subdirectories."
            ),
            flag(
                "dot",
                short: ".",
                help: "Include dotfiles and dot directories."
            ),
            opt(
                "include",
                aliases: ["include-files"],
                short: "i",
                as: String.self,
                take: .many,
                help: "Include specific files for concatenation."
            ),
            opt(
                "fe",
                as: String.self,
                take: .many,
                help: "Exclude specific files from concatenation."
            ),
            opt(
                "line-limit",
                short: "l",
                as: Int.self,
                help: "Limit number of lines per file."
            ),
            flag(
                "verbose-out",
                help: "Enable debugging output."
            ),
            opt(
                "delimiter",
                as: DelimiterStyle.self,
                default: .boxed,
                help: "Set delimiter style."
            ),
            flag(
                "closure",
                help: "Add an end-of-file delimiter."
            ),
            opt(
                "relative",
                as: Bool.self,
                default: true,
                help: "Use relative paths in headers."
            ),
            flag(
                "raw",
                help: "Avoid headers or file tree, preserve syntax."
            ),
            opt(
                "format",
                short: "f",
                as: ConcatenationOutputFormat.self,
                default: .text,
                help: "Set output format: text or xml."
            ),
            flag(
                "line-numbers",
                default: true,
                help: "Prefix each line with its original line number."
            ),
            flag(
                "modified-at",
                default: true,
                help: "Include source file modification timestamp."
            ),
            flag(
                "copy",
                short: "c",
                help: "Copy the output to clipboard."
            ),
            flag(
                "exclude-static-ignores",
                short: "e",
                help: "Exclude the statically ignored files."
            ),
            flag(
                "allow-secrets",
                short: "a",
                help: "Allow files otherwise excluded by protection defaults."
            ),
            flag(
                "no-deep-inspect",
                short: "n",
                help: "Turn off deep inspection for file protection."
            ),
        ]
    }

    static func parse(
        _ invocation: ParsedInvocation
    ) throws -> Self {
        let cwd = FileManager.default.currentDirectoryPath

        return .init(
            outputFileName: try invocation.value(
                "output",
                as: String.self
            ),
            directories: try nonEmpty(
                invocation.values(
                    "directory",
                    as: String.self
                ),
                fallback: [
                    cwd,
                ]
            ),
            excludeDirs: try invocation.values(
                "de",
                as: String.self
            ),
            depth: try invocation.value(
                "depth",
                as: Int.self
            ),
            allSubdirectories: try invocation.flag(
                "all"
            ),
            includeDotFiles: try invocation.flag(
                "dot"
            ),
            includeFiles: try nonEmpty(
                invocation.values(
                    "include",
                    as: String.self
                ),
                fallback: [
                    "*",
                ]
            ),
            excludeFiles: try invocation.values(
                "fe",
                as: String.self
            ),
            lineLimit: try invocation.value(
                "line-limit",
                as: Int.self
            ),
            verboseOutput: try invocation.flag(
                "verbose-out"
            ),
            delimiterStyle: try invocation.value(
                "delimiter",
                as: DelimiterStyle.self
            ) ?? .boxed,
            delimiterClosure: try invocation.flag(
                "closure"
            ),
            useRelativePaths: try invocation.value(
                "relative",
                as: Bool.self
            ) ?? true,
            rawOutput: try invocation.flag(
                "raw"
            ),
            outputFormat: try invocation.value(
                "format",
                as: ConcatenationOutputFormat.self
            ) ?? .text,
            includeSourceLineNumbers: try invocation.flag(
                "line-numbers",
                default: true
            ),
            includeSourceModifiedAt: try invocation.flag(
                "modified-at",
                default: true
            ),
            copyToClipboard: try invocation.flag(
                "copy"
            ),
            excludeStaticIgnores: try invocation.flag(
                "exclude-static-ignores"
            ),
            allowSecrets: try invocation.flag(
                "allow-secrets"
            ),
            noDeepInspect: try invocation.flag(
                "no-deep-inspect"
            )
        )
    }

    private static func nonEmpty(
        _ values: [String],
        fallback: [String]
    ) -> [String] {
        values.isEmpty ? fallback : values
    }
}
