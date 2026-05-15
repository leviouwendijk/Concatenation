public enum ConLegacyMigration {
    public static func rewrite(
        _ legacyText: String
    ) throws -> String {
        let config = try ConLegacyParser.parse(
            legacyText
        )

        return ConConfigRenderer.render(
            config
        )
    }
}
