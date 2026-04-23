import Foundation
import Position

public struct ConcatenationRenderer: Sendable {
    public let outputURL: URL
    public let options: ConcatenationRenderOptions

    public init(
        outputURL: URL,
        options: ConcatenationRenderOptions
    ) {
        self.outputURL = outputURL
        self.options = options
    }

    public func render(
        _ document: ConcatenationDocument
    ) -> String {
        var output = ""

        if !options.output.raw,
           let context = document.context {
            let header = context.header(
                outputURL: outputURL
            )

            if !header.isEmpty {
                output += header
                output += "\n\n"
            }
        }

        for (sectionIndex, section) in document.sections.enumerated() {
            if !options.output.raw {
                output += options.delimiter.style.header(
                    for: section.headerLabel
                )
                output += "\n"
                output += section.blankLineHeader
            }

            for (sliceIndex, slice) in section.slices.enumerated() {
                for line in renderedBodyLines(from: slice) {
                    output += line
                    output += "\n"
                }

                if sliceIndex < section.slices.count - 1 {
                    output += "\n"
                }
            }

            if let truncationMessage = section.truncationMessage {
                output += truncationMessage
                output += "\n"
            }

            if !options.output.raw {
                output += section.blankLineFooter

                if options.delimiter.closure {
                    output += options.delimiter.style.footer(
                        for: section.headerLabel
                    )
                    output += "\n"
                }
            }

            if sectionIndex < document.sections.count - 1 {
                output += "\n\n"
            }
        }

        return output
    }
}

private extension ConcatenationRenderer {
    func renderedBodyLines(
        from slice: FileLineSlice
    ) -> [String] {
        guard !options.line.numbers else {
            let width = String(
                max(1, slice.endLine)
            ).count

            return slice.numberedLines().map { numberedLine in
                let label = String(
                    format: "%\(width)d",
                    numberedLine.line
                )

                return "\(label) | \(numberedLine.text)"
            }
        }

        return slice.lines
    }
}
