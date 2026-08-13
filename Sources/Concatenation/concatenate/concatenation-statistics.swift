public struct ConcatenationStatistics: Sendable {
    public struct Cache: Sendable, Equatable {
        public let metadataInspections: Int
        public let safeguardReads: Int
        public let safeguardHits: Int
        public let sourceReads: Int
        public let metadataHits: Int
        public let contentHits: Int
        public let rebuilds: Int

        public init(
            metadataInspections: Int = 0,
            safeguardReads: Int = 0,
            safeguardHits: Int = 0,
            sourceReads: Int = 0,
            metadataHits: Int = 0,
            contentHits: Int = 0,
            rebuilds: Int = 0
        ) {
            self.metadataInspections = metadataInspections
            self.safeguardReads = safeguardReads
            self.safeguardHits = safeguardHits
            self.sourceReads = sourceReads
            self.metadataHits = metadataHits
            self.contentHits = contentHits
            self.rebuilds = rebuilds
        }
    }

    public let sourceCount: Int
    public let renderedSectionCount: Int
    public let blockedFileCount: Int
    public let truncatedSectionCount: Int
    public let selectedLineCount: Int
    public let cache: Cache

    public init(
        sourceCount: Int,
        renderedSectionCount: Int,
        blockedFileCount: Int,
        truncatedSectionCount: Int,
        selectedLineCount: Int,
        cache: Cache = .init()
    ) {
        self.sourceCount = sourceCount
        self.renderedSectionCount = renderedSectionCount
        self.blockedFileCount = blockedFileCount
        self.truncatedSectionCount = truncatedSectionCount
        self.selectedLineCount = selectedLineCount
        self.cache = cache
    }
}
