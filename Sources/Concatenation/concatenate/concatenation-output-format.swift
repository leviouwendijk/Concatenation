import Arguments

public enum ConcatenationOutputFormat: String, CaseIterable, Sendable, Codable, Equatable, ArgumentValue {
    case text
    case xml
}
