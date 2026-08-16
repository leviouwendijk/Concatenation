import Foundation
import Concatenation
import IO

@main
struct ConcatenationBenchmark {
    static func main() async throws {
        let samples = max(
            1,
            Int(
                ProcessInfo.processInfo.environment[
                    "CON_BENCH_SAMPLES"
                ] ?? ""
            ) ?? 7
        )

        let deepInspection =
            ProcessInfo.processInfo.environment[
                "CON_BENCH_DEEP_INSPECTION"
            ] == "1"

        let scales = [
            BenchmarkScale(
                files: 100,
                linesPerFile: 100
            ),
            BenchmarkScale(
                files: 100,
                linesPerFile: 1_000
            ),
            BenchmarkScale(
                files: 1_000,
                linesPerFile: 100
            ),
            BenchmarkScale(
                files: 100,
                linesPerFile: 10_000
            ),
        ]

        let cacheBackends =
            ProcessInfo.processInfo.environment[
                "CON_BENCH_CACHE_BACKENDS"
            ] == "1"

        let cacheOnly =
            ProcessInfo.processInfo.environment[
                "CON_BENCH_CACHE_ONLY"
            ] == "1"

        if !cacheOnly {
            print(
                [
                    "scale",
                    "scenario",
                    "median_ms",
                    "p95_ms",
                    "safeguard_reads",
                    "safeguard_hits",
                    "source_reads",
                    "metadata_hits",
                    "rebuilds",
                    "render",
                    "write",
                ].joined(
                    separator: "\t"
                )
            )

            for scale in scales {
                try await run(
                    scale: scale,
                    samples: samples,
                    deepInspection: deepInspection
                )
            }
        }

        if cacheBackends || cacheOnly {
            if !cacheOnly {
                print()
            }

            try await CacheBackendBenchmark.run(
                scales: scales,
                samples: samples,
                deepInspection: deepInspection
            )
        }
    }

    static func run(
        scale: BenchmarkScale,
        samples: Int,
        deepInspection: Bool
    ) async throws {
        let fixture = try BenchmarkFixture(
            scale: scale,
            deepInspection: deepInspection
        )

        defer {
            fixture.remove()
        }

        let cold = try await fixture.measureCold(
            samples: samples
        )

        print(
            cold.row(
                scale: scale
            )
        )

        let warm = try await fixture.measureWarm(
            samples: samples
        )

        print(
            warm.row(
                scale: scale
            )
        )

        let changedOnePercent =
            try await fixture.measureChanged(
                fraction: 0.01,
                name: "changed-1pct",
                samples: samples
            )

        print(
            changedOnePercent.row(
                scale: scale
            )
        )

        let changedTenPercent =
            try await fixture.measureChanged(
                fraction: 0.10,
                name: "changed-10pct",
                samples: samples
            )

        print(
            changedTenPercent.row(
                scale: scale
            )
        )

        print(
            [
                scale.label,
                "speedup-warm-vs-cold",
                format(
                    cold.medianMilliseconds
                        / warm.medianMilliseconds
                ) + "x",
            ].joined(
                separator: "\t"
            )
        )
    }
}

internal struct BenchmarkScale {
    let files: Int
    let linesPerFile: Int

    var totalLines: Int {
        files * linesPerFile
    }

    var label: String {
        "\(files)x\(linesPerFile)-\(totalLines)"
    }
}

internal struct BenchmarkMeasurement {
    let scenario: String
    let milliseconds: [Double]
    let safeguardReads: Int
    let safeguardHits: Int
    let sourceReads: Int
    let metadataHits: Int
    let rebuilds: Int
    let performedRender: Bool
    let performedWrite: Bool

    var medianMilliseconds: Double {
        percentile(
            0.50
        )
    }

    var p95Milliseconds: Double {
        percentile(
            0.95
        )
    }

    func percentile(
        _ quantile: Double
    ) -> Double {
        let sorted = milliseconds.sorted()

        guard sorted.count > 1 else {
            return sorted.first ?? 0
        }

        let position =
            quantile
            * Double(
                sorted.count - 1
            )

        let lower = Int(
            floor(
                position
            )
        )

        let upper = Int(
            ceil(
                position
            )
        )

        guard lower != upper else {
            return sorted[
                lower
            ]
        }

        let fraction =
            position
            - Double(
                lower
            )

        return sorted[lower]
            + (
                sorted[upper]
                - sorted[lower]
            )
            * fraction
    }

    func row(
        scale: BenchmarkScale
    ) -> String {
        [
            scale.label,
            scenario,
            format(
                medianMilliseconds
            ),
            format(
                p95Milliseconds
            ),
            String(
                safeguardReads
            ),
            String(
                safeguardHits
            ),
            String(
                sourceReads
            ),
            String(
                metadataHits
            ),
            String(
                rebuilds
            ),
            String(
                performedRender
            ),
            String(
                performedWrite
            ),
        ].joined(
            separator: "\t"
        )
    }
}

internal final class BenchmarkFixture {
    let scale: BenchmarkScale
    let root: URL
    let output: URL
    let workspace: ConcatenationWorkspace
    let sources: [URL]
    let deepInspection: Bool

    private var mutationGeneration = 0

    init(
        scale: BenchmarkScale,
        deepInspection: Bool
    ) throws {
        self.scale = scale
        self.deepInspection = deepInspection

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "concatenation-benchmark-\(UUID().uuidString)",
                isDirectory: true
            )

        self.root = root
        self.output = root.appendingPathComponent(
            "output.txt",
            isDirectory: false
        )
        self.workspace = ConcatenationWorkspace(
            root: root
        )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        var sources: [URL] = []
        sources.reserveCapacity(
            scale.files
        )

        for index in 0..<scale.files {
            let source = root.appendingPathComponent(
                String(
                    format: "source-%04d.txt",
                    index
                ),
                isDirectory: false
            )

            try Self.baseContent(
                scale: scale,
                for: index
            ).write(
                to: source,
                atomically: false,
                encoding: .utf8
            )

            sources.append(
                source
            )
        }

        self.sources = sources
    }

    func concatenator() -> FileConcatenator {
        FileConcatenator(
            inputFiles: sources,
            outputURL: output,
            workspace: workspace,
            maxLinesPerFile: nil,
            trimBlankLines: true,
            relativePaths: false,
            includeSourceModifiedAt: false,
            protectSecrets: deepInspection,
            deepSecretInspection: deepInspection
        )
    }

    func measureCold(
        samples: Int
    ) async throws -> BenchmarkMeasurement {
        var durations: [Double] = []
        var last: ConcatenationWriteResult?

        for _ in 0..<samples {
            try resetCacheAndOutput()

            let measured = try await measure {
                try await self.concatenator().write(
                    concurrency: .automatic
                )
            }

            let result = measured.result

            try require(
                result.document.statistics.cache.safeguardReads
                    == (
                        deepInspection
                            ? scale.files
                            : 0
                    ),
                "cold safeguardReads"
            )

            try require(
                result.document.statistics.cache.safeguardHits
                    == 0,
                "cold safeguardHits"
            )

            try require(
                result.document.statistics.cache.sourceReads
                    == scale.files,
                "cold sourceReads"
            )

            try require(
                result.document.statistics.cache.metadataHits
                    == 0,
                "cold metadataHits"
            )

            try require(
                result.document.statistics.cache.rebuilds
                    == scale.files,
                "cold rebuilds"
            )

            try require(
                result.performedRender,
                "cold render"
            )

            try require(
                result.performedWrite,
                "cold write"
            )

            durations.append(
                measured.milliseconds
            )

            last = result
        }

        return measurement(
            scenario: "cold",
            durations: durations,
            last: last
        )
    }

    func measureWarm(
        samples: Int
    ) async throws -> BenchmarkMeasurement {
        try resetCacheAndOutput()

        _ = try await concatenator().write(
            concurrency: .automatic
        )

        var durations: [Double] = []
        var last: ConcatenationWriteResult?

        for _ in 0..<samples {
            let measured = try await measure {
                try await self.concatenator().write(
                    concurrency: .automatic
                )
            }

            let result = measured.result

            try require(
                result.document.statistics.cache.safeguardReads
                    == 0,
                "warm safeguardReads"
            )

            try require(
                result.document.statistics.cache.safeguardHits
                    == (
                        deepInspection
                            ? scale.files
                            : 0
                    ),
                "warm safeguardHits"
            )

            try require(
                result.document.statistics.cache.sourceReads
                    == 0,
                "warm sourceReads"
            )

            try require(
                result.document.statistics.cache.metadataHits
                    == scale.files,
                "warm metadataHits"
            )

            try require(
                result.document.statistics.cache.rebuilds
                    == 0,
                "warm rebuilds"
            )

            try require(
                !result.performedRender,
                "warm render"
            )

            try require(
                !result.performedWrite,
                "warm write"
            )

            durations.append(
                measured.milliseconds
            )

            last = result
        }

        return measurement(
            scenario: "warm-noop",
            durations: durations,
            last: last
        )
    }

    func measureChanged(
        fraction: Double,
        name: String,
        samples: Int
    ) async throws -> BenchmarkMeasurement {
        try resetCacheAndOutput()

        _ = try await concatenator().write(
            concurrency: .automatic
        )

        let changeCount = max(
            1,
            Int(
                ceil(
                    Double(
                        scale.files
                    )
                    * fraction
                )
            )
        )

        var durations: [Double] = []
        var last: ConcatenationWriteResult?

        for sample in 0..<samples {
            try mutate(
                count: changeCount,
                sample: sample
            )

            let measured = try await measure {
                try await self.concatenator().write(
                    concurrency: .automatic
                )
            }

            let result = measured.result

            try require(
                result.document.statistics.cache.safeguardReads
                    == (
                        deepInspection
                            ? changeCount
                            : 0
                    ),
                "\(name) safeguardReads"
            )

            try require(
                result.document.statistics.cache.safeguardHits
                    == (
                        deepInspection
                            ? scale.files - changeCount
                            : 0
                    ),
                "\(name) safeguardHits"
            )

            try require(
                result.document.statistics.cache.sourceReads
                    == changeCount,
                "\(name) sourceReads"
            )

            try require(
                result.document.statistics.cache.metadataHits
                    == scale.files - changeCount,
                "\(name) metadataHits"
            )

            try require(
                result.document.statistics.cache.rebuilds
                    == changeCount,
                "\(name) rebuilds"
            )

            try require(
                result.performedRender,
                "\(name) render"
            )

            try require(
                result.performedWrite,
                "\(name) write"
            )

            durations.append(
                measured.milliseconds
            )

            last = result
        }

        return measurement(
            scenario: name,
            durations: durations,
            last: last
        )
    }

    func measurement(
        scenario: String,
        durations: [Double],
        last: ConcatenationWriteResult?
    ) -> BenchmarkMeasurement {
        let cache = last?
            .document
            .statistics
            .cache
            ?? .init()

        return BenchmarkMeasurement(
            scenario: scenario,
            milliseconds: durations,
            safeguardReads: cache.safeguardReads,
            safeguardHits: cache.safeguardHits,
            sourceReads: cache.sourceReads,
            metadataHits: cache.metadataHits,
            rebuilds: cache.rebuilds,
            performedRender:
                last?.performedRender
                ?? false,
            performedWrite:
                last?.performedWrite
                ?? false
        )
    }

    func mutate(
        count: Int,
        sample: Int
    ) throws {
        mutationGeneration += 1

        let start = (
            sample
            * count
        ) % scale.files

        for offset in 0..<count {
            let index = (
                start
                + offset
            ) % scale.files

            let mutation = String(
                repeating: "x",
                count:
                    mutationGeneration
                    + offset
                    + 1
            )

            let text =
                baseContent(
                    for: index
                )
                + "\nmutation-\(mutation)"

            try text.write(
                to: sources[
                    index
                ],
                atomically: false,
                encoding: .utf8
            )
        }
    }

    func baseContent(
        for sourceIndex: Int
    ) -> String {
        Self.baseContent(
            scale: scale,
            for: sourceIndex
        )
    }

    static func baseContent(
        scale: BenchmarkScale,
        for sourceIndex: Int
    ) -> String {
        var lines: [String] = []
        lines.reserveCapacity(
            scale.linesPerFile
        )

        for line in 0..<scale.linesPerFile {
            lines.append(
                "source-\(sourceIndex)-line-\(line)-abcdefghijklmnopqrstuvwxyz"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }

    func resetCacheAndOutput() throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(
            atPath: workspace.state.path
        ) {
            try fileManager.removeItem(
                at: workspace.state
            )
        }

        if fileManager.fileExists(
            atPath: output.path
        ) {
            try fileManager.removeItem(
                at: output
            )
        }
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}

private func measure(
    _ operation: () async throws -> ConcatenationWriteResult
) async throws -> (
    milliseconds: Double,
    result: ConcatenationWriteResult
) {
    let clock = ContinuousClock()
    let start = clock.now

    let result = try await operation()

    let end = clock.now
    let duration = start.duration(
        to: end
    )

    let components = duration.components

    let milliseconds =
        Double(
            components.seconds
        )
        * 1_000
        + Double(
            components.attoseconds
        )
        / 1_000_000_000_000_000

    return (
        milliseconds,
        result
    )
}

private func require(
    _ condition: Bool,
    _ name: String
) throws {
    guard condition else {
        throw BenchmarkError.failedInvariant(
            name
        )
    }
}

private func format(
    _ value: Double
) -> String {
    String(
        format: "%.3f",
        value
    )
}

internal enum BenchmarkError:
    Error,
    CustomStringConvertible
{
    case failedInvariant(String)

    var description: String {
        switch self {
        case .failedInvariant(let name):
            return "Benchmark invariant failed: \(name)"
        }
    }
}
