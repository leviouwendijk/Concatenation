import Darwin
import Foundation

internal enum ConcatenationUnixSocket {
    static let maximumMessageSize = 64 * 1024 * 1024

    static func listen(
        at endpoint: ConcatenationServiceEndpoint
    ) throws -> Int32 {
        try prepareEndpoint(
            endpoint
        )

        let descriptor = Darwin.socket(
            AF_UNIX,
            SOCK_STREAM,
            0
        )

        guard descriptor >= 0 else {
            throw systemError(
                "socket"
            )
        }

        var boundEndpoint = false

        do {
            var address = try address(
                endpoint.path
            )

            let bindResult = withUnsafePointer(
                to: &address
            ) { pointer in
                pointer.withMemoryRebound(
                    to: sockaddr.self,
                    capacity: 1
                ) { socketAddress in
                    Darwin.bind(
                        descriptor,
                        socketAddress,
                        socklen_t(
                            MemoryLayout<sockaddr_un>.size
                        )
                    )
                }
            }

            guard bindResult == 0 else {
                throw systemError(
                    "bind"
                )
            }

            boundEndpoint = true

            guard Darwin.listen(
                descriptor,
                16
            ) == 0 else {
                throw systemError(
                    "listen"
                )
            }

            try FileManager.default.setAttributes(
                [
                    .posixPermissions: 0o600,
                ],
                ofItemAtPath: endpoint.path
            )

            return descriptor
        } catch {
            Darwin.close(
                descriptor
            )

            if boundEndpoint {
                try? removeSocket(
                    endpoint
                )
            }

            throw error
        }
    }

    static func connect(
        to endpoint: ConcatenationServiceEndpoint
    ) throws -> Int32 {
        let descriptor = Darwin.socket(
            AF_UNIX,
            SOCK_STREAM,
            0
        )

        guard descriptor >= 0 else {
            throw systemError(
                "socket"
            )
        }

        do {
            var address = try address(
                endpoint.path
            )

            let result = withUnsafePointer(
                to: &address
            ) { pointer in
                pointer.withMemoryRebound(
                    to: sockaddr.self,
                    capacity: 1
                ) { socketAddress in
                    Darwin.connect(
                        descriptor,
                        socketAddress,
                        socklen_t(
                            MemoryLayout<sockaddr_un>.size
                        )
                    )
                }
            }

            guard result == 0 else {
                throw systemError(
                    "connect"
                )
            }

            return descriptor
        } catch {
            Darwin.close(
                descriptor
            )
            throw error
        }
    }

    static func accept(
        _ listener: Int32
    ) throws -> Int32 {
        let descriptor = Darwin.accept(
            listener,
            nil,
            nil
        )

        guard descriptor >= 0 else {
            throw systemError(
                "accept"
            )
        }

        return descriptor
    }

    static func send<Message: Encodable>(
        _ message: Message,
        to descriptor: Int32
    ) throws {
        let payload = try JSONEncoder().encode(
            message
        )

        guard payload.count <= maximumMessageSize else {
            throw ConcatenationServiceTransportError
                .messageTooLarge(
                    payload.count
                )
        }

        var length = UInt64(
            payload.count
        ).bigEndian

        let header = withUnsafeBytes(
            of: &length
        ) {
            Data(
                $0
            )
        }

        try writeAll(
            header,
            to: descriptor
        )
        try writeAll(
            payload,
            to: descriptor
        )
    }

    static func receive<Message: Decodable>(
        _ type: Message.Type,
        from descriptor: Int32
    ) throws -> Message {
        let header = try readExactly(
            MemoryLayout<UInt64>.size,
            from: descriptor
        )

        var encodedLength: UInt64 = 0

        _ = withUnsafeMutableBytes(
            of: &encodedLength
        ) { destination in
            header.copyBytes(
                to: destination
            )
        }

        let length = UInt64(
            bigEndian: encodedLength
        )

        guard length <= UInt64(maximumMessageSize),
              length <= UInt64(Int.max)
        else {
            throw ConcatenationServiceTransportError
                .messageTooLarge(
                    Int(
                        min(
                            length,
                            UInt64(Int.max)
                        )
                    )
                )
        }

        let payload = try readExactly(
            Int(length),
            from: descriptor
        )

        return try JSONDecoder().decode(
            type,
            from: payload
        )
    }

    static func close(
        _ descriptor: Int32
    ) {
        Darwin.close(
            descriptor
        )
    }

    static func removeSocket(
        _ endpoint: ConcatenationServiceEndpoint
    ) throws {
        let manager = FileManager.default

        guard manager.fileExists(
            atPath: endpoint.path
        ) else {
            return
        }

        let attributes = try manager.attributesOfItem(
            atPath: endpoint.path
        )

        guard attributes[.type] as? FileAttributeType
                == .typeSocket
        else {
            throw ConcatenationServiceTransportError
                .endpointOccupied(
                    endpoint.url
                )
        }

        try manager.removeItem(
            at: endpoint.url
        )
    }
}

private extension ConcatenationUnixSocket {
    static func prepareEndpoint(
        _ endpoint: ConcatenationServiceEndpoint
    ) throws {
        let manager = FileManager.default
        let parent = endpoint.url
            .deletingLastPathComponent()

        try manager.createDirectory(
            at: parent,
            withIntermediateDirectories: true,
            attributes: [
                .posixPermissions: 0o700,
            ]
        )

        guard manager.fileExists(
            atPath: endpoint.path
        ) else {
            return
        }

        let attributes = try manager.attributesOfItem(
            atPath: endpoint.path
        )

        guard attributes[.type] as? FileAttributeType
                == .typeSocket
        else {
            throw ConcatenationServiceTransportError
                .endpointOccupied(
                    endpoint.url
                )
        }

        if try isEndpointActive(
            endpoint
        ) {
            throw ConcatenationServiceTransportError
                .endpointActive(
                    endpoint.url
                )
        }

        try manager.removeItem(
            at: endpoint.url
        )
    }

    static func isEndpointActive(
        _ endpoint: ConcatenationServiceEndpoint
    ) throws -> Bool {
        do {
            let descriptor = try connect(
                to: endpoint
            )

            close(
                descriptor
            )

            return true
        } catch let error as ConcatenationServiceTransportError {
            switch error {
            case .system(let operation, let code)
                where operation == "connect"
                    && (
                        code == ECONNREFUSED
                            || code == ENOENT
                    ):
                return false

            default:
                throw error
            }
        }
    }

    static func address(
        _ path: String
    ) throws -> sockaddr_un {
        var address = sockaddr_un()
        let bytes = path.utf8CString
        let capacity = MemoryLayout.size(
            ofValue: address.sun_path
        )

        guard bytes.count <= capacity else {
            throw ConcatenationServiceTransportError
                .endpointPathTooLong(
                    bytes.count
                )
        }

        address.sun_family = sa_family_t(
            AF_UNIX
        )
        address.sun_len = UInt8(
            MemoryLayout<sockaddr_un>.size
        )

        withUnsafeMutablePointer(
            to: &address.sun_path
        ) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: capacity
            ) { destination in
                bytes.withUnsafeBufferPointer { source in
                    guard let base = source.baseAddress else {
                        return
                    }

                    destination.initialize(
                        from: base,
                        count: bytes.count
                    )
                }
            }
        }

        return address
    }

    static func readExactly(
        _ count: Int,
        from descriptor: Int32
    ) throws -> Data {
        guard count > 0 else {
            return Data()
        }

        var data = Data(
            count: count
        )
        var offset = 0

        while offset < count {
            let readCount = data.withUnsafeMutableBytes { bytes in
                Darwin.read(
                    descriptor,
                    bytes.baseAddress!.advanced(
                        by: offset
                    ),
                    count - offset
                )
            }

            if readCount == 0 {
                throw ConcatenationServiceTransportError
                    .connectionClosed
            }

            guard readCount > 0 else {
                if errno == EINTR {
                    continue
                }

                throw systemError(
                    "read"
                )
            }

            offset += readCount
        }

        return data
    }

    static func writeAll(
        _ data: Data,
        to descriptor: Int32
    ) throws {
        var offset = 0

        while offset < data.count {
            let written = data.withUnsafeBytes { bytes in
                Darwin.write(
                    descriptor,
                    bytes.baseAddress!.advanced(
                        by: offset
                    ),
                    data.count - offset
                )
            }

            if written < 0 {
                if errno == EINTR {
                    continue
                }

                throw systemError(
                    "write"
                )
            }

            guard written > 0 else {
                throw ConcatenationServiceTransportError
                    .connectionClosed
            }

            offset += written
        }
    }

    static func systemError(
        _ operation: String
    ) -> ConcatenationServiceTransportError {
        .system(
            operation: operation,
            code: errno
        )
    }
}
