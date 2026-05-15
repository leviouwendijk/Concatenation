import Arguments
import Concatenation
import Foundation

enum TreeCommand: RunnableArgumentCommand {
    static let name = "tree"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Generate a hierarchical file tree."),
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
                help: "Include specific files."
            ),
            opt(
                "fe",
                as: String.self,
                take: .many,
                help: "Exclude specific files."
            ),
            flag(
                "verbose",
                help: "Enable debugging output."
            ),
            flag(
                "no-trailing-slash",
                help: "Remove trailing slash from directories."
            ),
            flag(
                "include-empty",
                short: "e",
                help: "Include empty files and directories."
            ),
            flag(
                "copy",
                short: "c",
                help: "Copy the tree output to clipboard."
            ),
            flag(
                "clean",
                help: "Do not write output to a file."
            ),
            flag(
                "exclude-static-ignores",
                help: "Exclude the statically ignored files."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let cwd = FileManager.default.currentDirectoryPath

        let outputFileName = try invocation.value(
            "output",
            as: String.self
        )

        let directories = try nonEmpty(
            invocation.values(
                "directory",
                as: String.self
            ),
            fallback: [
                cwd,
            ]
        )

        let excludeDirs = try invocation.values(
            "de",
            as: String.self
        )

        let excludeFiles = try invocation.values(
            "fe",
            as: String.self
        )

        let includeFiles = try nonEmpty(
            invocation.values(
                "include",
                as: String.self
            ),
            fallback: [
                "*",
            ]
        )

        let finalMap: IgnoreMap
        if let parsed = try? ConignoreParser.parseFile(
            at: URL(fileURLWithPath: cwd + "/.conignore")
        ) {
            finalMap = try IgnoreMap(
                ignoreFiles: parsed.ignoreFiles + excludeFiles,
                ignoreDirectories: parsed.ignoreDirectories + excludeDirs,
                obscureValues: parsed.obscureValues
            )
        } else {
            finalMap = try IgnoreMap(
                ignoreFiles: excludeFiles,
                ignoreDirectories: excludeDirs,
                obscureValues: [:]
            )
        }

        let includeStaticIgnores = try !invocation.flag(
            "exclude-static-ignores"
        )

        let scanner = try FileScanner(
            treeRoot: directories[0],
            maxDepth: try invocation.flag("all")
                ? nil
                : invocation.value("depth", as: Int.self),
            includePatterns: includeFiles,
            excludeFilePatterns: finalMap.ignoreFiles,
            excludeDirPatterns: finalMap.ignoreDirectories,
            includeDotfiles: try invocation.flag("dot"),
            includeEmpty: try invocation.flag("include-empty"),
            ignoreMap: finalMap,
            ignoreStaticDefaults: includeStaticIgnores
        )

        let urls = try scanner.scan()

        if urls.isEmpty {
            print("No files found in the specified directories.")
            return
        }

        let clean = try invocation.flag("clean")
        let copyToClipboard = try invocation.flag("copy")
        let copyPolicy = clean || copyToClipboard

        let maker = FileTreeMaker(
            files: urls,
            rootPath: directories[0],
            removeTrailingSlash: try invocation.flag("no-trailing-slash"),
            copyToClipboard: copyPolicy
        )

        let tree = maker.generate()

        if !clean {
            let path = cwd + "/" + (outputFileName ?? "tree.txt")
            try tree.write(
                toFile: path,
                atomically: true,
                encoding: .utf8
            )
            print("File tree generated: \(path)")
        } else {
            print("Tree copied.")
            print("-c (copy) flag auto-set to true.")
            print("No file was written.")
        }
    }

    private static func nonEmpty(
        _ values: [String],
        fallback: [String]
    ) -> [String] {
        values.isEmpty ? fallback : values
    }
}
