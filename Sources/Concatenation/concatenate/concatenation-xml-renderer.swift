import Foundation

public struct ConcatenationXMLRenderer: Sendable {
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
        var lines: [String] = []

        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<concatenation output="\#(xml(outputURL.path))">"#)

        if let context = document.context,
           !options.output.raw {
            lines.append("    <context>")

            if let title = context.title,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("        <title>\(xml(title))</title>")
            }

            if let details = context.details,
               !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("        <details>\(xml(details))</details>")
            }

            if let dependencies = context.dependencies,
               !dependencies.isEmpty {
                lines.append("        <dependencies>")

                for dependency in dependencies {
                    lines.append("            <dependency>\(xml(dependency))</dependency>")
                }

                lines.append("        </dependencies>")
            }

            if let concatenatedFile = context.concatenatedFile {
                lines.append("        <concatenated-file>\(xml(concatenatedFile))</concatenated-file>")
            }

            lines.append("    </context>")
        }

        lines.append("    <statistics")
        lines.append("        source-count=\"\(document.statistics.sourceCount)\"")
        lines.append("        rendered-section-count=\"\(document.statistics.renderedSectionCount)\"")
        lines.append("        blocked-file-count=\"\(document.statistics.blockedFileCount)\"")
        lines.append("        truncated-section-count=\"\(document.statistics.truncatedSectionCount)\"")
        lines.append("        selected-line-count=\"\(document.statistics.selectedLineCount)\"")
        lines.append("    />")

        if !document.warnings.isEmpty {
            lines.append("    <warnings>")

            for warning in document.warnings {
                lines.append("        <warning kind=\"\(xml(warning.kind.rawValue))\" file=\"\(xml(warning.file.path))\">")
                lines.append("            <message>\(xml(warning.message))</message>")
                lines.append("        </warning>")
            }

            lines.append("    </warnings>")
        }

        lines.append("    <sections>")

        for section in document.sections {
            lines.append("        <section")
            lines.append("            path=\"\(xml(section.presentedPath))\"")
            lines.append("            source=\"\(xml(section.sourcePath))\"")
            lines.append("            label=\"\(xml(section.headerLabel))\"")

            if let modifiedAt = section.modifiedAt {
                lines.append("            modified-at=\"\(xml(modifiedAt))\"")
            }

            lines.append("            total-line-count=\"\(section.totalLineCount)\"")
            lines.append("            kept-line-count=\"\(section.keptLineCount)\"")
            lines.append("            selected-line-count=\"\(section.selectedLineCount)\"")
            lines.append("            truncated=\"\(section.wasTruncated)\"")
            lines.append("        >")

            for slice in section.slices {
                lines.append("            <slice start-line=\"\(slice.startLine)\" end-line=\"\(slice.endLine)\">")

                for numbered in slice.numberedLines() {
                    lines.append("                <line number=\"\(numbered.line)\">\(xml(numbered.text))</line>")
                }

                lines.append("            </slice>")
            }

            if let truncationMessage = section.truncationMessage {
                lines.append("            <truncation>\(xml(truncationMessage))</truncation>")
            }

            lines.append("        </section>")
        }

        lines.append("    </sections>")
        lines.append("</concatenation>")

        return lines.joined(separator: "\n") + "\n"
    }
}

private func xml(
    _ raw: String
) -> String {
    raw
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
