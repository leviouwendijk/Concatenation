public struct ConcatenationStatistics: Sendable {
    public let sourceCount: Int
    public let renderedSectionCount: Int
    public let blockedFileCount: Int
    public let truncatedSectionCount: Int
    public let selectedLineCount: Int

    public init(
        sourceCount: Int,
        renderedSectionCount: Int,
        blockedFileCount: Int,
        truncatedSectionCount: Int,
        selectedLineCount: Int
    ) {
        self.sourceCount = sourceCount
        self.renderedSectionCount = renderedSectionCount
        self.blockedFileCount = blockedFileCount
        self.truncatedSectionCount = truncatedSectionCount
        self.selectedLineCount = selectedLineCount
    }
}
