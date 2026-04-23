import Foundation
import Position

public struct ConcatenationSection: Sendable {
    public let file: URL
    public let headerLabel: String
    public let slices: [FileLineSlice]

    public let blankLineHeader: String
    public let blankLineFooter: String

    public let totalLineCount: Int
    public let keptLineCount: Int
    public let wasTruncated: Bool

    public init(
        file: URL,
        headerLabel: String,
        slices: [FileLineSlice],
        blankLineHeader: String,
        blankLineFooter: String,
        totalLineCount: Int,
        keptLineCount: Int,
        wasTruncated: Bool
    ) {
        self.file = file.standardizedFileURL
        self.headerLabel = headerLabel
        self.slices = slices
        self.blankLineHeader = blankLineHeader
        self.blankLineFooter = blankLineFooter
        self.totalLineCount = totalLineCount
        self.keptLineCount = keptLineCount
        self.wasTruncated = wasTruncated
    }

    public var selectedLineCount: Int {
        slices.reduce(0) { partial, slice in
            partial + slice.lines.count
        }
    }

    public var truncationMessage: String? {
        guard wasTruncated else {
            return nil
        }

        return "(!): truncated — file exceeded max line limit (\(keptLineCount)/\(totalLineCount) lines)"
    }
}
