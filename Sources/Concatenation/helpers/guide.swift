import Foundation

public func conignoreGuide() -> String {
    return """
    .conignore Configuration Guide
    ---------------------------------
    The .conignore file allows you to configure files, directories, and values to exclude or obscure during processing. 
    Below is a breakdown of how to use and structure the .conignore file.

    [IgnoreFiles]
    - Use patterns to exclude specific files. Patterns support wildcards (*, ?).
    - Examples:
        *.env       - Matches all `.env` files.
        *.log       - Matches all `.log` files.
        config.json - Matches a specific file named `config.json`.

    [IgnoreDirectories]
    - Use patterns to exclude specific directories. Patterns also support wildcards (*, ?).
    - Examples:
        env/        - Matches the `env/` directory.
        build/      - Matches the `build/` directory.
        */backups/  - Matches any `backups/` directory at any level.

    [Obscure]
    - Use this section to obscure sensitive values in the processed files. Specify the value and method of obscuration.
    - Methods:
        redact   - Replaces the value with `[REDACTED]`.
        preserve - Replaces numeric and alphabetic characters with zeros and letters.
        verbose  - Replaces the value with a type identifier like `[INT]` or `[STRING]`.
    - Examples:
        password : redact   - Replaces occurrences of "password" with `[REDACTED]`.
        12345 : preserve    - Replaces "12345" with "00000".
        apiKey : verbose    - Replaces "apiKey" with `[STRING]`.

    Additional Notes:
    - Comments: Lines beginning with `#` are ignored.
    - Wildcards:
        *  - Matches any number of characters (e.g., `*.log` matches `error.log` or `app.log`).
        ?  - Matches a single character (e.g., `file?.txt` matches `file1.txt` but not `file12.txt`).
    - Directory patterns must end with a `/` to ensure they match directories specifically.

    Example .conignore File:
    ---------------------------------
    [IgnoreFiles]
    *.env
    *.log
    secrets.txt

    [IgnoreDirectories]
    env/
    build/
    */backups/

    [Obscure]
    password : redact
    apiKey : verbose
    """

}

public func printConignoreGuide() {
    print(
        conignoreGuide()
    )
}
