import TestFlows

@main
enum ConcatenationFlowMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: ConcatenationFlowSuite.self
        )
    }
}
