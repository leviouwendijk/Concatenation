public struct ConcatenationDocument: Sendable {
    public let context: ConcatenationContext?
    public let sections: [ConcatenationSection]
    public let warnings: [ConcatenationWarning]
    public let statistics: ConcatenationStatistics

    public init(
        context: ConcatenationContext?,
        sections: [ConcatenationSection],
        warnings: [ConcatenationWarning],
        statistics: ConcatenationStatistics
    ) {
        self.context = context
        self.sections = sections
        self.warnings = warnings
        self.statistics = statistics
    }
}
