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
    public let renderResult: ConcatenationRenderResult?
    public let writeResult: SafeWriteResult?
    public let renderedLineCount: Int

    public init(
        document: ConcatenationDocument,
        renderResult: ConcatenationRenderResult?,
        writeResult: SafeWriteResult?,
        renderedLineCount: Int
    ) {
        self.document = document
        self.renderResult = renderResult
        self.writeResult = writeResult
        self.renderedLineCount = renderedLineCount
    }

    public var text: String? {
        renderResult?.text
    }

    public var performedRender: Bool {
        renderResult != nil
    }

    public var performedWrite: Bool {
        writeResult != nil
    }
}
