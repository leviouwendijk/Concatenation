import Foundation
import Path
import PathParsing
import Selection
import SelectionParsing

public struct ConcatenationCorpusDefinition:
    Sendable,
    Codable,
    Equatable
{
    public var specification: SelectionScanSpecification
    public var walk: PathWalkConfiguration

    public init(
        specification: SelectionScanSpecification,
        walk: PathWalkConfiguration = .init()
    ) {
        var walk = walk
        walk.emitDirectories = false
        walk.emitFiles = true

        self.specification = specification
        self.walk = walk
    }

    public init(
        includes: [PathExpression] = [],
        excludes: [PathExpression] = [],
        selections: [PathSelectionExpression] = [],
        walk: PathWalkConfiguration = .init()
    ) {
        self.init(
            specification: .init(
                includes: includes,
                excludes: excludes,
                selections: selections
            ),
            walk: walk
        )
    }

    public var includes: [PathExpression] {
        get {
            specification.includes
        }
        set {
            specification.includes = newValue
        }
    }

    public var excludes: [PathExpression] {
        get {
            specification.excludes
        }
        set {
            specification.excludes = newValue
        }
    }

    public var selections: [PathSelectionExpression] {
        get {
            specification.selections
        }
        set {
            specification.selections = newValue
        }
    }

    public static func parsing(
        includes: [String] = [],
        excludes: [String] = [],
        selections: [String] = [],
        walk: PathWalkConfiguration = .init()
    ) throws -> Self {
        try .init(
            includes: includes.map(
                PathParse.expression
            ),
            excludes: excludes.map(
                PathParse.expression
            ),
            selections: selections.map(
                PathSelectionExpressionParser.parse
            ),
            walk: walk
        )
    }

    public func resolve(
        relativeTo directory: URL
    ) throws -> ConcatenationCorpusResolution {
        let anchor = directory.standardizedFileURL
        let result = try SelectionScan.scan(
            specification,
            relativeTo: .directoryURL(
                anchor
            ),
            configuration: walk
        )

        return .init(
            definition: self,
            anchor: anchor,
            sources: result.matches.map { match in
                ConcatenationSource(
                    file: match.url,
                    selections: match.contentSelections
                )
            },
            warnings: result.warnings
        )
    }

    public func applying(
        _ patch: ConcatenationCorpusDefinitionPatch
    ) -> Self {
        .init(
            includes: corpusDefinitionPatched(
                current: includes,
                removing: patch.removeIncludes,
                adding: patch.addIncludes
            ),
            excludes: corpusDefinitionPatched(
                current: excludes,
                removing: patch.removeExcludes,
                adding: patch.addExcludes
            ),
            selections: corpusDefinitionPatched(
                current: selections,
                removing: patch.removeSelections,
                adding: patch.addSelections
            ),
            walk: patch.walk ?? walk
        )
    }
}

public struct ConcatenationCorpusDefinitionPatch:
    Sendable,
    Codable,
    Equatable
{
    public var addIncludes: [PathExpression]
    public var removeIncludes: [PathExpression]
    public var addExcludes: [PathExpression]
    public var removeExcludes: [PathExpression]
    public var addSelections: [PathSelectionExpression]
    public var removeSelections: [PathSelectionExpression]
    public var walk: PathWalkConfiguration?

    public init(
        addIncludes: [PathExpression] = [],
        removeIncludes: [PathExpression] = [],
        addExcludes: [PathExpression] = [],
        removeExcludes: [PathExpression] = [],
        addSelections: [PathSelectionExpression] = [],
        removeSelections: [PathSelectionExpression] = [],
        walk: PathWalkConfiguration? = nil
    ) {
        self.addIncludes = addIncludes
        self.removeIncludes = removeIncludes
        self.addExcludes = addExcludes
        self.removeExcludes = removeExcludes
        self.addSelections = addSelections
        self.removeSelections = removeSelections
        self.walk = walk
    }
}

public struct ConcatenationCorpusResolution:
    Sendable
{
    public let definition: ConcatenationCorpusDefinition
    public let anchor: URL
    public let sources: [ConcatenationSource]
    public let warnings: [SelectionScanWarning]

    public init(
        definition: ConcatenationCorpusDefinition,
        anchor: URL,
        sources: [ConcatenationSource],
        warnings: [SelectionScanWarning] = []
    ) {
        self.definition = definition
        self.anchor = anchor.standardizedFileURL
        self.sources = sources
        self.warnings = warnings
    }

    public var plan: ConcatenationPlan {
        .init(
            context: nil,
            sources: sources,
            options: .init()
        )
    }
}

private func corpusDefinitionPatched<Value: Equatable>(
    current: [Value],
    removing: [Value],
    adding: [Value]
) -> [Value] {
    var values = current.filter { value in
        !removing.contains(
            value
        )
    }

    for value in adding
        where !values.contains(value)
    {
        values.append(
            value
        )
    }

    return values
}
