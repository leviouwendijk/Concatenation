import Foundation
import plate

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
        let rootName = root.lastPathComponent
        var tree = "\(rootName)\(removeTrailingSlash ? "" : "/")\n"

        let rels = inputPaths.map { url in
            url.path.replacingOccurrences(of: root.path + "/", with: "")
        }.sorted()

        var stack: [String] = []
            for rel in rels {
                let comps = rel.split(separator: "/").map(String.init)
                let filename = comps.last!
                let dirs = comps.dropLast()

                while stack.count > dirs.count { stack.removeLast() }
                while stack.count < dirs.count {
                    let next = dirs[stack.count]
                    stack.append(next)
                    tree += String(repeating: "    ", count: stack.count - 1)
                    + "└── \(next)\(removeTrailingSlash ? "" : "/")\n"
                }

                tree += String(repeating: "    ", count: stack.count)
                + "└── \(filename)\n"
            }

        if copyToClipboard {
            tree.clipboard()
        }
        return tree
    }
}
