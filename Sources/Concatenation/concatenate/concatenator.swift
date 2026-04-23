import Foundation
import Terminal
import Indentation
import Primitives
import Clipboard
import Path
import Position
import Writers
import Readers
import Selection

public struct FileConcatenator: SafelyConcatenatable {
    public let inputFiles: [URL]
    public let outputURL: URL
    public let context: ConcatenationContext?

    public let selectedContentByFile: [URL: [ContentSelection]]

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
        selectedContentByFile: [URL: [ContentSelection]] = [:],

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
        self.selectedContentByFile = selectedContentByFile

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

    public var plan: ConcatenationPlan {
        ConcatenationPlan(
            context: context,
            sources: inputFiles.map { file in
                ConcatenationSource(
                    file: file,
                    selections: selections(
                        for: file.standardizedFileURL
                    )
                )
            },
            options: options
        )
    }

    public func document() throws -> ConcatenationDocument {
        let fileManager = FileManager.default

        var sections: [ConcatenationSection] = []
        var warnings: [ConcatenationWarning] = []
        var errors: [Error] = []

        var blockedFileCount = 0

        for source in plan.sources {
            let fileURL = source.file

            if protectSecrets && !allowSecrets {
                if isProtectedFile(fileURL) {
                    blockedFileCount += 1

                    let reason = "Detected filename/extension matching secret patterns."

                    warnings.append(
                        .init(
                            kind: .blockedByPolicy,
                            file: fileURL,
                            message: reason
                        )
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
                    let (deepMatched, deepReason) = deepSecretCheck(
                        fileURL
                    )

                    if deepMatched {
                        blockedFileCount += 1

                        let reason = deepReason
                            ?? "deep-secret heuristic matched"

                        warnings.append(
                            .init(
                                kind: .blockedByPolicy,
                                file: fileURL,
                                message: reason
                            )
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
                let resolved = try resolveSymlink(
                    at: fileURL
                )

                let section = try makeSection(
                    for: resolved,
                    fileManager: fileManager
                )

                if section.wasTruncated,
                   let message = section.truncationMessage {
                    warnings.append(
                        .init(
                            kind: .truncated,
                            file: resolved,
                            message: message
                        )
                    )
                }

                sections.append(section)
            } catch {
                let wrapped = ConcatError.fileProcessingFailed(
                    url: fileURL,
                    stage: "document-build",
                    underlying: error
                )

                errors.append(wrapped)
            }
        }

        if !errors.isEmpty {
            throw MultiError(errors)
        }

        let selectedLineCount = sections.reduce(0) { partial, section in
            partial + section.selectedLineCount
        }

        let statistics = ConcatenationStatistics(
            sourceCount: inputFiles.count,
            renderedSectionCount: sections.count,
            blockedFileCount: blockedFileCount,
            truncatedSectionCount: sections.filter(\.wasTruncated).count,
            selectedLineCount: selectedLineCount
        )

        return ConcatenationDocument(
            context: context,
            sections: sections,
            warnings: warnings,
            statistics: statistics
        )
    }

    public func render() throws -> ConcatenationRenderResult {
        let document = try document()
        return render(document)
    }

    @discardableResult
    public func write() throws -> ConcatenationWriteResult {
        if verbose {
            if let location {
                print("Concatenation location: \(location)")
            }

            print(
                "Concatenating \(inputFiles.count) files → \(outputURL.path)"
            )
        }

        let preparedDocument: ConcatenationDocument

        do {
            preparedDocument = try self.document()
        } catch {
            printErrors(for: error)
            throw error
        }

        printWarnings(from: preparedDocument)

        let rendered = render(preparedDocument)

        let writeResult = try ConcatenationWriter(
            outputURL
        ).write(rendered.text)

        if copyToClipboard {
            rendered.text.clipboard()

            if verbose {
                print("Copied output to clipboard")
            }
        }

        if verbose {
            print(
                "Done: \(preparedDocument.statistics.selectedLineCount) lines written"
            )
        }

        return ConcatenationWriteResult(
            document: preparedDocument,
            text: rendered.text,
            writeResult: writeResult,
            renderedLineCount: preparedDocument.statistics.selectedLineCount
        )
    }

    public func run() throws -> Int {
        try write().renderedLineCount
    }
}

private extension FileConcatenator {
    var options: ConcatenationRenderOptions {
        .init(
            delimiter: .init(
                style: delimiterStyle,
                closure: delimiterClosure
            ),
            line: .init(
                filemax: maxLinesPerFile,
                trimblanks: trimBlankLines,
                numbers: includeSourceLineNumbers
            ),
            output: .init(
                raw: rawOutput,
                relativepaths: relativePaths,
                modifiedstamp: includeSourceModifiedAt,
                obscurations: obscureMap
            )
        )
    }

    func render(
        _ document: ConcatenationDocument
    ) -> ConcatenationRenderResult {
        let text = ConcatenationRenderer(
            outputURL: outputURL,
            options: options
        ).render(document)

        return .init(
            document: document,
            text: text
        )
    }

    func makeSection(
        for resolved: URL,
        fileManager: FileManager
    ) throws -> ConcatenationSection {
        let readResult = try LineReader(resolved).read(
            options: .init(
                text: .init(
                    decoding: .commonTextFallbacks,
                    missingFilePolicy: .throwError,
                    newlineNormalization: .unix
                )
            )
        )

        let (processedLines, blankWarnings) = processBlankLines(
            readResult.lines,
            trim: options.line.trimblanks
        )

        let totalLineCount = processedLines.count

        let keptLines: [String]
        let wasTruncated: Bool

        if let limit = options.line.filemax,
           processedLines.count > limit {
            keptLines = Array(
                processedLines.prefix(limit)
            )
            wasTruncated = true
        } else {
            keptLines = processedLines
            wasTruncated = false
        }

        let obscuredLines = applyObscuring(
            to: keptLines,
            obscurations: options.output.obscurations
        )

        let slices = resolvedSlices(
            for: resolved,
            lines: obscuredLines,
            encodingUsed: readResult.encodingUsed,
            byteCount: readResult.byteCount,
            existed: readResult.existed
        )

        return ConcatenationSection(
            file: resolved,
            headerLabel: makeHeaderLabel(
                for: resolved,
                fileManager: fileManager
            ),
            slices: slices,
            blankLineHeader: blankWarnings.header,
            blankLineFooter: blankWarnings.footer,
            totalLineCount: totalLineCount,
            keptLineCount: keptLines.count,
            wasTruncated: wasTruncated
        )
    }

    func resolvedSlices(
        for file: URL,
        lines: [String],
        encodingUsed: TextEncoding?,
        byteCount: Int,
        existed: Bool
    ) -> [FileLineSlice] {
        let fileSelections = selections(
            for: file.standardizedFileURL
        )

        let readResult = LineReadResult(
            url: file,
            lines: lines,
            encodingUsed: encodingUsed,
            byteCount: byteCount,
            existed: existed
        )

        return SelectionResolver.resolve(
            file: file,
            readResult: readResult,
            selections: fileSelections
        ).slices
    }

    func selections(
        for file: URL
    ) -> [ContentSelection] {
        let standardized = file.standardizedFileURL

        if let exact = selectedContentByFile[standardized] {
            return exact
        }

        if let exact = selectedContentByFile[file] {
            return exact
        }

        return []
    }

    func printWarnings(
        from document: ConcatenationDocument
    ) {
        let blockedWarnings = document.warnings.filter {
            $0.kind == .blockedByPolicy
        }

        if !blockedWarnings.isEmpty {
            for warning in blockedWarnings {
                printProtectionNotifier(
                    file: warning.file.path,
                    reason: warning.message
                )
            }

            print("Use --allow-secrets to override".indent())
            print()
        }

        let truncatedWarnings = document.warnings.filter {
            $0.kind == .truncated
        }

        for warning in truncatedWarnings {
            print(
                warning.message.ansi(.yellow)
            )
        }
    }

    func printErrors(
        for error: Error
    ) {
        let errors: [Error]

        if let multi = error as? Errors {
            errors = multi.errors
        } else {
            errors = [error]
        }

        guard !errors.isEmpty else {
            return
        }

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
    }

    private func displayPath(
        for resolved: URL,
        fileManager: FileManager
    ) -> String {
        if options.output.relativepaths {
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

        guard options.output.modifiedstamp,
              let modifiedAt = sourceModifiedAtString(
                for: resolved
              ) else {
            return path
        }

        return "\(path) [modified_at: \(modifiedAt)]"
    }

    private func sourceModifiedAtString(
        for url: URL
    ) -> String? {
        guard let values = try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        ),
        let date = values.contentModificationDate else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    private func applyObscuring(
        to lines: [String],
        obscurations: [String: String]
    ) -> [String] {
        guard !obscurations.isEmpty else {
            return lines
        }

        var content = lines.joined(separator: "\n")

        for (value, method) in obscurations {
            content = content.replacingOccurrences(
                of: value,
                with: obscureValue(value, method: method)
            )
        }

        return content
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)
    }
}

// public struct FileConcatenator: SafelyConcatenatable {
//     public let inputFiles: [URL]
//     public let outputURL: URL
//     public let context: ConcatenationContext?

//     public let selectedContentByFile: [URL: [ContentSelection]]

//     public let delimiterStyle: DelimiterStyle
//     public let delimiterClosure: Bool
//     public let maxLinesPerFile: Int?
//     public let trimBlankLines: Bool
//     public let relativePaths: Bool
//     public let rawOutput: Bool
//     public let includeSourceLineNumbers: Bool
//     public let includeSourceModifiedAt: Bool

//     public let obscureMap: [String: String]
//     public let copyToClipboard: Bool
//     public let verbose: Bool

//     public let location: String?

//     public let protectSecrets: Bool
//     public let allowSecrets: Bool
//     public let failOnBlockedFiles: Bool
//     public let deepSecretInspection: Bool

//     public init(
//         inputFiles: [URL],
//         outputURL: URL,
//         context: ConcatenationContext? = nil,
//         selectedContentByFile: [URL: [ContentSelection]] = [:],

//         delimiterStyle: DelimiterStyle = .boxed,
//         delimiterClosure: Bool = false,
//         maxLinesPerFile: Int? = 10_000,
//         trimBlankLines: Bool = true,
//         relativePaths: Bool = true,
//         rawOutput: Bool = false,
//         includeSourceLineNumbers: Bool = false,
//         includeSourceModifiedAt: Bool = false,
//         obscureMap: [String: String] = [:],

//         copyToClipboard: Bool = false,
//         verbose: Bool = false,

//         location: String? = nil,

//         protectSecrets: Bool = true,
//         allowSecrets: Bool = false,
//         failOnBlockedFiles: Bool = false,
//         deepSecretInspection: Bool = false
//     ) {
//         self.inputFiles = inputFiles
//         self.outputURL = outputURL
//         self.context = context
//         self.selectedContentByFile = selectedContentByFile

//         self.delimiterStyle = delimiterStyle
//         self.delimiterClosure = delimiterClosure
//         self.maxLinesPerFile = maxLinesPerFile
//         self.trimBlankLines = trimBlankLines
//         self.relativePaths = relativePaths
//         self.rawOutput = rawOutput
//         self.includeSourceLineNumbers = includeSourceLineNumbers
//         self.includeSourceModifiedAt = includeSourceModifiedAt
//         self.obscureMap = obscureMap

//         self.copyToClipboard = copyToClipboard
//         self.verbose = verbose

//         self.location = location

//         self.protectSecrets = protectSecrets
//         self.allowSecrets = allowSecrets
//         self.failOnBlockedFiles = failOnBlockedFiles
//         self.deepSecretInspection = deepSecretInspection
//     }

//     public func run() throws -> Int {
//         let fileManager = FileManager.default
//         let writer = StandardWriter(outputURL)

//         let bootstrapContent: String = {
//             guard !rawOutput, let context else {
//                 return ""
//             }

//             let header = context.header(outputURL: outputURL)

//             guard !header.isEmpty else {
//                 return ""
//             }

//             return header + "\n\n"
//         }()

//         try writer.write(
//             bootstrapContent,
//             options: .init(
//                 existingFilePolicy: .overwrite,
//                 makeBackupOnOverride: true,
//                 whitespaceOnlyIsBlank: true,
//                 createIntermediateDirectories: true,
//                 atomic: true,
//                 maxBackupSets: 5
//             )
//         )

//         let handle = try FileHandle(forWritingTo: outputURL)
//         defer { handle.closeFile() }
//         handle.seekToEndOfFile()

//         if verbose {
//             if let location {
//                 print("Concatenation location: \(location)")
//             }
//             print("Concatenating \(inputFiles.count) files → \(outputURL.path)")
//         }

//         var totalLines = 0
//         var errors: [Error] = []

//         var filesAutoProtected = false
//         let override = "Use --allow-secrets to override"

//         for fileURL in inputFiles {
//             if protectSecrets && !allowSecrets {
//                 if isProtectedFile(fileURL) {
//                     filesAutoProtected = true
//                     let reason = "Detected filename/extension matching secret patterns."
//                     printProtectionNotifier(
//                         file: fileURL.path,
//                         reason: reason
//                     )

//                     if failOnBlockedFiles {
//                         errors.append(
//                             ConcatError.fileBlockedByPolicy(
//                                 url: fileURL,
//                                 reason: reason
//                             )
//                         )
//                     }

//                     continue
//                 }

//                 if deepSecretInspection {
//                     let (deepMatched, deepReason) = deepSecretCheck(fileURL)

//                     if deepMatched {
//                         filesAutoProtected = true
//                         let reason = deepReason ?? "deep-secret heuristic matched"

//                         printProtectionNotifier(
//                             file: fileURL.path,
//                             reason: reason
//                         )

//                         if failOnBlockedFiles {
//                             errors.append(
//                                 ConcatError.fileBlockedByPolicy(
//                                     url: fileURL,
//                                     reason: reason
//                                 )
//                             )
//                         }

//                         continue
//                     }
//                 }
//             }

//             do {
//                 let resolved = try resolveSymlink(at: fileURL)
//                 var lines = try readLines(from: resolved)

//                 let (processedLines, blankWarnings) = processBlankLines(
//                     lines,
//                     trim: trimBlankLines
//                 )
//                 lines = processedLines

//                 let writeLines: [String]
//                 let wasTruncated: Bool

//                 if let limit = maxLinesPerFile, lines.count > limit {
//                     writeLines = Array(lines.prefix(limit))
//                     wasTruncated = true
//                 } else {
//                     writeLines = lines
//                     wasTruncated = false
//                 }

//                 let selections = selectedContentByFile[resolved.standardizedFileURL] ?? []
//                 let obscuredContent = applyObscuring(
//                     to: writeLines
//                 ).joined(separator: "\n")

//                 let slices = ContentSelectionSlicer.slice(
//                     content: obscuredContent,
//                     file: resolved,
//                     selections: selections
//                 )

//                 if !rawOutput {
//                     let headerLabel = makeHeaderLabel(
//                         for: resolved,
//                         fileManager: fileManager
//                     )

//                     let header = delimiterStyle.header(for: headerLabel) + "\n"
//                     handle.write(Data(header.utf8))
//                     handle.write(Data(blankWarnings.header.utf8))
//                 }

//                 for (index, slice) in slices.enumerated() {
//                     let bodyLines = renderedBodyLines(from: slice)

//                     for line in bodyLines {
//                         handle.write(Data((line + "\n").utf8))
//                     }

//                     totalLines += bodyLines.count

//                     if index < slices.count - 1 {
//                         handle.write(Data("\n".utf8))
//                     }
//                 }

//                 if wasTruncated {
//                     let message = "(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)\n"
//                     handle.write(Data(message.utf8))
//                     print(
//                         "(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)"
//                             .ansi(.yellow)
//                     )
//                 }

//                 if !rawOutput {
//                     let footerLabel = makeHeaderLabel(
//                         for: resolved,
//                         fileManager: fileManager
//                     )

//                     handle.write(Data(blankWarnings.footer.utf8))

//                     if delimiterClosure {
//                         handle.write(
//                             Data((delimiterStyle.footer(for: footerLabel) + "\n").utf8)
//                         )
//                     }
//                 }

//                 if fileURL != inputFiles.last {
//                     handle.write(Data("\n\n".utf8))
//                 }
//             } catch {
//                 let wrapped = ConcatError.fileProcessingFailed(
//                     url: fileURL,
//                     stage: "run-loop",
//                     underlying: error
//                 )
//                 errors.append(wrapped)
//             }
//         }

//         if filesAutoProtected {
//             print(override.indent())
//             print()
//         }

//         if !errors.isEmpty {
//             print(
//                 "\nErrors encountered during concatenation"
//                     + (location.map { " — \($0)" } ?? "")
//             )

//             for error in errors {
//                 if let concatError = error as? ConcatError {
//                     print(" • \(concatError.localizedDescription)")
//                 } else {
//                     print(" • \(error.localizedDescription)")
//                 }
//             }

//             throw MultiError(errors)
//         }

//         if copyToClipboard, let full = try? String(contentsOf: outputURL) {
//             full.clipboard()

//             if verbose {
//                 print("Copied output to clipboard")
//             }
//         }

//         if verbose {
//             print("Done: \(totalLines) lines written")
//         }

//         return totalLines
//     }

//     private func displayPath(
//         for resolved: URL,
//         fileManager: FileManager
//     ) -> String {
//         if relativePaths {
//             return resolved.path.replacingOccurrences(
//                 of: fileManager.currentDirectoryPath + "/",
//                 with: ""
//             )
//         }

//         return resolved.path
//     }

//     private func makeHeaderLabel(
//         for resolved: URL,
//         fileManager: FileManager
//     ) -> String {
//         let path = displayPath(
//             for: resolved,
//             fileManager: fileManager
//         )

//         guard includeSourceModifiedAt,
//               let modifiedAt = sourceModifiedAtString(for: resolved)
//         else {
//             return path
//         }

//         return "\(path) [modified_at: \(modifiedAt)]"
//     }

//     private func sourceModifiedAtString(
//         for url: URL
//     ) -> String? {
//         guard let values = try? url.resourceValues(
//             forKeys: [.contentModificationDateKey]
//         ), let date = values.contentModificationDate else {
//             return nil
//         }

//         let formatter = ISO8601DateFormatter()
//         return formatter.string(from: date)
//     }

//     private func applyObscuring(
//         to lines: [String]
//     ) -> [String] {
//         guard !obscureMap.isEmpty else {
//             return lines
//         }

//         var content = lines.joined(separator: "\n")

//         for (value, method) in obscureMap {
//             content = content.replacingOccurrences(
//                 of: value,
//                 with: obscureValue(value, method: method)
//             )
//         }

//         return content
//             .split(separator: "\n", omittingEmptySubsequences: false)
//             .map(String.init)
//     }

//     private func renderedBodyLines(
//         from slice: FileLineSlice
//     ) -> [String] {
//         guard includeSourceLineNumbers else {
//             return slice.lines
//         }

//         let width = String(max(1, slice.endLine)).count

//         return slice.numberedLines().map { numbered in
//             let label = String(
//                 format: "%\(width)d",
//                 numbered.line
//             )

//             return "\(label) | \(numbered.text)"
//         }
//     }
// }
