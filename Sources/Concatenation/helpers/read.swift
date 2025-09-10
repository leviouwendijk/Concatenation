import Foundation

// public func readLines(from url: URL) throws -> [String] {
//     let raw = try String(contentsOf: url, encoding: .utf8)
//     return raw.components(separatedBy: .newlines)
// }

public func readLines(from url: URL) throws -> [String] {
    do {
        let raw = try String(contentsOf: url, encoding: .utf8)
        return raw.components(separatedBy: .newlines)
    } catch {
        do {
            let data = try Data(contentsOf: url)
            if let s = String(data: data, encoding: .utf8) {
                return s.components(separatedBy: .newlines)
            }
            if let s = String(data: data, encoding: .utf16) {
                return s.components(separatedBy: .newlines)
            }
            if let s = String(data: data, encoding: .isoLatin1) {
                return s.components(separatedBy: .newlines)
            }

            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? -1
            let underlying = NSError(
                domain: NSCocoaErrorDomain,
                code: 259,
                userInfo: [NSLocalizedDescriptionKey: "Could not decode file as text (utf8/utf16/isoLatin1). size=\(size) bytes"]
            )
            throw ConcatError.fileReadFailed(url: url, stage: "decode-fallback", underlying: underlying)
        } catch let inner where inner is ConcatError {
            throw inner
        } catch {
            throw ConcatError.fileReadFailed(url: url, stage: "read-data", underlying: error)
        }
    }
}

public func processBlankLines(_ lines: [String], trim: Bool) -> ([String], (header: String, footer: String)) {
    guard trim else {
        return (lines, ("", ""))
    }
    let arr = lines
    var lead = 0, trail = 0

    while lead < arr.count, arr[lead].trimmingCharacters(in: .whitespaces).isEmpty {
        lead += 1
    }
    while trail < arr.count - lead,
          arr[arr.count - 1 - trail].trimmingCharacters(in: .whitespaces).isEmpty {
        trail += 1
    }

    let header = lead > 0 ? "(!): \(lead) blank lines\n" : ""
    let footer = trail > 0 ? "\n(!): \(trail) blank lines\n" : ""
    let trimmed = Array(arr.dropFirst(lead).dropLast(trail))
    return (trimmed, (header, footer))
}
