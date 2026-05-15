import Arguments
import Concatenation

enum IgnoreCommand: RunnableArgumentCommand {
    static let name = "ignore"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about("Manage the .conignore file."),
            flag(
                "comments",
                help: "Initialize the .conignore file with comments."
            ),
            flag(
                "force",
                help: "Force re-initialization of the .conignore file."
            ),
            flag(
                "transfer",
                help: "Transfer unique entries from the existing .conignore file."
            ),
            flag(
                "help",
                help: "Print a guide on how to use the .conignore file."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let initializer = ConignoreInitializer()

        if try invocation.flag("help") {
            initializer.printGuide()
            return
        }

        let force = try invocation.flag("force")
        let transfer = try invocation.flag("transfer")

        do {
            try initializer.initialize(
                template: try invocation.flag("comments") ? .comments : .clean,
                force: force,
                transfer: transfer
            )

            let message: String
            if force {
                message = transfer
                    ? ".conignore file has been reinitialized with transferred content."
                    : ".conignore file has been reinitialized without transferring content."
            } else {
                message = ".conignore file has been created."
            }

            print(message)
        } catch ConIgnoreError.alreadyExists {
            print(".conignore file already exists. Use --force to reinitialize.")
        }
    }
}
