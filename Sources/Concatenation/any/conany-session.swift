import Foundation
import IO

public extension ConcatenationSession {
    func render(
        conAnyAt configURL: URL,
        options: ConAnyExecutionOptions = .init(),
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConAnyRenderBatchResult {
        try await ConAnyExecution(
            configURL: configURL,
            options: options
        )
        .render(
            using: self,
            concurrency: concurrency
        )
    }
}
