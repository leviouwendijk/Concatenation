import Foundation

public func obscureValue(_ value: String, method: String) -> String {
    switch method.lowercased() {
    case "preserve":
        return String(value.map { $0.isNumber ? "0" : $0.isLetter ? "a" : $0 })
    case "verbose":
        if value.allSatisfy(\.isNumber) { return "[INT]" }
        if value.allSatisfy(\.isLetter) { return "[STRING]" }
        return "[OBSCURED]"
    case "redact":
        fallthrough
    default:
        return "[REDACTED]"
    }
}

