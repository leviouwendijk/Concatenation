import Foundation

public struct StaticIgnoreDefaults {
    public static let staticIgnore = [
        ".conignore",
        ".conselect",
        ".configure",
        ".conany"
    ]

    public static let backwardsCompatible = [
        "concatenation.txt",
        "conselection.txt",
        "configure.txt"
    ]

    public static let newIgnore = [
        "concatenation",
        "tree"
    ]

    public static let allPatterns = staticIgnore + backwardsCompatible + newIgnore
}
