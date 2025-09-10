import Foundation

public struct ConSafeguard {
    public static let protectedExtensions: Set<String> = [
        "pem","key","p12","jks","crt","cer","der","pkcs8",

        "conf","env","ini","cfg","yaml","yml"
    ]

    public static let protectedExactNames: Set<String> = [
        ".env", ".env.local", ".env.production", ".env.development",
        "authorized_keys", "known_hosts", "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519",
        "id_rsa.pub", "id_dsa.pub", "id_ed25519.pub",
        "credentials", "aws_credentials", "aws-credentials", "bunq.conf"
    ]

    public static let protectedPrefixes: [String] = [
        "id_", "ssh_", "public", "secret", "credentials", "aws", "amazon"
    ]

    public static let protectedTokens: Set<String> = [
        "public", "secret", "credentials", "passwd", "password", "key", "cert", "pem", "ssh", "aws"
    ]

    public static let deepPeekBytes: Int = 8_192

    public static let pemMarkers: [String] = [
        "-----begin ",                     // generic PEM
        "-----begin rsa private key",      // RSA
        "-----begin rsa public key",
        "-----begin openssh private key",  // OpenSSH new format
        "-----begin private key",          // PKCS#8
        "-----begin encrypted",            // encrypted PEM
        "-----begin certificate"           // certs
    ].map { $0.lowercased() }

    public static let privateKeyJsonTokens: [String] = ([
        "\"private_key\"", "\"private_key_id\"", "\"type\": \"service_account\"",
        "\"api_key\"", "\"apikey\"", "\"access_token\"", "\"refresh_token\"", "\"client_secret\"",
        "\"token\"", "\"session_token\"",
        "\"installation_context\"", "\"private_key_client\"", "\"public_key_client\"", "\"public_key_server\"",
        "\"session_context\""
    ]).map { $0.lowercased() }

    public static let treatNullByteAsBinary: Bool = true

    public static let alphaNumKeyMinLength: Int = 40
}
