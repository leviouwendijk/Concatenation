import Strings

public enum DelimiterStyle: String, CaseIterable {
    case none
    case comment
    case asterisk
    case classic
    case boxed

    func header(for path: String) -> String {
        switch self {
        case .none:
            return ""
        case .comment:
            return "# \(path)"
        case .asterisk:
            return "* \(path)"
        case .classic:
            return "=== Contents of \(path) ==="
        case .boxed:
            return createBox(for: path)
        }
    }

    func footer(for path: String) -> String {
        switch self {
        case .none:
            return ""
        case .comment, .asterisk:
            return ""
        case .classic:
            return "=== End of \(path) ==="
        case .boxed:
            return createBox(for: "END \(path)")
        }
    }
}
