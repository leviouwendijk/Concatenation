import Concatenation
import Foundation

public struct ConcatenationServiceEndpoint:
    Sendable,
    Codable,
    Hashable
{
    public let url: URL

    public init(
        url: URL
    ) {
        self.url = url.standardizedFileURL
    }

    /// `service.sock` under the cache root (`~/.cache/concatenation`).
    public static var `default`: Self {
        .init(
            url: ConcatenationCacheRoot.default.serviceSocket
        )
    }

    public var path: String {
        url.path
    }
}
