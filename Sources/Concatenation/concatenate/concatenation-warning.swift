import Foundation

/// What the safeguard detected in a source it refused to include.
public enum ConcatenationSecretSignal: Sendable, Codable, Equatable, Hashable {
    /// The file name or extension matches a protected pattern.
    case protectedFileName
    /// The first bytes contain NUL; `keystoreExtension` when the extension
    /// also suggests a keystore (PKCS12, JKS, …).
    case nullBytes(keystoreExtension: Bool)
    /// A PEM or OpenSSH armor line, such as `-----BEGIN PRIVATE KEY-----`.
    case pemMarker(String)
    case openSSHPrivateKey
    /// `ssh-rsa` or `ssh-ed25519` key material.
    case sshKeyMarker
    /// A JSON key that usually holds a secret, such as `"private_key"`.
    case secretJSONKey(String)
    case pemWithSecretJSON
    /// A leading token of 80+ base64 characters.
    case base64Token
}

public enum ConcatenationWarning: Sendable, Codable, Equatable {
    /// The source was left out by the secret safeguard.
    case blocked(
        file: URL,
        signal: ConcatenationSecretSignal
    )
    /// The source was cut at the per-file line limit.
    case truncated(
        file: URL,
        keptLineCount: Int,
        totalLineCount: Int
    )

    public static func blocked(
        _ file: URL,
        signal: ConcatenationSecretSignal
    ) -> Self {
        .blocked(
            file: file.standardizedFileURL,
            signal: signal
        )
    }

    public static func truncated(
        _ file: URL,
        keptLineCount: Int,
        totalLineCount: Int
    ) -> Self {
        .truncated(
            file: file.standardizedFileURL,
            keptLineCount: keptLineCount,
            totalLineCount: totalLineCount
        )
    }

    public var file: URL {
        switch self {
        case .blocked(let file, _),
             .truncated(let file, _, _):
            return file
        }
    }

    public var isBlocked: Bool {
        if case .blocked = self {
            return true
        }
        return false
    }
}
