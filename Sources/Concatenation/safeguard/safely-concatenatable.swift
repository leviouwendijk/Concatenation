import Foundation

public protocol SafelyConcatenatable {}

public extension SafelyConcatenatable {
    func tokens(from filename: String) -> [Substring] {
        return filename.split { c in c == "." || c == "-" || c == "_" }
    }

    func isProtectedFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        let lower = name.lowercased()

        if ConSafeguard.protectedExactNames.contains(lower) {
            return true
        }

        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && ConSafeguard.protectedExtensions.contains(ext) {
            return true
        }

        for p in ConSafeguard.protectedPrefixes {
            if lower.hasPrefix(p) || lower.hasSuffix(p) {
                return true
            }
        }

        for token in ConSafeguard.protectedTokens {
            if lower.contains(token) {
                return true
            }
        }

        let toks = tokens(from: lower)
        for t in toks {
            if ConSafeguard.protectedTokens.contains(String(t)) {
                return true
            }
        }

        let comps = url.pathComponents.map { $0.lowercased() }
        if comps.contains(".ssh") || comps.contains("ssh") {
            if lower.contains("authorized_keys") || lower.contains("id_rsa") || lower.contains("known_hosts") {
                return true
            }
            return true
        }

        let justAlphaNum = lower.filter { $0.isLetter || $0.isNumber }
        if justAlphaNum.count >= 40 && justAlphaNum.count == lower.count {
            return true
        }
        return false
    }

    func deepSecretCheck(
        _ url: URL,
        maxPeek: Int = ConSafeguard.deepPeekBytes
    ) -> (matched: Bool, reason: String?) {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let peek = data.prefix(maxPeek)

            if ConSafeguard.treatNullByteAsBinary {
                if peek.contains(0) {
                    let ext = url.pathExtension.lowercased()
                    if ConSafeguard.protectedExtensions.contains(ext) || ext == "p12" || ext == "jks" {
                        return (true, "binary file contains NUL bytes (likely keystore / PKCS12/JKS)")
                    }
                    return (true, "binary file contains NUL bytes")
                }
            }

            var text: String? = nil
            if let s = String(data: peek, encoding: .utf8) {
                text = s.lowercased()
            } else if let s = String(data: peek, encoding: .isoLatin1) {
                text = s.lowercased()
            }

            if let txt = text {
                for marker in ConSafeguard.pemMarkers {
                    if txt.contains(marker) {
                        return (true, "detected PEM/OPENSSH marker '\(marker.trimmingCharacters(in: .whitespaces))'")
                    }
                }

                if txt.contains("-----begin openssh private key-----") {
                    return (true, "detected OpenSSH private key")
                }

                if txt.contains("ssh-rsa") || txt.contains("ssh-ed25519") {
                    return (true, "detected SSH key marker (ssh-rsa / ssh-ed25519)")
                }

                for token in ConSafeguard.privateKeyJsonTokens {
                    if txt.contains(token) {
                        return (true, "detected JSON private-key-like token '\(token)'")
                    }
                }

                // additional heuristics: pkcs8 base64 blocks (BEGIN ... PRIVATE KEY) already covered by pemMarkers
            }

            if let s = String(data: peek, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let first = s.components(separatedBy: .whitespacesAndNewlines).first ?? ""
                let base64Chars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
                let isBase64Like = first.count >= 80 && first.rangeOfCharacter(from: base64Chars.inverted) == nil
                if isBase64Like {
                    return (true, "detected long base64-like token (possible key material)")
                }
            }

            return (false, nil)
        } catch {
            return (false, nil)
        }
    }

    func printProtectionNotifier(file: String, reason: String) {
        // let override = "Use --allow-secrets to override"
        let strFile = "file:     \(file)"
        let strReason = "reason:   \(reason)"
        print("Excluding protected file:")
        print(strFile.indent())
        print(strReason.indent())
        print()
    }
}
