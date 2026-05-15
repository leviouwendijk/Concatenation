import Foundation
import Selection

public struct ConcatenationSource: Sendable {
    public let file: URL
    public let presentedPath: String?
    public let selections: [ContentSelection]

    public init(
        file: URL,
        presentedPath: String? = nil,
        selections: [ContentSelection] = []
    ) {
        self.file = file.standardizedFileURL
        self.presentedPath = presentedPath
        self.selections = selections
    }
}
