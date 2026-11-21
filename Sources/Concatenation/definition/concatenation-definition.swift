import Foundation
import Path
import Selection

/// What to concatenate, independent of the file format that declared it.
///
/// A configuration format (`.conany` through `ConcatenationLegacy`, later
/// `con.frame`) is lowered into this value; execution only ever sees this.
public struct ConcatenationDefinition: Sendable {
    /// The file that declared the definition. Its directory anchors relative
    /// expressions, the local cache and `context_index.txt`.
    public var configuration: URL
    public var outputs: [Output]

    public init(
        configuration: URL,
        outputs: [Output]
    ) {
        self.configuration = configuration.standardizedFileURL
        self.outputs = outputs
    }

    public var anchor: URL {
        configuration
            .deletingLastPathComponent()
            .standardizedFileURL
    }
}

public extension ConcatenationDefinition {
    struct Output: Sendable {
        public var name: String
        public var destination: URL
        /// Scanned relative to the definition's `anchor`.
        public var specification: SelectionScanSpecification
        /// Checked in order; the first rule whose base covers a source decides
        /// how its path is shown. Sources no rule covers show their full path.
        public var presentation: [PresentationRule]
        public var context: ConcatenationContext?

        public init(
            name: String,
            destination: URL,
            specification: SelectionScanSpecification,
            presentation: [PresentationRule] = [],
            context: ConcatenationContext? = nil
        ) {
            self.name = name
            self.destination = destination.standardizedFileURL
            self.specification = specification
            self.presentation = presentation
            self.context = context
        }
    }

    struct PresentationRule: Sendable {
        public enum Style: Sendable {
            /// The source's full file path, as given.
            case unchanged
            case basename
            case path(PathPresentationOptions)
        }

        /// Sources at or below this directory; `nil` covers every source.
        public var base: URL?
        public var style: Style

        public init(
            base: URL?,
            style: Style
        ) {
            self.base = base?.standardizedFileURL
            self.style = style
        }

        func covers(
            _ path: String
        ) -> Bool {
            guard let base else {
                return true
            }

            let basePath = base.path

            return path == basePath
                || path.hasPrefix(basePath + "/")
        }
    }
}

extension ConcatenationDefinition.Output {
    func presentedPath(
        for match: SelectionScanMatch
    ) -> String {
        let path = match.url.path

        guard let rule = presentation.first(
            where: { $0.covers(path) }
        ) else {
            return path
        }

        switch rule.style {
        case .unchanged:
            return path

        case .basename:
            return match.path.basename
                ?? match.url.lastPathComponent

        case .path(let options):
            return match.path.present(
                options
            )
        }
    }
}
