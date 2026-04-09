import Foundation
import Terminal
import Indentation
import Primitives
import Clipboard
import Position
import Writers

public struct FileConcatenator: SafelyConcatenatable {
    public let inputFiles: [URL]
    public let outputURL: URL
    public let context: ConcatenationContext?

    public let delimiterStyle: DelimiterStyle
    public let delimiterClosure: Bool
    public let maxLinesPerFile: Int?
    public let trimBlankLines: Bool
    public let relativePaths: Bool
    public let rawOutput: Bool
    public let includeSourceLineNumbers: Bool
    public let includeSourceModifiedAt: Bool

    public let obscureMap: [String: String]
    public let copyToClipboard: Bool
    public let verbose: Bool

    public let location: String?

    public let protectSecrets: Bool
    public let allowSecrets: Bool
    public let failOnBlockedFiles: Bool
    public let deepSecretInspection: Bool

    public init(
        inputFiles: [URL],
        outputURL: URL,
        context: ConcatenationContext? = nil,

        delimiterStyle: DelimiterStyle = .boxed,
        delimiterClosure: Bool = false,
        maxLinesPerFile: Int? = 10_000,
        trimBlankLines: Bool = true,
        relativePaths: Bool = true,
        rawOutput: Bool = false,
        includeSourceLineNumbers: Bool = false,
        includeSourceModifiedAt: Bool = false,
        obscureMap: [String: String] = [:],

        copyToClipboard: Bool = false,
        verbose: Bool = false,

        location: String? = nil,

        protectSecrets: Bool = true,
        allowSecrets: Bool = false,
        failOnBlockedFiles: Bool = false,
        deepSecretInspection: Bool = false
    ) {
        self.inputFiles = inputFiles
        self.outputURL = outputURL
        self.context = context

        self.delimiterStyle = delimiterStyle
        self.delimiterClosure = delimiterClosure
        self.maxLinesPerFile = maxLinesPerFile
        self.trimBlankLines = trimBlankLines
        self.relativePaths = relativePaths
        self.rawOutput = rawOutput
        self.includeSourceLineNumbers = includeSourceLineNumbers
        self.includeSourceModifiedAt = includeSourceModifiedAt
        self.obscureMap = obscureMap

        self.copyToClipboard = copyToClipboard
        self.verbose = verbose

        self.location = location

        self.protectSecrets = protectSecrets
        self.allowSecrets = allowSecrets
        self.failOnBlockedFiles = failOnBlockedFiles
        self.deepSecretInspection = deepSecretInspection
    }

    public func run() throws -> Int {
        let fileManager = FileManager.default
        let writer = StandardWriter(outputURL)

        let bootstrapContent: String = {
            guard !rawOutput, let context else {
                return ""
            }

            let header = context.header(outputURL: outputURL)

            guard !header.isEmpty else {
                return ""
            }

            return header + "\n\n"
        }()

        try writer.write(
            bootstrapContent,
            options: .init(
                existingFilePolicy: .overwrite,
                makeBackupOnOverride: false,
                whitespaceOnlyIsBlank: true,
                createIntermediateDirectories: true,
                atomic: true
            )
        )

        let handle = try FileHandle(forWritingTo: outputURL)
        defer { handle.closeFile() }
        handle.seekToEndOfFile()

        if verbose {
            if let location {
                print("Concatenation location: \(location)")
            }
            print("Concatenating \(inputFiles.count) files → \(outputURL.path)")
        }

        var totalLines = 0
        var errors: [Error] = []

        var filesAutoProtected = false
        let override = "Use --allow-secrets to override"

        for fileURL in inputFiles {
            if protectSecrets && !allowSecrets {
                if isProtectedFile(fileURL) {
                    filesAutoProtected = true
                    let reason = "Detected filename/extension matching secret patterns."
                    printProtectionNotifier(
                        file: fileURL.path,
                        reason: reason
                    )

                    if failOnBlockedFiles {
                        errors.append(
                            ConcatError.fileBlockedByPolicy(
                                url: fileURL,
                                reason: reason
                            )
                        )
                    }

                    continue
                }

                if deepSecretInspection {
                    let (deepMatched, deepReason) = deepSecretCheck(fileURL)

                    if deepMatched {
                        filesAutoProtected = true
                        let reason = deepReason ?? "deep-secret heuristic matched"

                        printProtectionNotifier(
                            file: fileURL.path,
                            reason: reason
                        )

                        if failOnBlockedFiles {
                            errors.append(
                                ConcatError.fileBlockedByPolicy(
                                    url: fileURL,
                                    reason: reason
                                )
                            )
                        }

                        continue
                    }
                }
            }

            do {
                let resolved = try resolveSymlink(at: fileURL)
                var lines = try readLines(from: resolved)

                let (processedLines, blankWarnings) = processBlankLines(
                    lines,
                    trim: trimBlankLines
                )
                lines = processedLines

                let writeLines: [String]
                let wasTruncated: Bool

                if let limit = maxLinesPerFile, lines.count > limit {
                    writeLines = Array(lines.prefix(limit))
                    wasTruncated = true
                } else {
                    writeLines = lines
                    wasTruncated = false
                }

                let obscuredLines = applyObscuring(to: writeLines)

                let slice = FileLineSlice(
                    file: resolved,
                    startLine: 1,
                    lines: obscuredLines
                )

                if !rawOutput {
                    let headerLabel = makeHeaderLabel(
                        for: resolved,
                        fileManager: fileManager
                    )

                    let header = delimiterStyle.header(for: headerLabel) + "\n"
                    handle.write(Data(header.utf8))
                    handle.write(Data(blankWarnings.header.utf8))
                }

                let bodyLines = renderedBodyLines(from: slice)

                for line in bodyLines {
                    handle.write(Data((line + "\n").utf8))
                }

                if wasTruncated {
                    let message = "(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)\n"
                    handle.write(Data(message.utf8))
                    print(
                        "(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)"
                            .ansi(.yellow)
                    )
                }

                totalLines += bodyLines.count

                if !rawOutput {
                    let footerLabel = makeHeaderLabel(
                        for: resolved,
                        fileManager: fileManager
                    )

                    handle.write(Data(blankWarnings.footer.utf8))

                    if delimiterClosure {
                        handle.write(
                            Data((delimiterStyle.footer(for: footerLabel) + "\n").utf8)
                        )
                    }
                }

                if fileURL != inputFiles.last {
                    handle.write(Data("\n\n".utf8))
                }
            } catch {
                let wrapped = ConcatError.fileProcessingFailed(
                    url: fileURL,
                    stage: "run-loop",
                    underlying: error
                )
                errors.append(wrapped)
            }
        }

        if filesAutoProtected {
            print(override.indent())
            print()
        }

        if !errors.isEmpty {
            print(
                "\nErrors encountered during concatenation"
                    + (location.map { " — \($0)" } ?? "")
            )

            for error in errors {
                if let concatError = error as? ConcatError {
                    print(" • \(concatError.localizedDescription)")
                } else {
                    print(" • \(error.localizedDescription)")
                }
            }

            throw MultiError(errors)
        }

        if copyToClipboard, let full = try? String(contentsOf: outputURL) {
            full.clipboard()

            if verbose {
                print("Copied output to clipboard")
            }
        }

        if verbose {
            print("Done: \(totalLines) lines written")
        }

        return totalLines
    }

    private func displayPath(
        for resolved: URL,
        fileManager: FileManager
    ) -> String {
        if relativePaths {
            return resolved.path.replacingOccurrences(
                of: fileManager.currentDirectoryPath + "/",
                with: ""
            )
        }

        return resolved.path
    }

    private func makeHeaderLabel(
        for resolved: URL,
        fileManager: FileManager
    ) -> String {
        let path = displayPath(
            for: resolved,
            fileManager: fileManager
        )

        guard includeSourceModifiedAt,
              let modifiedAt = sourceModifiedAtString(for: resolved)
        else {
            return path
        }

        return "\(path) [modified_at: \(modifiedAt)]"
    }

    private func sourceModifiedAtString(
        for url: URL
    ) -> String? {
        guard let values = try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        ), let date = values.contentModificationDate else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    private func applyObscuring(
        to lines: [String]
    ) -> [String] {
        guard !obscureMap.isEmpty else {
            return lines
        }

        var content = lines.joined(separator: "\n")

        for (value, method) in obscureMap {
            content = content.replacingOccurrences(
                of: value,
                with: obscureValue(value, method: method)
            )
        }

        return content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private func renderedBodyLines(
        from slice: FileLineSlice
    ) -> [String] {
        guard includeSourceLineNumbers else {
            return slice.lines
        }

        let width = String(max(1, slice.endLine)).count

        return slice.numberedLines().map { numbered in
            let label = String(
                format: "%\(width)d",
                numbered.line
            )

            return "\(label) | \(numbered.text)"
        }
    }
}
