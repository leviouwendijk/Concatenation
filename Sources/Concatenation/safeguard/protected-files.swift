import Foundation

public struct ConSafeguard {
    public static let protectedExtensions: Set<String> = [
        "pem", "key", "p12", "jks", "crt", "cer", "der", "pkcs8"
    ]

    public static let protectedExactNames: Set<String> = [
        ".env", ".env.local", ".env.production", ".env.development",
        "authorized_keys", "known_hosts", "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519",
        "id_rsa.pub", "id_dsa.pub", "id_ed25519.pub",
        "credentials", "aws_credentials", "aws-credentials"
    ]

    public static let protectedPrefixes: [String] = [
        "id_", "ssh_", "public", "secret", "credentials", "aws", "amazon"
    ]

    public static let protectedTokens: Set<String> = [
        "public", "secret", "credentials", "passwd", "password", "key", "cert", "pem", "ssh", "aws"
    ]

    public static let deepPeekBytes: Int = 2_048

    public static let pemMarkers: [String] = [
        "-----begin ",                     // generic PEM
        "-----begin rsa private key",      // RSA
        "-----begin rsa public key",
        "-----begin openssh private key",  // OpenSSH new format
        "-----begin private key",          // PKCS#8
        "-----begin encrypted",            // encrypted PEM
        "-----begin certificate"           // certs
    ].map { $0.lowercased() }

    public static let privateKeyJsonTokens: [String] = [
        "\"private_key\"", "\"private_key_id\"", "\"client_email\"", "\"type\": \"service_account\""
    ].map { $0.lowercased() }

    public static let treatNullByteAsBinary: Bool = true

    public static let alphaNumKeyMinLength: Int = 40
}
