import TestFlows

enum ConcatenationFlowSuite: TestFlowRegistry {
    static let title = "Concatenation flow tests"

    static let flows: [TestFlow] = [
        conLegacyMigrationFlow,
        conAnyNestingFlow,
        conAnyExecutionFlow,
        conAnyLoweringFlow,
        conCacheFlow,
        conCacheStressFlow,
        conSourceSnapshotFlow,
        conCorpusFlow,
        conCorpusServiceFlow,
        conCorpusDefinitionFlow,
        conServiceTransportFlow,
        conServiceCorpusRPCFlow,
    ]
}
