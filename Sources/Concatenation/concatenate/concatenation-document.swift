import IO

public struct ConcatenationDocument: Sendable {
    public let context: ConcatenationContext?
    public let sections: [ConcatenationSection]
    public let warnings: [ConcatenationWarning]
    public let statistics: ConcatenationStatistics

    let sourceMaterialFingerprint: ContentFingerprint?

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
        self.sourceMaterialFingerprint = nil
    }

    init(
        context: ConcatenationContext?,
        sections: [ConcatenationSection],
        warnings: [ConcatenationWarning],
        statistics: ConcatenationStatistics,
        sourceMaterialFingerprint: ContentFingerprint
    ) {
        self.context = context
        self.sections = sections
        self.warnings = warnings
        self.statistics = statistics
        self.sourceMaterialFingerprint = sourceMaterialFingerprint
    }
}
