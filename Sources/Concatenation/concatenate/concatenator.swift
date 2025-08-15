import Foundation
import plate

public struct FileConcatenator {
    public let inputFiles: [URL]
    public let outputURL: URL

    public let delimiterStyle: DelimiterStyle
    public let delimiterClosure: Bool          
    public let maxLinesPerFile: Int?           
    public let trimBlankLines: Bool
    public let relativePaths: Bool
    public let rawOutput: Bool

    public let obscureMap: [String:String]     
    public let copyToClipboard: Bool
    public let verbose: Bool

    public init(
        inputFiles: [URL],
        outputURL: URL,
        delimiterStyle: DelimiterStyle = .boxed,
        delimiterClosure: Bool = false,
        maxLinesPerFile: Int? = 5000,
        trimBlankLines: Bool = true,
        relativePaths: Bool = true,
        rawOutput: Bool = false,
        obscureMap: [String:String] = [:],
        copyToClipboard: Bool = false,
        verbose: Bool = false
    ) {
        self.inputFiles = inputFiles
        self.outputURL = outputURL
        self.delimiterStyle = delimiterStyle
        self.delimiterClosure = delimiterClosure
        self.maxLinesPerFile = maxLinesPerFile
        self.trimBlankLines = trimBlankLines
        self.relativePaths = relativePaths
        self.rawOutput = rawOutput
        self.obscureMap = obscureMap
        self.copyToClipboard = copyToClipboard
        self.verbose = verbose
    }

    public func run() throws -> Int {
        let fm = FileManager.default
        fm.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        let handle = try FileHandle(forWritingTo: outputURL)

        defer { handle.closeFile() }

        if verbose {
            print("Concatenating \(inputFiles.count) files → \(outputURL.path)")
        }

        var totalLines = 0
        var errors: [Error] = []

        for fileURL in inputFiles {
            do {
                let resolved = try resolveSymlink(at: fileURL)
                var lines = try readLines(from: resolved)

                let (processedLines, blankWarnings) = processBlankLines(lines, trim: trimBlankLines)
                lines = processedLines

                var content = lines.joined(separator: "\n")
                for (value, method) in obscureMap {
                    content = content.replacingOccurrences(of: value, with: obscureValue(value, method: method))
                }

                if !rawOutput {
                    let path = relativePaths
                        ? resolved.path.replacingOccurrences(of: fm.currentDirectoryPath + "/", with: "")
                        : resolved.path
                    let hdr = delimiterStyle.header(for: path) + "\n"
                    handle.write(Data(hdr.utf8))
                    handle.write(Data(blankWarnings.header.utf8))
                }

                // let writeLines = maxLinesPerFile.map { Array(lines.prefix($0)) } ?? lines
                // for line in writeLines {
                //     handle.write(Data((line + "\n").utf8))
                // }
                // totalLines += writeLines.count

                let writeLines: [String]
                let wasTruncated: Bool
                if let limit = maxLinesPerFile, lines.count > limit {
                    writeLines = Array(lines.prefix(limit))
                    wasTruncated = true
                } else {
                    writeLines = lines
                    wasTruncated = false
                }

                for line in writeLines {
                    handle.write(Data((line + "\n").utf8))
                }

                if wasTruncated {
                    handle.write(Data("(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)\n".utf8))
                    print("(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)".ansi(.yellow))
                }

                totalLines += writeLines.count

                if !rawOutput {
                    let path = relativePaths
                        ? resolved.path.replacingOccurrences(of: fm.currentDirectoryPath + "/", with: "")
                        : resolved.path
                    handle.write(Data(blankWarnings.footer.utf8))
                    if delimiterClosure {
                        handle.write(Data((delimiterStyle.footer(for: path) + "\n").utf8))
                    }
                }

                if fileURL != inputFiles.last {
                    handle.write(Data("\n\n".utf8))
                }
            } catch {
                errors.append(error)
            }
        }

        if !errors.isEmpty {
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
}
