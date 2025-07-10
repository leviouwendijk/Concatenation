import Foundation

public enum ConIgnoreError: Error, Sendable {
    case alreadyExists
}

public struct ConignoreInitializer {
    public let path: URL

    public init(
        at directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) {
        self.path = directory.appendingPathComponent(".conignore")
    }

    public func initialize(
        template: ConignoreTemplate = .clean,
        force: Bool = false,
        transfer: Bool = false
    ) throws {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: path.path)
        if exists && !force {
            throw ConIgnoreError.alreadyExists
        }

        let existingMap: IgnoreMap? = (exists && transfer) ? try ConignoreParser.parseFile(at: path) : nil

        let content = makeConignoreFileWithMergedDefaults(
            template: template,
            mergingWith: existingMap
        )
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    public func printGuide() {
        print(conignoreGuide())
    }
}
