public enum ConLegacyParser {
    public static func parse(
        _ text: String
    ) throws -> ConAnyConfig {
        try ConAnyParser.parse(
            text
        )
    }
}
