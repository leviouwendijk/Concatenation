import Arguments
import ConcatenationServiceTransport

struct ServiceCommand: ArgumentCommand {
    static let name = "service"

    static var defaultChild: ServicePingCommand.Type {
        ServicePingCommand.self
    }

    static var children: [ArgumentCommandType] {
        [
            ServiceHostCommand.self,
            ServicePingCommand.self,
            ServiceStopCommand.self,
        ]
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Interact with the persistent Concatenation corpus service."
            ),
        ]
    }
}

struct ServiceHostCommand: RunnableArgumentCommand {
    static let name = "host"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Run the persistent Concatenation corpus service in the foreground."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let host = ConcatenationServiceHost()

        print(
            "Concatenation service listening at \(host.endpoint.path)"
        )

        try await host.serve()
    }
}

struct ServicePingCommand: RunnableArgumentCommand {
    static let name = "ping"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Check whether the Concatenation corpus service is reachable."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let response = try await ConcatenationServiceClient()
            .ping()

        guard response.isSuccess else {
            throw ConcatenationServiceCLIError.failed(
                response.message
            )
        }

        print(
            response.message ?? "pong"
        )
    }
}

struct ServiceStopCommand: RunnableArgumentCommand {
    static let name = "stop"

    static func components() throws -> [CommandComponentLowerable] {
        [
            about(
                "Gracefully stop the persistent Concatenation corpus service."
            ),
        ]
    }

    static func run(
        _ invocation: ParsedInvocation
    ) async throws {
        let response = try await ConcatenationServiceClient()
            .shutdown()

        guard response.isSuccess else {
            throw ConcatenationServiceCLIError.failed(
                response.message
            )
        }

        print(
            response.message ?? "shutting_down"
        )
    }
}

enum ConcatenationServiceCLIError: Error {
    case failed(String?)
}
