public enum ConInclude: Sendable, Codable, Equatable {
    case path(String)
    case partition(String)
}

public struct ConIncludeBlock: Sendable, Codable, Equatable {
    public let base: ConInclude?
    public let show: ConPathShowStyle
    public let includes: [String]
    public let selections: [String]

    public init(
        base: ConInclude? = nil,
        show: ConPathShowStyle = .full,
        includes: [String] = [],
        selections: [String] = []
    ) {
        self.base = base
        self.show = show
        self.includes = includes
        self.selections = selections
    }

    public var patterns: [String] {
        includes + selections
    }
}
