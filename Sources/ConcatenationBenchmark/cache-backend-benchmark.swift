import Concatenation
import Foundation
import IO

internal enum CacheBackendBenchmark {
    static func run(
        scales: [BenchmarkScale],
        samples: Int,
        deepInspection: Bool
    ) async throws {
        print([
            "scale",
            "scenario",
            "median_ms",
            "p95_ms",
            "prepare_ms",
            "cache_load_ms",
            "inspect_ms",
            "safeguard_ms",
            "section_load_ms",
            "preread_ms",
            "assemble_ms",
            "fingerprint_ms",
            "artifact_check_ms",
            "render_ms",
            "write_ms",
            "artifact_record_ms",
            "cache_persist_ms",
            "safeguard_reads",
            "safeguard_hits",
            "source_reads",
            "metadata_hits",
            "content_hits",
            "rebuilds",
            "render_bytes",
            "render_checksum",
            "render",
            "write",
        ].joined(separator: "\t"))

        for scale in scales {
            try await run(
                scale: scale,
                samples: samples,
                deepInspection: deepInspection
            )
        }
    }

    private static func run(
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

        let measurements = [
            try await uncached(
                fixture,
                samples: samples
            ),
            try await memoryCold(
                fixture,
                samples: samples
            ),
            try await diskWarm(
                fixture,
                samples: samples
            ),
            try await memoryWarm(
                fixture,
                samples: samples
            ),
            try await hybridFirst(
                fixture,
                samples: samples
            ),
            try await hybridWarm(
                fixture,
                samples: samples
            ),
            try await memoryInvalidated(
                fixture,
                samples: samples,
                stage: .document
            ),
            try await memoryInvalidated(
                fixture,
                samples: samples,
                stage: .render
            ),
            try await memoryInvalidated(
                fixture,
                samples: samples,
                stage: .preparedRender
            ),
            try await memoryInvalidated(
                fixture,
                samples: samples,
                stage: .write
            ),
        ]

        for measurement in measurements {
            print(
                measurement.row(
                    scale: scale
                )
            )
        }

        let byName = Dictionary(
            uniqueKeysWithValues:
                measurements.map {
                    (
                        $0.scenario,
                        $0
                    )
                }
        )

        if let disk = byName[
            "disk-warm"
        ],
        let memory = byName[
            "memory-warm"
        ] {
            print([
                scale.label,
                "speedup-memory-vs-disk-warm",
                format(
                    disk.medianMilliseconds
                        / memory.medianMilliseconds
                ) + "x",
            ].joined(separator: "\t"))
        }

        if let first = byName[
            "hybrid-first"
        ],
        let warm = byName[
            "hybrid-warm"
        ] {
            print([
                scale.label,
                "speedup-hybrid-heap-vs-first",
                format(
                    first.medianMilliseconds
                        / warm.medianMilliseconds
                ) + "x",
            ].joined(separator: "\t"))
        }

        if let preparedRender = byName[
            "memory-invalidated-prepared-render"
        ],
        let write = byName[
            "memory-invalidated-write"
        ] {
            let writeRenderMilliseconds =
                write.median {
                    $0.renderDuration
                }

            if writeRenderMilliseconds > 0 {
                print([
                    scale.label,
                    "ratio-prepared-render-vs-write-render",
                    format(
                        preparedRender.medianMilliseconds
                            / writeRenderMilliseconds
                    ) + "x",
                ].joined(separator: "\t"))
            }
        }
    }

    private static func uncached(
        _ fixture: BenchmarkFixture,
        samples: Int
    ) async throws -> Measurement {
        try await cold(
            fixture,
            scenario: "uncached",
            samples: samples
        ) {
            fixture.cacheConcatenator(
                cache: nil
            )
        }
    }

    private static func memoryCold(
        _ fixture: BenchmarkFixture,
        samples: Int
    ) async throws -> Measurement {
        var values: [Sample] = []

        for _ in 0..<samples {
            try fixture.resetCacheAndOutput()

            let session =
                ConcatenationSession(
                    cache:
                        ConcatenationMemoryCache()
                )

            let binding =
                session.binding(
                    for:
                        fixture.output
                )

            let sample =
                try await measureWrite {
                    try await fixture
                        .cacheConcatenator(
                            cache:
                                binding
                        )
                        .write(
                            concurrency:
                                .automatic
                        )
                }

            try requireCold(
                sample,
                fixture:
                    fixture,
                name:
                    "memory-cold"
            )

            values.append(
                sample
            )
        }

        return .init(
            scenario:
                "memory-cold",
            samples:
                values
        )
    }

    private static func diskWarm(
        _ fixture: BenchmarkFixture,
        samples: Int
    ) async throws -> Measurement {
        try fixture.resetCacheAndOutput()

        _ = try await fixture
            .concatenator()
            .write(
                concurrency:
                    .automatic
            )

        return try await warm(
            fixture,
            scenario:
                "disk-warm",
            samples:
                samples
        ) {
            fixture.concatenator()
        }
    }

    private static func memoryWarm(
        _ fixture: BenchmarkFixture,
        samples: Int
    ) async throws -> Measurement {
        try fixture.resetCacheAndOutput()

        let session =
            ConcatenationSession(
                cache:
                    ConcatenationMemoryCache()
            )

        let binding =
            session.binding(
                for:
                    fixture.output
            )

        _ = try await fixture
            .cacheConcatenator(
                cache:
                    binding
            )
            .write(
                concurrency:
                    .automatic
            )

        return try await warm(
            fixture,
            scenario:
                "memory-warm",
            samples:
                samples
        ) {
            fixture.cacheConcatenator(
                cache:
                    binding
            )
        }
    }

    private static func hybridFirst(
        _ fixture: BenchmarkFixture,
        samples: Int
    ) async throws -> Measurement {
        try fixture.resetCacheAndOutput()

        _ = try await fixture
            .concatenator()
            .write(
                concurrency:
                    .automatic
            )

        let disk =
            ConcatenationDiskCache(
                workspace:
                    fixture.workspace
            )

        var values: [Sample] = []

        for _ in 0..<samples {
            let session =
                ConcatenationSession(
                    cache:
                        ConcatenationHybridCache(
                            memory:
                                ConcatenationMemoryCache(),
                            disk:
                                disk
                        )
                )

            let binding =
                session.binding(
                    for:
                        fixture.output
                )

            let sample =
                try await measureWrite {
                    try await fixture
                        .cacheConcatenator(
                            cache:
                                binding
                        )
                        .write(
                            concurrency:
                                .automatic
                        )
                }

            try requireWarm(
                sample,
                fixture:
                    fixture,
                name:
                    "hybrid-first"
            )

            values.append(
                sample
            )
        }

        return .init(
            scenario:
                "hybrid-first",
            samples:
                values
        )
    }

    private static func hybridWarm(
        _ fixture: BenchmarkFixture,
        samples: Int
    ) async throws -> Measurement {
        try fixture.resetCacheAndOutput()

        _ = try await fixture
            .concatenator()
            .write(
                concurrency:
                    .automatic
            )

        let session =
            ConcatenationSession(
                cache:
                    ConcatenationHybridCache(
                        memory:
                            ConcatenationMemoryCache(),
                        disk:
                            ConcatenationDiskCache(
                                workspace:
                                    fixture.workspace
                            )
                    )
            )

        let binding =
            session.binding(
                for:
                    fixture.output
            )

        _ = try await fixture
            .cacheConcatenator(
                cache:
                    binding
            )
            .write(
                concurrency:
                    .automatic
            )

        return try await warm(
            fixture,
            scenario:
                "hybrid-warm",
            samples:
                samples
        ) {
            fixture.cacheConcatenator(
                cache:
                    binding
            )
        }
    }

    private static func memoryInvalidated(
        _ fixture: BenchmarkFixture,
        samples: Int,
        stage: InvalidationStage
    ) async throws -> Measurement {
        try fixture.resetCacheAndOutput()

        let session =
            ConcatenationSession(
                cache:
                    ConcatenationMemoryCache()
            )

        let binding =
            session.binding(
                for:
                    fixture.output
            )

        _ = try await stage.measure(
            fixture:
                fixture,
            binding:
                binding
        )

        var values: [Sample] = []

        for sampleIndex in 0..<samples {
            let source =
                fixture.sources[
                    sampleIndex
                        % fixture.scale.files
                ]

            try fixture.mutate(
                count:
                    1,
                sample:
                    sampleIndex
            )

            try session.invalidate(
                source:
                    source
            )

            let sample =
                try await stage.measure(
                    fixture:
                        fixture,
                    binding:
                        binding
                )

            try requireInvalidated(
                sample,
                fixture:
                    fixture,
                name:
                    stage.scenario,
                rendered:
                    stage.performedRender,
                written:
                    stage.performedWrite
            )

            values.append(
                sample
            )
        }

        return .init(
            scenario:
                stage.scenario,
            samples:
                values
        )
    }

    private static func cold(
        _ fixture: BenchmarkFixture,
        scenario: String,
        samples: Int,
        concatenator: () -> FileConcatenator
    ) async throws -> Measurement {
        var values: [Sample] = []

        for _ in 0..<samples {
            try fixture.resetCacheAndOutput()

            let sample =
                try await measureWrite {
                    try await concatenator()
                        .write(
                            concurrency:
                                .automatic
                        )
                }

            try requireCold(
                sample,
                fixture:
                    fixture,
                name:
                    scenario
            )

            values.append(
                sample
            )
        }

        return .init(
            scenario:
                scenario,
            samples:
                values
        )
    }

    private static func warm(
        _ fixture: BenchmarkFixture,
        scenario: String,
        samples: Int,
        concatenator: () -> FileConcatenator
    ) async throws -> Measurement {
        var values: [Sample] = []

        for _ in 0..<samples {
            let sample =
                try await measureWrite {
                    try await concatenator()
                        .write(
                            concurrency:
                                .automatic
                        )
                }

            try requireWarm(
                sample,
                fixture:
                    fixture,
                name:
                    scenario
            )

            values.append(
                sample
            )
        }

        return .init(
            scenario:
                scenario,
            samples:
                values
        )
    }

    private static func requireCold(
        _ sample: Sample,
        fixture: BenchmarkFixture,
        name: String
    ) throws {
        let cache =
            sample.document
                .statistics
                .cache

        let safeguards =
            fixture.deepInspection
                ? fixture.scale.files
                : 0

        try check(
            cache.safeguardReads
                == safeguards,
            "\(name) safeguardReads"
        )

        try check(
            cache.safeguardHits
                == 0,
            "\(name) safeguardHits"
        )

        try check(
            cache.sourceReads
                == fixture.scale.files,
            "\(name) sourceReads"
        )

        try check(
            cache.metadataHits
                == 0,
            "\(name) metadataHits"
        )

        try check(
            cache.rebuilds
                == fixture.scale.files,
            "\(name) rebuilds"
        )

        try check(
            sample.performedRender,
            "\(name) render"
        )

        try check(
            sample.performedWrite,
            "\(name) write"
        )
    }

    private static func requireWarm(
        _ sample: Sample,
        fixture: BenchmarkFixture,
        name: String
    ) throws {
        let cache =
            sample.document
                .statistics
                .cache

        let safeguards =
            fixture.deepInspection
                ? fixture.scale.files
                : 0

        try check(
            cache.safeguardReads
                == 0,
            "\(name) safeguardReads"
        )

        try check(
            cache.safeguardHits
                == safeguards,
            "\(name) safeguardHits"
        )

        try check(
            cache.sourceReads
                == 0,
            "\(name) sourceReads"
        )

        try check(
            cache.metadataHits
                == fixture.scale.files,
            "\(name) metadataHits"
        )

        try check(
            cache.rebuilds
                == 0,
            "\(name) rebuilds"
        )

        try check(
            !sample.performedRender,
            "\(name) render"
        )

        try check(
            !sample.performedWrite,
            "\(name) write"
        )
    }

    private static func requireInvalidated(
        _ sample: Sample,
        fixture: BenchmarkFixture,
        name: String,
        rendered: Bool,
        written: Bool
    ) throws {
        let cache =
            sample.document
                .statistics
                .cache

        let safeguardReads =
            fixture.deepInspection
                ? 1
                : 0

        let safeguardHits =
            fixture.deepInspection
                ? fixture.scale.files - 1
                : 0

        try check(
            cache.safeguardReads
                == safeguardReads,
            "\(name) safeguardReads"
        )

        try check(
            cache.safeguardHits
                == safeguardHits,
            "\(name) safeguardHits"
        )

        try check(
            cache.sourceReads
                == 1,
            "\(name) sourceReads"
        )

        try check(
            cache.metadataHits
                == fixture.scale.files - 1,
            "\(name) metadataHits"
        )

        try check(
            cache.rebuilds
                == 1,
            "\(name) rebuilds"
        )

        try check(
            sample.performedRender
                == rendered,
            "\(name) render"
        )

        try check(
            sample.performedWrite
                == written,
            "\(name) write"
        )
    }
}

private enum InvalidationStage {
    case document
    case render
    case preparedRender
    case write

    var scenario: String {
        switch self {
        case .document:
            return "memory-invalidated-document"

        case .render:
            return "memory-invalidated-render"

        case .preparedRender:
            return "memory-invalidated-prepared-render"

        case .write:
            return "memory-invalidated-write"
        }
    }

    var performedRender: Bool {
        switch self {
        case .document:
            return false

        case .render, .preparedRender, .write:
            return true
        }
    }

    var performedWrite: Bool {
        switch self {
        case .document, .render, .preparedRender:
            return false

        case .write:
            return true
        }
    }

    func measure(
        fixture: BenchmarkFixture,
        binding: ConcatenationCacheBinding
    ) async throws -> Sample {
        switch self {
        case .document:
            return try await measureDocument {
                try await fixture
                    .cacheConcatenator(
                        cache:
                            binding
                    )
                    .document(
                        concurrency:
                            .automatic
                    )
            }

        case .render:
            return try await measureRender {
                try await fixture
                    .cacheConcatenator(
                        cache:
                            binding
                    )
                    .render(
                        concurrency:
                            .automatic
                    )
            }

        case .preparedRender:
            let concatenator =
                fixture.cacheConcatenator(
                    cache:
                        binding
                )

            let document =
                try await concatenator.document(
                    concurrency:
                        .automatic
                )

            try check(
                concatenator.plan
                    .options
                    .output
                    .format
                    == .text,
                "prepared-render requires text output"
            )

            return measurePreparedRender(
                document:
                    document,
                outputURL:
                    concatenator.outputURL,
                options:
                    concatenator.plan.options
            )

        case .write:
            return try await measureWrite {
                try await fixture
                    .cacheConcatenator(
                        cache:
                            binding
                    )
                    .write(
                        concurrency:
                            .automatic
                    )
            }
        }
    }
}

private extension BenchmarkFixture {
    func cacheConcatenator(
        cache: ConcatenationCacheBinding?
    ) -> FileConcatenator {
        FileConcatenator(
            inputFiles:
                sources,
            outputURL:
                output,
            cache:
                cache,
            maxLinesPerFile:
                nil,
            trimBlankLines:
                true,
            relativePaths:
                false,
            includeSourceModifiedAt:
                false,
            protectSecrets:
                deepInspection,
            deepSecretInspection:
                deepInspection
        )
    }
}

private struct Sample {
    let milliseconds: Double
    let document: ConcatenationDocument
    let statistics: ConcatenationWriteStatistics
    let performedRender: Bool
    let performedWrite: Bool
    let renderObservation: RenderObservation?

    init(
        milliseconds: Double,
        document: ConcatenationDocument,
        statistics: ConcatenationWriteStatistics,
        performedRender: Bool,
        performedWrite: Bool,
        renderObservation: RenderObservation? = nil
    ) {
        self.milliseconds = milliseconds
        self.document = document
        self.statistics = statistics
        self.performedRender = performedRender
        self.performedWrite = performedWrite
        self.renderObservation = renderObservation
    }
}

private struct RenderObservation {
    let byteCount: Int
    let checksum: UInt64
}

private struct Measurement {
    let scenario: String
    let samples: [Sample]

    var medianMilliseconds: Double {
        percentile(
            samples.map(
                \.milliseconds
            ),
            quantile:
                0.50
        )
    }

    var p95Milliseconds: Double {
        percentile(
            samples.map(
                \.milliseconds
            ),
            quantile:
                0.95
        )
    }

    func median(
        _ value:
            (ConcatenationWriteStatistics)
            -> TimeInterval
    ) -> Double {
        percentile(
            samples.map {
                value(
                    $0.statistics
                ) * 1_000
            },
            quantile:
                0.50
        )
    }

    func row(
        scale: BenchmarkScale
    ) -> String {
        let last =
            samples.last

        let cache =
            last?
                .document
                .statistics
                .cache
            ?? .init()

        let renderBytes =
            last?
                .renderObservation
                .map {
                    String(
                        $0.byteCount
                    )
                }
            ?? "-"

        let renderChecksum =
            last?
                .renderObservation
                .map {
                    String(
                        $0.checksum,
                        radix: 16
                    )
                }
            ?? "-"

        return [
            scale.label,
            scenario,
            format(
                medianMilliseconds
            ),
            format(
                p95Milliseconds
            ),
            format(
                median {
                    $0.preparation.duration
                }
            ),
            format(
                median {
                    $0.preparation
                        .cacheLoadDuration
                }
            ),
            format(
                median {
                    $0.preparation
                        .sourceInspectionDuration
                }
            ),
            format(
                median {
                    $0.preparation
                        .safeguardDuration
                }
            ),
            format(
                median {
                    $0.preparation
                        .sectionPreloadDuration
                }
            ),
            format(
                median {
                    $0.preparation
                        .sourcePrereadDuration
                }
            ),
            format(
                median {
                    $0.preparation
                        .assemblyDuration
                }
            ),
            format(
                median {
                    $0.artifactFingerprintDuration
                }
            ),
            format(
                median {
                    $0.artifactValidationDuration
                }
            ),
            format(
                median {
                    $0.renderDuration
                }
            ),
            format(
                median {
                    $0.outputWriteDuration
                }
            ),
            format(
                median {
                    $0.artifactCreationDuration
                }
            ),
            format(
                median {
                    $0.cachePersistenceDuration
                }
            ),
            String(
                cache.safeguardReads
            ),
            String(
                cache.safeguardHits
            ),
            String(
                cache.sourceReads
            ),
            String(
                cache.metadataHits
            ),
            String(
                cache.contentHits
            ),
            String(
                cache.rebuilds
            ),
            renderBytes,
            renderChecksum,
            String(
                last?.performedRender
                    ?? false
            ),
            String(
                last?.performedWrite
                    ?? false
            ),
        ].joined(
            separator:
                "\t"
        )
    }
}

private func measureWrite(
    _ operation:
        () async throws
        -> ConcatenationWriteResult
) async throws -> Sample {
    let (milliseconds, result) =
        try await measure(
            operation
        )

    let observation =
        result.text.map(
            observeRenderedText
        )

    return .init(
        milliseconds:
            milliseconds,
        document:
            result.document,
        statistics:
            result.statistics,
        performedRender:
            result.performedRender,
        performedWrite:
            result.performedWrite,
        renderObservation:
            observation
    )
}

private func measureRender(
    _ operation:
        () async throws
        -> ConcatenationRenderResult
) async throws -> Sample {
    let (milliseconds, result) =
        try await measure(
            operation
        )

    let observation =
        observeRenderedText(
            result.text
        )

    return .init(
        milliseconds:
            milliseconds,
        document:
            result.document,
        statistics:
            .init(),
        performedRender:
            true,
        performedWrite:
            false,
        renderObservation:
            observation
    )
}

private func measurePreparedRender(
    document: ConcatenationDocument,
    outputURL: URL?,
    options: ConcatenationRenderOptions
) -> Sample {
    let clock =
        ContinuousClock()

    let start =
        clock.now

    let text =
        ConcatenationRenderer(
            outputURL:
                outputURL,
            options:
                options
        )
        .render(
            document
        )

    let components =
        start.duration(
            to:
                clock.now
        )
        .components

    let milliseconds =
        Double(
            components.seconds
        )
        * 1_000
        + Double(
            components.attoseconds
        )
        / 1_000_000_000_000_000

    let observation =
        observeRenderedText(
            text
        )

    return .init(
        milliseconds:
            milliseconds,
        document:
            document,
        statistics:
            .init(
                renderDuration:
                    milliseconds
                    / 1_000
            ),
        performedRender:
            true,
        performedWrite:
            false,
        renderObservation:
            observation
    )
}

private func measureDocument(
    _ operation:
        () async throws
        -> ConcatenationDocument
) async throws -> Sample {
    let (milliseconds, document) =
        try await measure(
            operation
        )

    return .init(
        milliseconds:
            milliseconds,
        document:
            document,
        statistics:
            .init(),
        performedRender:
            false,
        performedWrite:
            false
    )
}

private func measure<Value>(
    _ operation:
        () async throws
        -> Value
) async throws -> (
    milliseconds: Double,
    value: Value
) {
    let clock =
        ContinuousClock()

    let start =
        clock.now

    let value =
        try await operation()

    let components =
        start.duration(
            to:
                clock.now
        )
        .components

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
        value
    )
}

@inline(never)
private func observeRenderedText(
    _ text: String
) -> RenderObservation {
    var checksum:
        UInt64 = 14_695_981_039_346_656_037

    var byteCount = 0

    for byte in text.utf8 {
        byteCount += 1
        checksum ^= UInt64(
            byte
        )
        checksum &*= 1_099_511_628_211
    }

    return .init(
        byteCount:
            byteCount,
        checksum:
            checksum
    )
}

private func percentile(
    _ values: [Double],
    quantile: Double
) -> Double {
    let sorted =
        values.sorted()

    guard sorted.count > 1 else {
        return sorted.first
            ?? 0
    }

    let position =
        quantile
        * Double(
            sorted.count - 1
        )

    let lower =
        Int(
            floor(
                position
            )
        )

    let upper =
        Int(
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

    return sorted[
        lower
    ]
    + (
        sorted[
            upper
        ]
        - sorted[
            lower
        ]
    )
    * fraction
}

private func check(
    _ condition: Bool,
    _ name: String
) throws {
    guard condition else {
        throw BenchmarkError
            .failedInvariant(
                name
            )
    }
}

private func format(
    _ value: Double
) -> String {
    String(
        format:
            "%.3f",
        value
    )
}
