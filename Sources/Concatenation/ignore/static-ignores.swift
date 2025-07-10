import Foundation

public struct StaticIgnoreDefaults {
    public static let staticIgnore = [
        ".conignore"
    ]

    public static let backwardsCompatible = [
        "concatenation.txt",
        "concatenation-filetree.txt"
    ]

    public static let newIgnore = [
        "concatenation",
        "tree"
    ]

    public static let allPatterns = staticIgnore + backwardsCompatible + newIgnore
}
