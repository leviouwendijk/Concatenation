import Arguments

enum ConcatCommand: ArgumentCommand {
    static let name = "concat"

    static var defaultChild: ConcatRunCommand.Type {
        ConcatRunCommand.self
    }

    static var children: [ArgumentCommandType] {
        [
            ConcatRunCommand.self,
            ConcatAnyCommand.self,
        ]
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Concatenate file contents."),
        ]
    }
}
