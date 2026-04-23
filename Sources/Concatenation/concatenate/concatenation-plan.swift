public struct ConcatenationPlan: Sendable {
    public let context: ConcatenationContext?
    public let sources: [ConcatenationSource]
    public let options: ConcatenationRenderOptions

    public init(
        context: ConcatenationContext?,
        sources: [ConcatenationSource],
        options: ConcatenationRenderOptions
    ) {
        self.context = context
        self.sources = sources
        self.options = options
    }
}
