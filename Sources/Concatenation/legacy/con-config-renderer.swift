public enum ConConfigRenderer {
    public static func render(
        _ config: ConAnyConfig
    ) -> String {
        config.renderables
            .map(renderRenderable)
            .joined(separator: "\n\n")
    }
}

private extension ConConfigRenderer {
    static func renderRenderable(
        _ renderable: ConAnyRenderableObject
    ) -> String {
        var lines: [String] = []

        lines.append("file(\(quoted(renderable.output))) {")

        if let context = renderable.context {
            lines.append(
                contentsOf: renderContext(
                    context
                ).map {
                    "    \($0)"
                }
            )

            if !renderable.includeBlocks.isEmpty || !renderable.exclude.isEmpty {
                lines.append("")
            }
        }

        for (index, block) in renderable.includeBlocks.enumerated() {
            lines.append(
                contentsOf: renderIncludeBlock(
                    block
                ).map {
                    "    \($0)"
                }
            )

            if index < renderable.includeBlocks.count - 1 || !renderable.exclude.isEmpty {
                lines.append("")
            }
        }

        if !renderable.exclude.isEmpty {
            lines.append("    exclude {")
            for pattern in renderable.exclude {
                lines.append("        \(quoted(pattern))")
            }
            lines.append("    }")
        }

        lines.append("}")

        return lines.joined(separator: "\n")
    }

    static func renderContext(
        _ context: ConcatenationContext
    ) -> [String] {
        var lines: [String] = []

        lines.append("context {")

        if let title = context.title {
            lines.append("    title = \(quoted(title))")
        }

        if let details = context.details {
            if context.title != nil {
                lines.append("")
            }

            lines.append("    details = \"\"\"")
            for line in details.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("    \(line)")
            }
            lines.append("    \"\"\"")
        }

        if let dependencies = context.dependencies,
           !dependencies.isEmpty {
            if context.title != nil || context.details != nil {
                lines.append("")
            }

            lines.append("    dependencies {")
            for dependency in dependencies {
                lines.append("        \(quoted(dependency))")
            }
            lines.append("    }")
        }

        lines.append("}")

        return lines
    }

    static func renderIncludeBlock(
        _ block: ConAnyIncludeBlock
    ) -> [String] {
        var lines: [String] = []

        let arguments = renderIncludeArguments(
            block
        )

        if arguments.isEmpty {
            lines.append("include {")
        } else {
            lines.append("include(")
            for (index, argument) in arguments.enumerated() {
                let comma = index == arguments.count - 1 ? "" : ","
                lines.append("    \(argument)\(comma)")
            }
            lines.append(") {")
        }

        for pattern in block.includes {
            lines.append("    \(quoted(pattern))")
        }

        for selection in block.selections {
            lines.append("    \(quoted(selection))")
        }

        lines.append("}")

        return lines
    }

    static func renderIncludeArguments(
        _ block: ConAnyIncludeBlock
    ) -> [String] {
        var arguments: [String] = []

        if let base = block.base {
            arguments.append(
                "from: \(renderIncludeBase(base))"
            )
        }

        if block.show != .full {
            arguments.append(
                "show: \(renderShowStyle(block.show))"
            )
        }

        return arguments
    }

    static func renderShowStyle(
        _ style: ConPathShowStyle
    ) -> String {
        switch style {
        case .full:
            return ".full"

        case .relativeToBase:
            return ".relativeToBase"

        case .relativeToCWD:
            return ".relativeToCWD"

        case .basename:
            return ".basename"

        case .middleEllipsis(let keepFirst, let keepLast):
            return ".middleEllipsis(keepFirst: \(keepFirst), keepLast: \(keepLast))"

        case .dropFirst(let count):
            return ".dropFirst(\(count))"
        }
    }

    static func renderIncludeBase(
        _ base: ConInclude
    ) -> String {
        switch base {
        case .path(let raw):
            return quoted(raw)

        case .partition(let raw):
            return ".partition(.\(raw))"
        }
    }

    static func quoted(
        _ value: String
    ) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return "\"\(escaped)\""
    }
}
