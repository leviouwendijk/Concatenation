import Foundation
import Path
import Position

enum ContentSelectionSlicer {
    static func slice(
        content: String,
        file: URL,
        selections: [ContentSelection]
    ) -> [FileLineSlice] {
        guard !selections.isEmpty else {
            return [
                FileLineSlice(
                    file: file,
                    startLine: 1,
                    lines: splitLines(content)
                )
            ]
        }

        let allLines = splitLines(content)

        var out: [FileLineSlice] = []

        for selection in selections {
            switch selection {
            case .lines(let range):
                if let slice = lineRangeSlice(
                    allLines: allLines,
                    file: file,
                    range: range
                ) {
                    out.append(slice)
                }

            case .point(let position):
                let range = LineRange(
                    uncheckedStart: position.line,
                    uncheckedEnd: position.line
                )

                if let slice = lineRangeSlice(
                    allLines: allLines,
                    file: file,
                    range: range
                ) {
                    out.append(slice)
                }

            case .span(let span):
                let range = LineRange(
                    uncheckedStart: span.start.line,
                    uncheckedEnd: span.end.line
                )

                if let slice = lineRangeSlice(
                    allLines: allLines,
                    file: file,
                    range: range
                ) {
                    out.append(slice)
                }

            case .anchor(let anchor):
                out.append(
                    contentsOf: anchorSlices(
                        allLines: allLines,
                        file: file,
                        anchor: anchor
                    )
                )
            }
        }

        return mergeOverlapping(out)
    }

    static func lineRangeSlice(
        allLines: [String],
        file: URL,
        range: LineRange
    ) -> FileLineSlice? {
        guard !allLines.isEmpty else {
            return nil
        }

        let startLine = max(1, range.start)
        let endLine = min(allLines.count, range.end)

        guard endLine >= startLine else {
            return nil
        }

        let startIndex = startLine - 1
        let endIndex = endLine

        return FileLineSlice(
            file: file,
            startLine: startLine,
            lines: Array(allLines[startIndex..<endIndex])
        )
    }

    static func anchorSlices(
        allLines: [String],
        file: URL,
        anchor: ContentAnchorSelection
    ) -> [FileLineSlice] {
        var out: [FileLineSlice] = []

        for (index, line) in allLines.enumerated() where line.contains(anchor.text) {
            let startLine = max(1, index + 1 + anchor.offset)
            let endLine = min(
                allLines.count,
                startLine + anchor.count - 1
            )

            guard endLine >= startLine else {
                continue
            }

            out.append(
                FileLineSlice(
                    file: file,
                    startLine: startLine,
                    lines: Array(allLines[(startLine - 1)..<endLine])
                )
            )
        }

        return out
    }

    static func splitLines(
        _ content: String
    ) -> [String] {
        content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    static func mergeOverlapping(
        _ slices: [FileLineSlice]
    ) -> [FileLineSlice] {
        let sorted = slices.sorted {
            if $0.file != $1.file {
                return $0.file.path < $1.file.path
            }

            return $0.startLine < $1.startLine
        }

        var out: [FileLineSlice] = []

        for slice in sorted {
            guard let last = out.last,
                  last.file == slice.file,
                  slice.startLine <= (last.endLine + 1) else {
                out.append(slice)
                continue
            }

            let mergedStart = last.startLine
            let mergedEnd = max(last.endLine, slice.endLine)

            let lastLines = last.lines
            let mergedLines: [String]

            if slice.endLine <= last.endLine {
                mergedLines = lastLines
            } else {
                let overlap = max(0, last.endLine - slice.startLine + 1)
                mergedLines = lastLines + slice.lines.dropFirst(overlap)
            }

            out[out.count - 1] = FileLineSlice(
                file: slice.file,
                startLine: mergedStart,
                lines: Array(mergedLines.prefix(mergedEnd - mergedStart + 1))
            )
        }

        return out
    }
}
