import Concatenation
import Foundation
import IO

public extension ConcatenationExecution {
    /// An execution for the `.conany` at `configURL`: parsed (unless
    /// `configuration` is given), lowered with `ignoreMap`'s entries as
    /// excludes, and obscuring with its `[Obscure]` values.
    init(
        conAnyAt configURL: URL,
        configuration: ConAnyConfig? = nil,
        ignoreMap: IgnoreMap = .init(),
        options: ConcatenationExecutionOptions = .init()
    ) throws {
        let configURL = configURL.standardizedFileURL

        let configuration = try configuration
            ?? ConAnyParser.parseFile(
                at: configURL
            )

        let definition = try ConAnyLowering(
            baseDirectory: configURL.deletingLastPathComponent()
        ).definition(
            configuration,
            declaredAt: configURL,
            ignoreMap: ignoreMap
        )

        var options = options

        options.obscurations.merge(
            ignoreMap.obscureValues
        ) { _, ignored in
            ignored
        }

        try self.init(
            definition: definition,
            options: options
        )
    }
}

public extension ConcatenationSession {
    func render(
        conAnyAt configURL: URL,
        options: ConcatenationExecutionOptions = .init(),
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConcatenationRenderBatchResult {
        try await ConcatenationExecution(
            conAnyAt: configURL,
            options: options
        )
        .render(
            using: self,
            concurrency: concurrency
        )
    }
}
