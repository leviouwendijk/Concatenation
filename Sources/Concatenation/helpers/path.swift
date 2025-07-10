import Foundation
import plate

public func normalize(path: String) -> URL {
    return URL(fileURLWithPath: path)
    .standardizedFileURL
}

public func resolveSymlink(at url: URL) throws -> URL {
    let standardized = url.standardizedFileURL
    let resourceValues = try standardized.resourceValues(forKeys: [.isSymbolicLinkKey])
    if resourceValues.isSymbolicLink == true {
        do {
            let destPath = try FileManager.default.destinationOfSymbolicLink(atPath: standardized.path)
            let destURL = URL(fileURLWithPath: destPath, relativeTo: standardized.deletingLastPathComponent())
            return destURL.standardizedFileURL
        } catch {
            throw ConcatError.pathResolutionFailed(url: url)
        }
    }
    return standardized
}
