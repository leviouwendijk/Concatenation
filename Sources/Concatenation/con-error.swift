import Foundation

public enum ConcatError: Error, LocalizedError {
    case fileNotReadable(url: URL)
    case pathResolutionFailed(url: URL)
    case patternCompilationFailed(pattern: String, underlying: Error)
    case ignoreMapLoadFailed(url: URL, underlying: Error)
    case fileReadFailed(url: URL, stage: String, underlying: Error)    
    case fileProcessingFailed(url: URL, stage: String, underlying: Error) 
    case fileBlockedByPolicy(url: URL, reason: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotReadable(let url):
            return "File not readable: \(url.path)"
        case .pathResolutionFailed(let url):
            return "Failed to resolve symlink/path: \(url.path)"
        case .patternCompilationFailed(let pattern, let underlying):
            return "Pattern compilation failed for '\(pattern)': \(underlying.localizedDescription)"
        case .ignoreMapLoadFailed(let url, let underlying):
            return "Failed loading .conignore at \(url.path): \(underlying.localizedDescription)"
        case .fileReadFailed(let url, let stage, let underlying):
            return "Failed to read file '\(url.path)' during '\(stage)': \(underlying.localizedDescription)"
        case .fileProcessingFailed(let url, let stage, let underlying):
            return "Error processing file '\(url.path)' at '\(stage)': \(underlying.localizedDescription)"
        case .fileBlockedByPolicy(let url, let reason):
            return "File blocked by safeguard policy: \(url.path) — \(reason)"
        }
    }
}
