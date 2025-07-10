import Foundation
import plate

public struct SnippetConcatenator {
    public let snippets: [FilteredSnippet]
    public let outputURL: URL
    public let delimiterStyle: DelimiterStyle
    public let delimiterClosure: Bool
    public let copyToClipboard: Bool
    public let verbose: Bool

    public init(
        snippets: [FilteredSnippet],
        outputURL: URL,
        delimiterStyle: DelimiterStyle = .boxed,
        delimiterClosure: Bool = false,
        copyToClipboard: Bool = false,
        verbose: Bool = false
    ) {
        self.snippets = snippets
        self.outputURL = outputURL
        self.delimiterStyle = delimiterStyle
        self.delimiterClosure = delimiterClosure
        self.copyToClipboard = copyToClipboard
        self.verbose = verbose
    }

    public func run() throws -> Int {
        let fm = FileManager.default
        fm.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        let handle = try FileHandle(forWritingTo: outputURL)
        defer { handle.closeFile() }

        if verbose {
            print("Concatenating \(snippets.count) snippets → \(outputURL.path)")
        }

        var total = 0
        for (i, snippet) in snippets.enumerated() {
            let header = delimiterStyle.header(for: snippet.file.path)
            if !header.isEmpty {
                handle.write(Data((header + "\n").utf8))
            }
            for line in snippet.lines {
                handle.write(Data((line + "\n").utf8))
                total += 1
            }
            if delimiterClosure {
                let footer = delimiterStyle.footer(for: snippet.file.path)
                handle.write(Data((footer + "\n").utf8))
            }
            if i < snippets.count - 1 {
                handle.write(Data("\n\n".utf8))
            }
        }

        if copyToClipboard, let out = try? String(contentsOf: outputURL) {
            out.clipboard()
        }

        if verbose {
            print("Done: \(total) lines written")
        }
        return total
    }
}
