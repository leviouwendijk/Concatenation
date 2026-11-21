import Concatenation
import Foundation
import Path
import PathParsing
import Selection

/// Lowers a parsed `.conany` into a `ConcatenationDefinition`.
public struct ConAnyLowering {
    public let baseDirectory: URL

    public init(
        baseDirectory: URL
    ) {
        self.baseDirectory = baseDirectory.standardizedFileURL
    }

    public func definition(
        _ configuration: ConAnyConfig,
        declaredAt configurationURL: URL,
        ignoreMap: IgnoreMap = .init()
    ) throws -> ConcatenationDefinition {
        let ignoreExcludes = Self.excludes(
            from: ignoreMap
        )

        return .init(
            configuration: configurationURL,
            outputs: try configuration.renderables.map {
                try output(
                    $0,
                    additionalExcludes: ignoreExcludes
                )
            }
        )
    }

    public func output(
        _ renderable: ConAnyRenderableObject,
        additionalExcludes: [PathExpression] = []
    ) throws -> ConcatenationDefinition.Output {
        var specification = try ConAnyPathPorting.makeSpecification(
            from: renderable,
            relativeTo: baseDirectory
        )

        specification.excludes += additionalExcludes

        return .init(
            name: renderable.output,
            destination: outputURL(
                for: renderable
            ),
            specification: specification,
            presentation: presentationRules(
                for: renderable
            ),
            context: renderable.context
        )
    }

    public func outputURL(
        for renderable: ConAnyRenderableObject
    ) -> URL {
        ConAnyPathPorting.outputURL(
            for: renderable.output,
            relativeTo: baseDirectory
        )
    }

    /// One rule per include block, most specific base first; a block without
    /// a base covers everything and goes last.
    func presentationRules(
        for renderable: ConAnyRenderableObject
    ) -> [ConcatenationDefinition.PresentationRule] {
        let candidates: [(rank: Int, rule: ConcatenationDefinition.PresentationRule)] =
            renderable.includeBlocks.map { block in
                let base = try? ConAnyPathPorting.resolvedBaseURL(
                    for: block,
                    relativeTo: baseDirectory
                )

                let options = try? ConAnyPathPorting.presentationOptions(
                    for: block,
                    relativeTo: baseDirectory
                )

                let style: ConcatenationDefinition.PresentationRule.Style

                switch (block.show, options) {
                case (_, nil):
                    style = .unchanged
                case (.basename, _):
                    style = .basename
                case (_, let options?):
                    style = .path(options)
                }

                return (
                    rank: base?.standardizedFileURL.path.count ?? -1,
                    rule: .init(
                        base: base,
                        style: style
                    )
                )
            }

        return candidates
            .enumerated()
            .sorted {
                $0.element.rank != $1.element.rank
                    ? $0.element.rank > $1.element.rank
                    : $0.offset < $1.offset
            }
            .map(\.element.rule)
    }

    /// `.conignore` entries as excludes.
    ///
    /// An entry used to be matched as a regex over the whole absolute path,
    /// with `*` crossing `/` and `?` any one character. Only entries of the
    /// form `*<suffix>` (no other `*`, no `/`) could ever match: they match a last component ending in
    /// `<suffix>`, which is `/**/*<suffix>`. Every other entry (bare names,
    /// `dir/`, `*/dir/`) never matched an absolute path, so it is dropped.
    static func excludes(
        from ignoreMap: IgnoreMap
    ) -> [PathExpression] {
        (ignoreMap.ignoreFiles + ignoreMap.ignoreDirectories).compactMap {
            entry in

            guard entry.hasPrefix("*") else {
                return nil
            }

            let suffix = entry.dropFirst()

            guard !suffix.isEmpty,
                  !suffix.contains("*"),
                  !suffix.contains("/"),
                  !suffix.contains("["),
                  !suffix.contains("]")
            else {
                return nil
            }

            return PathExpression(
                anchor: .root,
                pattern: PathPattern(
                    [
                        .recursive,
                        .componentPattern(entry),
                    ]
                )
            )
        }
    }
}
