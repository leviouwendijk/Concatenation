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
        self.init(
            standardizedFile:
                file.standardizedFileURL,
            presentedPath:
                presentedPath,
            selections:
                selections
        )
    }

    init(
        standardizedFile file: URL,
        presentedPath: String? = nil,
        selections: [ContentSelection] = []
    ) {
        self.file = file
        self.presentedPath = presentedPath
        self.selections = selections
    }
}
