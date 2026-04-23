import Writers

public struct ConcatenationRenderResult: Sendable {
    public let document: ConcatenationDocument
    public let text: String

    public init(
        document: ConcatenationDocument,
        text: String
    ) {
        self.document = document
        self.text = text
    }
}

public struct ConcatenationWriteResult: Sendable {
    public let document: ConcatenationDocument
    public let text: String
    public let writeResult: SafeWriteResult
    public let renderedLineCount: Int

    public init(
        document: ConcatenationDocument,
        text: String,
        writeResult: SafeWriteResult,
        renderedLineCount: Int
    ) {
        self.document = document
        self.text = text
        self.writeResult = writeResult
        self.renderedLineCount = renderedLineCount
    }
}
