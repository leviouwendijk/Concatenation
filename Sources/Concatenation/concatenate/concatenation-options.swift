import Writers

public struct DelimiterOptions: Sendable {
    public let style: DelimiterStyle
    public let closure: Bool

    public init(
        style: DelimiterStyle = .boxed,
        closure: Bool = false
    ) {
        self.style = style
        self.closure = closure
    }
}

public struct LineOptions: Sendable {
    public let filemax: Int?
    public let trimblanks: Bool
    public let numbers: Bool

    public init(
        filemax: Int? = 10_000,
        trimblanks: Bool = true,
        numbers: Bool = false
    ) {
        self.filemax = filemax
        self.trimblanks = trimblanks
        self.numbers = numbers
    }
}

public struct OutputOptions: Sendable {
    public let raw: Bool
    public let relativepaths: Bool
    public let modifiedstamp: Bool
    public let obscurations: [String: String]

    public init(
        raw: Bool = false,
        relativepaths: Bool = true,
        modifiedstamp: Bool = false,
        obscurations: [String: String] = [:]
    ) {
        self.raw = raw
        self.relativepaths = relativepaths
        self.modifiedstamp = modifiedstamp
        self.obscurations = obscurations
    }
}

public struct ConcatenationRenderOptions: Sendable {
    public let delimiter: DelimiterOptions
    public let line: LineOptions
    public let output: OutputOptions

    public init(
        delimiter: DelimiterOptions = .init(),
        line: LineOptions = .init(),
        output: OutputOptions = .init()
    ) {
        self.delimiter = delimiter
        self.line = line
        self.output = output
    }
}
