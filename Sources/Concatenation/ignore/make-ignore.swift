import Foundation

public enum ConignoreTemplate {
    case clean
    case comments
}

public func makeCommentSection(comments: [String]) -> String {
    var section = ""
    for comment in comments {
        section += "# \(comment)\n"
    }
    section += "\n"
    return section
}

public func makeIgnoreFilesSection(files: [String], comment: String? = nil) -> String {
    var section = "[IgnoreFiles]\n"
    if let comment = comment {
        section += "# \(comment)\n"
    }
    section += files.isEmpty ? "# No files to ignore\n" : files.joined(separator: "\n")
    section += "\n\n"
    return section
}

public func makeIgnoreDirectoriesSection(directories: [String], comment: String? = nil) -> String {
    var section = "[IgnoreDirectories]\n"
    if let comment = comment {
        section += "# \(comment)\n"
    }
    section += directories.isEmpty ? "# No directories to ignore\n" : directories.joined(separator: "\n")
    section += "\n\n"
    return section
}

public func makeObscureSection(obscurations: [String: String], comment: String? = nil) -> String {
    var section = "[Obscure]\n"
    if let comment = comment {
        section += "# \(comment)\n"
    }
    if obscurations.isEmpty {
        section += "# No values to obscure\n"
    } else {
        for (value, method) in obscurations {
            section += "\(value) : \(method)\n"
        }
    }
    section += "\n"
    return section
}

public func makeConignoreFile(
    topLevelComments: [String],
    files: [String],
    directories: [String],
    obscurations: [String: String],
    fileComment: String? = "List files to exclude from concatenation.",
    dirComment: String? = "List directories to exclude from concatenation.",
    obscureComment: String? = "Specify values to obscure and their methods."
) -> String {
    let commentsSection = makeCommentSection(comments: topLevelComments)
    let filesSection = makeIgnoreFilesSection(files: files, comment: fileComment)
    let directoriesSection = makeIgnoreDirectoriesSection(directories: directories, comment: dirComment)
    let obscureSection = makeObscureSection(obscurations: obscurations, comment: obscureComment)
    
    return commentsSection + filesSection + directoriesSection + obscureSection
}

public func makeConignoreFileWithMergedDefaults(
    template: ConignoreTemplate,
    mergingWith existing: IgnoreMap? = nil
) -> String {
    let baseFiles   = ["*.env", "*.log", "*.pem", "*.pub", "*.conf", "secrets.txt"]
    let baseDirs    = ["env/", "build/", ".build/", "*/backups/"]
    let baseObscure = ["apiKey":"verbose"]

    let (topComments, fileC, dirC, obsC): ([String], String?, String?, String?) = {
        switch template {
        case .clean:
            return ([], nil, nil, nil)
        case .comments:
            return (
                [ ".conignore configuration file",
                  "Use [IgnoreFiles] and [IgnoreDirectories] to skip items,",
                  "and [Obscure] to mask sensitive values." ],
                "List files to exclude (one per line).",
                "List directories to exclude (one per line).",
                "Specify value : method (redact, preserve, verbose)."
            )
        }
    }()

    let mergedFiles = existing?.ignoreFiles.removingDuplicates() ?? baseFiles
    let mergedDirs  = existing?.ignoreDirectories.removingDuplicates() ?? baseDirs
    let mergedObs   = existing?.obscureValues.merging(baseObscure) { _, new in new } ?? baseObscure

    var out = ""
    out += makeCommentSection(comments: topComments)
    out += makeIgnoreFilesSection(files: mergedFiles, comment: fileC)
    out += makeIgnoreDirectoriesSection(directories: mergedDirs, comment: dirC)
    out += makeObscureSection(obscurations: mergedObs, comment: obsC)
    return out
}
