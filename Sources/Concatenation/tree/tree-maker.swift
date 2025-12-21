import Foundation
import Clipboard

public struct FileTreeMaker {
    private let inputPaths: [URL]
    private let root: URL
    private let removeTrailingSlash: Bool
    private let copyToClipboard: Bool

    public init(
        files: [URL],
        rootPath: String,
        removeTrailingSlash: Bool = false,
        copyToClipboard: Bool = false
    ) {
        self.inputPaths           = files
        self.root                 = URL(fileURLWithPath: rootPath)
        self.removeTrailingSlash  = removeTrailingSlash
        self.copyToClipboard      = copyToClipboard
    }

    public func generate() -> String {
        let rootStd = root.standardizedFileURL
        let rootPrefix = rootStd.path.hasSuffix("/") ? rootStd.path : rootStd.path + "/"

        let rels = inputPaths.map { url -> String in
            let p = url.standardizedFileURL.path
            if p.hasPrefix(rootPrefix) {
                return String(p.dropFirst(rootPrefix.count))
            } else {
                // Fallback: keep absolute path if it isn't under root
                return p
            }
        }.sorted()

        var tree = "\(root.lastPathComponent)\(removeTrailingSlash ? "" : "/")\n"
        var stack: [String] = []

        for rel in rels {
            let comps = rel.split(separator: "/").map(String.init)
            guard let filename = comps.last else { continue }
            let dirs = Array(comps.dropLast())

            // 1) find length of common prefix with current stack
            var common = 0
            while common < min(stack.count, dirs.count) && stack[common] == dirs[common] {
                common += 1
            }

            // 2) pop to the common prefix
            while stack.count > common { stack.removeLast() }

            // 3) push remaining dirs
            while stack.count < dirs.count {
                let next = dirs[stack.count]
                stack.append(next)
                tree += String(repeating: "    ", count: stack.count - 1)
                     + "└── \(next)\(removeTrailingSlash ? "" : "/")\n"
            }

            // 4) print file
            tree += String(repeating: "    ", count: stack.count)
                 + "└── \(filename)\n"
        }

        if copyToClipboard { tree.clipboard() }
        return tree
    }
}
