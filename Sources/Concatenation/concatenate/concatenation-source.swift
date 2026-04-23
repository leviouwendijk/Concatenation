import Foundation
import Selection

public struct ConcatenationSource: Sendable {
    public let file: URL
    public let selections: [ContentSelection]

    public init(
        file: URL,
        selections: [ContentSelection] = []
    ) {
        self.file = file.standardizedFileURL
        self.selections = selections
    }
}

