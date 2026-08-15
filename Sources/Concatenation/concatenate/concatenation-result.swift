import Foundation
import Writers

public struct ConcatenationRenderResult: Sendable {
    public let document: ConcatenationDocument
    public let text: String

    public init(
        document: ConcatenationDocument,
        text: String
    ) {
        self.document = document
        self.text = text
    }
}

public struct ConcatenationPreparationStatistics:
    Sendable,
    Equatable
{
    public let duration: TimeInterval
    public let cacheLoadDuration: TimeInterval
    public let sourceInspectionDuration: TimeInterval
    public let safeguardDuration: TimeInterval
    public let sectionPreloadDuration: TimeInterval
    public let sourcePrereadDuration: TimeInterval
    public let assemblyDuration: TimeInterval

    public init(
        duration: TimeInterval = 0,
        cacheLoadDuration: TimeInterval = 0,
        sourceInspectionDuration: TimeInterval = 0,
        safeguardDuration: TimeInterval = 0,
        sectionPreloadDuration: TimeInterval = 0,
        sourcePrereadDuration: TimeInterval = 0,
        assemblyDuration: TimeInterval = 0
    ) {
        self.duration = duration
        self.cacheLoadDuration = cacheLoadDuration
        self.sourceInspectionDuration =
            sourceInspectionDuration
        self.safeguardDuration =
            safeguardDuration
        self.sectionPreloadDuration =
            sectionPreloadDuration
        self.sourcePrereadDuration =
            sourcePrereadDuration
        self.assemblyDuration =
            assemblyDuration
    }

    public var measuredDuration: TimeInterval {
        cacheLoadDuration
            + sourceInspectionDuration
            + safeguardDuration
            + sectionPreloadDuration
            + sourcePrereadDuration
            + assemblyDuration
    }

    public var otherDuration: TimeInterval {
        max(
            0,
            duration - measuredDuration
        )
    }

    public static func + (
        lhs: Self,
        rhs: Self
    ) -> Self {
        .init(
            duration:
                lhs.duration
                + rhs.duration,
            cacheLoadDuration:
                lhs.cacheLoadDuration
                + rhs.cacheLoadDuration,
            sourceInspectionDuration:
                lhs.sourceInspectionDuration
                + rhs.sourceInspectionDuration,
            safeguardDuration:
                lhs.safeguardDuration
                + rhs.safeguardDuration,
            sectionPreloadDuration:
                lhs.sectionPreloadDuration
                + rhs.sectionPreloadDuration,
            sourcePrereadDuration:
                lhs.sourcePrereadDuration
                + rhs.sourcePrereadDuration,
            assemblyDuration:
                lhs.assemblyDuration
                + rhs.assemblyDuration
        )
    }
}

public struct ConcatenationWriteStatistics:
    Sendable,
    Equatable
{
    public let duration: TimeInterval
    public let preparation: ConcatenationPreparationStatistics
    public let artifactFingerprintDuration: TimeInterval
    public let artifactValidationDuration: TimeInterval
    public let renderDuration: TimeInterval
    public let outputWriteDuration: TimeInterval
    public let artifactCreationDuration: TimeInterval
    public let cachePersistenceDuration: TimeInterval
    public let clipboardDuration: TimeInterval

    public init(
        duration: TimeInterval = 0,
        preparation: ConcatenationPreparationStatistics = .init(),
        artifactFingerprintDuration: TimeInterval = 0,
        artifactValidationDuration: TimeInterval = 0,
        renderDuration: TimeInterval = 0,
        outputWriteDuration: TimeInterval = 0,
        artifactCreationDuration: TimeInterval = 0,
        cachePersistenceDuration: TimeInterval = 0,
        clipboardDuration: TimeInterval = 0
    ) {
        self.duration = duration
        self.preparation = preparation
        self.artifactFingerprintDuration =
            artifactFingerprintDuration
        self.artifactValidationDuration =
            artifactValidationDuration
        self.renderDuration =
            renderDuration
        self.outputWriteDuration =
            outputWriteDuration
        self.artifactCreationDuration =
            artifactCreationDuration
        self.cachePersistenceDuration =
            cachePersistenceDuration
        self.clipboardDuration =
            clipboardDuration
    }

    public var measuredDuration: TimeInterval {
        preparation.duration
            + artifactFingerprintDuration
            + artifactValidationDuration
            + renderDuration
            + outputWriteDuration
            + artifactCreationDuration
            + cachePersistenceDuration
            + clipboardDuration
    }

    public var otherDuration: TimeInterval {
        max(
            0,
            duration - measuredDuration
        )
    }

    public static func + (
        lhs: Self,
        rhs: Self
    ) -> Self {
        .init(
            duration:
                lhs.duration
                + rhs.duration,
            preparation:
                lhs.preparation
                + rhs.preparation,
            artifactFingerprintDuration:
                lhs.artifactFingerprintDuration
                + rhs.artifactFingerprintDuration,
            artifactValidationDuration:
                lhs.artifactValidationDuration
                + rhs.artifactValidationDuration,
            renderDuration:
                lhs.renderDuration
                + rhs.renderDuration,
            outputWriteDuration:
                lhs.outputWriteDuration
                + rhs.outputWriteDuration,
            artifactCreationDuration:
                lhs.artifactCreationDuration
                + rhs.artifactCreationDuration,
            cachePersistenceDuration:
                lhs.cachePersistenceDuration
                + rhs.cachePersistenceDuration,
            clipboardDuration:
                lhs.clipboardDuration
                + rhs.clipboardDuration
        )
    }
}

public struct ConcatenationSourceActivity:
    Sendable,
    Equatable
{
    public enum Kind:
        String,
        Sendable,
        Equatable
    {
        case reread
        case rebuilt
    }

    public let source: URL
    public let presentedPath: String?
    public let kind: Kind

    public init(
        source: URL,
        presentedPath: String? = nil,
        kind: Kind
    ) {
        self.source =
            source.standardizedFileURL

        self.presentedPath =
            presentedPath

        self.kind =
            kind
    }

    init(
        standardizedSource source: URL,
        presentedPath: String? = nil,
        kind: Kind
    ) {
        self.source =
            source

        self.presentedPath =
            presentedPath

        self.kind =
            kind
    }
}

public struct ConcatenationWriteResult: Sendable {
    public let document: ConcatenationDocument
    public let renderResult: ConcatenationRenderResult?
    public let writeResult: SafeWriteResult?
    public let renderedLineCount: Int
    public let statistics: ConcatenationWriteStatistics
    public let sourceActivities:
        [ConcatenationSourceActivity]

    public init(
        document: ConcatenationDocument,
        renderResult: ConcatenationRenderResult?,
        writeResult: SafeWriteResult?,
        renderedLineCount: Int,
        sourceActivities:
            [ConcatenationSourceActivity] = [],
        statistics: ConcatenationWriteStatistics = .init()
    ) {
        self.document = document
        self.renderResult = renderResult
        self.writeResult = writeResult
        self.renderedLineCount = renderedLineCount
        self.statistics = statistics
        self.sourceActivities =
            sourceActivities
    }

    public var text: String? {
        renderResult?.text
    }

    public var performedRender: Bool {
        renderResult != nil
    }

    public var performedWrite: Bool {
        writeResult != nil
    }
}
