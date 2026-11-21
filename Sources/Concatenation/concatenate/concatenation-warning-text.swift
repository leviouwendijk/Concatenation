/// Text for warnings, shared by the document renderers (which embed warnings
/// and truncation notes in the output) and by `con`'s terminal presentation.
public enum ConcatenationWarningText {
    public static func kind(
        _ warning: ConcatenationWarning
    ) -> String {
        switch warning {
        case .blocked:
            return "blockedByPolicy"
        case .truncated:
            return "truncated"
        }
    }

    public static func message(
        _ warning: ConcatenationWarning
    ) -> String {
        switch warning {
        case .blocked(_, let signal):
            return reason(signal)
        case .truncated(_, let kept, let total):
            return truncation(
                keptLineCount: kept,
                totalLineCount: total
            )
        }
    }

    public static func truncation(
        keptLineCount: Int,
        totalLineCount: Int
    ) -> String {
        "(!): truncated — file exceeded max line limit (\(keptLineCount)/\(totalLineCount) lines)"
    }

    public static func reason(
        _ signal: ConcatenationSecretSignal
    ) -> String {
        switch signal {
        case .protectedFileName:
            return "Detected filename/extension matching secret patterns."
        case .nullBytes(let keystoreExtension):
            return keystoreExtension
                ? "binary file contains NUL bytes (likely keystore / PKCS12/JKS)"
                : "binary file contains NUL bytes"
        case .pemMarker(let marker):
            return "detected PEM/OPENSSH marker '\(marker)'"
        case .openSSHPrivateKey:
            return "detected OpenSSH private key"
        case .sshKeyMarker:
            return "detected SSH key marker (ssh-rsa / ssh-ed25519)"
        case .secretJSONKey(let key):
            return "detected JSON secret-like key \(key)"
        case .pemWithSecretJSON:
            return "detected PEM + JSON secret indicators"
        case .base64Token:
            return "detected long base64-like token (possible key material)"
        }
    }
}
