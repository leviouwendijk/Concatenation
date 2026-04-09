Exactly — that is why you are not seeing either of them.

The `Concatenation` library now has both switches on `FileConcatenator`:

* `includeSourceLineNumbers: Bool = false`
* `includeSourceModifiedAt: Bool = false` 

But your CLI layer does **not** expose those options in `ConcatenateOptions`, and the `con any`, `con`, and `con select` commands do **not** pass them into `FileConcatenator`, so both features are silently staying off. 

So the fix is in the **bin script**, not the library.

Do these exact replacements.

## 1) Replace

`/Users/leviouwendijk/myworkdir/programming/scripts/concatenator/Sources/con/concatenation/concatenation-options.swift`

```swift id="tqebiv"
import Foundation
import ArgumentParser
import Concatenation

extension DelimiterStyle: @retroactive ExpressibleByArgument { }

struct ConcatenateOptions: ParsableCommand {
    @Option(name: .shortAndLong, help: "Set output file name.")
    var outputFileName: String? = nil

    @Option(name: .shortAndLong, help: "Specify directories to include (default: current directory).")
    var directories: [String] = [FileManager.default.currentDirectoryPath]
    
    @Option(name: .customLong("de"), help: "Exclude specified directories from processing.")
    var excludeDirs: [String] = []
    
    @Option(name: [.customShort("s"), .customLong("depth")], help: "Set maximum scope / depth level to scan (default: unlimited).")
    var depth: Int? = nil

    @Flag(name: .customLong("all"), help: "Iterate over all subdirectories.")
    var allSubdirectories: Bool = false
    
    @Flag(name: [.customShort("."), .customLong("dot")], help: "Include dotfiles and dot directories (default: false).")
    var includeDotFiles: Bool = false
    
    @Option(name: .shortAndLong, help: "Include specific files for concatenation (supports wildcards, e.g., *.txt).")
    var includeFiles: [String] = ["*"]
    
    @Option(name: .customLong("fe"), help: "Exclude specific files from concatenation (supports wildcards, e.g., *.log).")
    var excludeFiles: [String] = []
    
    @Option(name: .shortAndLong, help: "Limit number of lines per file (default: 10_000).")
    var lineLimit: Int?
    
    @Flag(name: .customLong("verbose-out"), help: "Enable debugging output.")
    var verboseOutput: Bool = false
    
    @Option(name: .customLong("delimiter"), help: "Set delimiter style (none, comment, asterisk, classic, boxed).")
    var delimiterStyle: DelimiterStyle = .boxed

    @Flag(name: .customLong("closure"), help: "Add an end-of-file delimiter.")
    var delimiterClosure: Bool = false
    
    @Option(name: .customLong("relative"), help: "Use relative paths in headers instead of absolute paths (true/false).")
    var useRelativePaths: Bool = true
    
    @Flag(name: .customLong("raw"), help: "Avoid headers or file tree, preserve syntax.")
    var rawOutput: Bool = false

    @Flag(name: .customLong("line-numbers"), help: "Prefix each concatenated source-file line with its original line number.")
    var includeSourceLineNumbers: Bool = false

    @Flag(name: .customLong("modified-at"), help: "Include each source file's filesystem modification timestamp in its header.")
    var includeSourceModifiedAt: Bool = false
    
    @Flag(name: .shortAndLong, help: "Copy the concatenation output to clipboard.")
    var copyToClipboard: Bool = false

    @Flag(name: .shortAndLong, help: "Excluding the statically ignored files (may contain sensitive content)")
    var excludeStaticIgnores: Bool = false

    @Flag(name: .shortAndLong, help: "Allow files to be concatenated that are otherwise excluded by protection defaults.")
    var allowSecrets: Bool = false
    
    @Flag(name: .shortAndLong, help: "Turn off deep inspection for file protection of secrets.")
    var noDeepInspect: Bool = false

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
```

---

## 2) Replace

`/Users/leviouwendijk/myworkdir/programming/scripts/concatenator/Sources/con/concatenation/concatenate-any.swift`

```swift id="7wo9dn"
import Foundation
import ArgumentParser
import Concatenation

extension Concatenate {
    struct `Any`: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "any",
            abstract: "Concatenate arbitrary absolute/relative files via .conany.",
            subcommands: [Init.self, Run.self],
            defaultSubcommand: Run.self
        )

        struct Init: ParsableCommand {
            @Flag(help: "Force overwrite existing .conany")
            var force: Bool = false

            func run() throws {
                let initializer = ConAnyInitializer()

                do {
                    try initializer.initialize(force: force)
                    print(".conany created.")
                } catch ConAnyInitError.alreadyExists {
                    print(".conany already exists. Use --force to overwrite.")
                }
            }
        }

        struct Run: ParsableCommand {
            @Option(name: .customLong("config"), help: "Path to .conany (default: ./.conany)")
            var configPath: String?

            @OptionGroup
            var options: ConcatenateOptions

            @Flag(help: "Verbose resolution")
            var verbose: Bool = false

            func run() throws {
                let cwd = FileManager.default.currentDirectoryPath
                let cfgURL = URL(
                    fileURLWithPath: configPath ?? "\(cwd)/.conany"
                ).standardizedFileURL

                let cfg = try ConAnyParser.parseFile(at: cfgURL)

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

                let resolver = ConAnyResolver(
                    baseDir: cfgURL.deletingLastPathComponent().path
                )

                var collectedContexts: [String] = []

                let containsContexts = cfg.renderables.contains {
                    $0.context != nil
                }

                if containsContexts {
                    let signature = """
                    // type: autogenerated
                    // signature: concatenator
                    """
                    collectedContexts.append(signature)
                }

                var totalLinesAll = 0

                for renderable in cfg.renderables {
                    let urls = try resolver.resolve(
                        renderable,
                        maxDepth: options.allSubdirectories ? nil : options.depth,
                        includeDotfiles: options.includeDotFiles,
                        ignoreMap: finalMap,
                        verbose: verbose
                    )

                    guard !urls.isEmpty else {
                        print("No files matched block → \(renderable.output)")
                        continue
                    }

                    let outURL = resolver.outputURL(for: renderable)
                    let location = "con any block '\(renderable.output)' → \(outURL.path)"

                    if let context = renderable.context {
                        let header = context.object(outputURL: outURL)
                        collectedContexts.append(header)
                    }

                    let concatenator = FileConcatenator(
                        inputFiles: urls,
                        outputURL: outURL,
                        context: renderable.context,

                        delimiterStyle: options.delimiterStyle,
                        delimiterClosure: options.delimiterClosure,
                        maxLinesPerFile: options.limit(),
                        trimBlankLines: true,
                        relativePaths: false,
                        rawOutput: options.rawOutput,
                        includeSourceLineNumbers: options.includeSourceLineNumbers,
                        includeSourceModifiedAt: options.includeSourceModifiedAt,
                        obscureMap: finalMap.obscureValues,

                        copyToClipboard: options.copyToClipboard,
                        verbose: options.verboseOutput,

                        location: location,
                        allowSecrets: options.allowSecrets,
                        deepSecretInspection: options.deepInspect
                    )

                    let total = try concatenator.run()
                    totalLinesAll += total

                    printSuccess(
                        outputPath: outURL.path,
                        totalLines: total
                    )
                }

                if !collectedContexts.isEmpty {
                    let contextsJoined = collectedContexts.joined(separator: "\n\n")
                    let contextsURL = cfgURL
                        .deletingLastPathComponent()
                        .appendingPathComponent("context_index.txt")

                    if FileManager.default.fileExists(atPath: contextsURL.path) {
                        let text = try String(
                            contentsOf: contextsURL,
                            encoding: .utf8
                        )

                        if isConcatenatorSigned(text: text) {
                            try contextsJoined.write(
                                to: contextsURL,
                                atomically: true,
                                encoding: .utf8
                            )

                            if verbose {
                                print("Overwrote autogenerated contexts at \(contextsURL.path)")
                            }
                        } else if verbose {
                            print("Skipping contexts write: \(contextsURL.path) exists and appears manually maintained (no concatenator signature)")
                        }
                    } else {
                        try contextsJoined.write(
                            to: contextsURL,
                            atomically: true,
                            encoding: .utf8
                        )

                        if verbose {
                            print("Wrote contexts to \(contextsURL.path)")
                        }
                    }
                }

                if cfg.renderables.count > 1 {
                    print("Done. Blocks: \(cfg.renderables.count), total lines: \(totalLinesAll).")
                }
            }

            func isConcatenatorSigned(
                text: String
            ) -> Bool {
                let firstLines = text
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .prefix(10)
                    .map(String.init)

                let hasTypeMarker = firstLines.contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines) == "// type: autogenerated"
                }

                let hasSignature = firstLines.contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines) == "// signature: concatenator"
                }

                return hasTypeMarker && hasSignature
            }
        }
    }
}
```

---

## 3) Replace

`/Users/leviouwendijk/myworkdir/programming/scripts/concatenator/Sources/con/concatenation/concatenate-default.swift`

```swift id="h1hlbw"
import Foundation
import ArgumentParser
import Concatenation

extension Concatenate {
    struct Default: ParsableCommand {
        @OptionGroup
        var options: ConcatenateOptions
        
        func run() throws {
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
    }
}
```

---

## 4) Replace

`/Users/leviouwendijk/myworkdir/programming/scripts/concatenator/Sources/con/concatenation/concatenate-select.swift`

```swift id="4jiovl"
import Foundation
import ArgumentParser
import Concatenation

extension Concatenate {
    struct Select: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "select",
            abstract: ".conselect related functions.",
            subcommands: [ConcatenateFromConselect.self, Initialize.self],
            defaultSubcommand: ConcatenateFromConselect.self
        )

        struct Initialize: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "init",
                abstract: "initialize a .conselect file."
            )

            @Flag(help: "Force overwrite .conselect file")
            var force: Bool = false

            func run() throws {
                let initializer = ConselectInitializer()

                do {
                    try initializer.initialize(force: force)
                    print(".conselect file has been created.")
                } catch ConselectError.alreadyExists {
                    print(".conselect file already exists. Use --force to overwrite.")
                }
            }
        }

        struct ConcatenateFromConselect: ParsableCommand {
            @Option(name: .customLong("select"), help: "Path to .conselect (default: ./.conselect)")
            var selectFile: String?

            @OptionGroup
            var options: ConcatenateOptions

            @Flag(help: "List matches (debug).")
            var verbose: Bool = false

            func run() throws {
                let cwd = FileManager.default.currentDirectoryPath
                let selPath = selectFile ?? "\(cwd)/.conselect"
                let selection = try ConselectParser.parseFile(
                    at: URL(fileURLWithPath: selPath)
                )

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

                let urls = try selection.resolve(
                    root: cwd,
                    maxDepth: options.allSubdirectories ? nil : options.depth,
                    includeDotfiles: options.includeDotFiles,
                    ignoreMap: finalMap,
                    verbose: verbose
                )

                guard !urls.isEmpty else {
                    print("No files matched .conselect.")
                    return
                }

                let outputPath = cwd + "/" + (options.outputFileName ?? "conselection.txt")

                let concatenator = FileConcatenator(
                    inputFiles: urls,
                    outputURL: URL(fileURLWithPath: outputPath),
                    delimiterStyle: options.delimiterStyle,
                    delimiterClosure: options.delimiterClosure,
                    maxLinesPerFile: options.limit(),
                    trimBlankLines: true,
                    relativePaths: options.useRelativePaths,
                    rawOutput: options.rawOutput,
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
        }
    }
}
```

## After this, use it like this

For `.conany`:

```bash
con concat any --line-numbers --modified-at
```

For the default full concat:

```bash
con concat --line-numbers --modified-at
```

For `.conselect`:

```bash
con concat select --line-numbers --modified-at
```

## Why this was happening

Because the bin layer currently only passes things like:

* `delimiterStyle`
* `delimiterClosure`
* `rawOutput`
* `obscureMap`

but not the two new `FileConcatenator` flags, so the library defaults are never overridden.

And yes, the `.conany` parser in your library **does already support both `#` and `//` comments** now, so that part is not the reason the new output features were missing. 

If you run with `--line-numbers`, you should now get per-source-file numbering like:

```text
1 | import Foundation
2 | struct Foo {
3 |     ...
```

and with `--modified-at`, each file header should include its own timestamp.
