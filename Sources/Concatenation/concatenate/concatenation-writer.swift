import Foundation
import Writers

public struct ConcatenationWriter: Sendable {
    public let output: URL
    public let options: WriteOptions

    public init(
        _ output: URL,
        options: WriteOptions = .init(
            existingFilePolicy: .overwrite,
            makeBackupOnOverride: false,
        )
    ) {
        self.output = output
        self.options = options
    }

    @discardableResult
    public func write(
        _ text: String
    ) throws -> SafeWriteResult {
        try StandardWriter(output).write(
            text,
            options: options
        )
    }
}
