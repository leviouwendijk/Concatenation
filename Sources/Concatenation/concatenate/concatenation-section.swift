import Foundation
import Position

public struct ConcatenationSection: Sendable, Codable {
    public let file: URL
    public let sourcePath: String
    public let presentedPath: String
    public let modifiedAt: String?
    public let slices: [FileLineSlice]

    public let blankLineHeader: String
    public let blankLineFooter: String

    public let totalLineCount: Int
    public let keptLineCount: Int
    public let wasTruncated: Bool

    public init(
        file: URL,
        presentedPath: String,
        modifiedAt: String?,
        slices: [FileLineSlice],
        blankLineHeader: String,
        blankLineFooter: String,
        totalLineCount: Int,
        keptLineCount: Int,
        wasTruncated: Bool
    ) {
        let standardized = file.standardizedFileURL

        self.file = standardized
        self.sourcePath = standardized.path
        self.presentedPath = presentedPath
        self.modifiedAt = modifiedAt
        self.slices = slices
        self.blankLineHeader = blankLineHeader
        self.blankLineFooter = blankLineFooter
        self.totalLineCount = totalLineCount
        self.keptLineCount = keptLineCount
        self.wasTruncated = wasTruncated
    }

    /// The same body under another source's header: a section from the
    /// shared pool may have been written for a different output, path or
    /// copy of the same content.
    func rebound(
        file: URL,
        presentedPath: String,
        modifiedAt: String?
    ) -> Self {
        let file = file.standardizedFileURL

        guard file != self.file
                || presentedPath != self.presentedPath
                || modifiedAt != self.modifiedAt
        else {
            return self
        }

        return .init(
            file: file,
            presentedPath: presentedPath,
            modifiedAt: modifiedAt,
            slices: slices.map {
                FileLineSlice(
                    file: file,
                    startLine: $0.startLine,
                    lines: $0.lines
                )
            },
            blankLineHeader: blankLineHeader,
            blankLineFooter: blankLineFooter,
            totalLineCount: totalLineCount,
            keptLineCount: keptLineCount,
            wasTruncated: wasTruncated
        )
    }

    public var headerLabel: String {
        guard let modifiedAt else {
            return presentedPath
        }

        return "\(presentedPath) [modified_at: \(modifiedAt)]"
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

        return ConcatenationWarningText.truncation(
            keptLineCount: keptLineCount,
            totalLineCount: totalLineCount
        )
    }
}
