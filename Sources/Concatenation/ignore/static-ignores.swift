import Foundation

public struct StaticIgnoreDefaults {
    public static let configs = [
        ".conignore",
        ".conselect",
        ".configure",
        ".conany"
    ]

    public static let common = [
        "concatenation.txt",
        "conselection.txt",
        "configure.txt"
    ]

    public static let other = [
        "concatenation",
        "tree"
    ]

    public static let allPatterns = configs + common + other
}
