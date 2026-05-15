import Terminal

func printSuccess(
    outputPath: String,
    totalLines total: Int
) {
    let headerLine = "Concatenation " + "ok".ansi(.green, .bold)
    let pathLine = "source: \(outputPath)".ansi(.brightBlack)
    let totalsLine = "\(total) ".ansi(.cyan) + "lines concatenated"

    print(headerLine)
    print(pathLine.indent())
    print(totalsLine.indent())
    print()
}
