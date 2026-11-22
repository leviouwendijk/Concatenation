import Foundation
import TestFlows

@main
enum ConcatenationFlowMain {
    static func main() async {
        // Flows that do not pass their own cache root must not write into the
        // real `~/.cache/concatenation`.
        let cacheRoot = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "concatenation-test-cache-\(UUID().uuidString)",
            isDirectory: true
        )

        setenv(
            "CON_CACHE_DIR",
            cacheRoot.path,
            1
        )

        await TestFlowCLI.run(
            suite: ConcatenationFlowSuite.self
        )
    }
}
