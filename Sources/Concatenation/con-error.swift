import Foundation

public enum ConcatError: Error {
    case fileNotReadable(url: URL)
    case pathResolutionFailed(url: URL)
    case patternCompilationFailed(pattern: String, underlying: Error)
    case ignoreMapLoadFailed(url: URL, underlying: Error)
}
