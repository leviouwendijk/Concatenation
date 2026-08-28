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

    public static var `default`: Self {
        let manager = FileManager.default
        let base = manager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? manager.temporaryDirectory

        return .init(
            url: base
                .appendingPathComponent(
                    "Concatenation",
                    isDirectory: true
                )
                .appendingPathComponent(
                    "service.sock",
                    isDirectory: false
                )
        )
    }

    public var path: String {
        url.path
    }
}
