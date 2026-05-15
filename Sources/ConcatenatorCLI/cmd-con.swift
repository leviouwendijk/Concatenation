import Arguments

enum ConCommand: ArgumentCommand {
    static let name = "con"

    static var defaultChild: ConcatCommand.Type {
        ConcatCommand.self
    }

    static var children: [ArgumentCommandType] {
        [
            ConcatCommand.self,
            TreeCommand.self,
            IgnoreCommand.self,
        ]
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("A tool to concatenate file contents or generate a file tree."),
        ]
    }
}
