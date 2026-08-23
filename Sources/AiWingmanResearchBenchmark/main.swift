import ActivityRadarCore
import CryptoKit
import Darwin
import Dispatch
import Foundation

private let frozenCorpusSHA256 = "183025163326aeb7f95470d2ecf494b31bc8239c8abb3e74e939967cf3ad8f30"
private let frozenSpecificationSHA256 = "ee6ab6568a3fcf8332facf9ef0a2d3bae66ab15d7f09a63ca6cbef6ce44e6f11"
private let frozenSchemaVersion = "1.0"
private let determinismRepetitions = 100
private let performanceWarmups = 5
private let performanceRepetitions = 30
private let performanceSizes = [10, 50, 200, 1_000]
private let day: TimeInterval = 86_400

private enum RunnerError: LocalizedError {
    case usage(String)
    case invalidCorpus(String)
    case invalidValue(String)
    case outputWrite(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message), .invalidCorpus(let message), .invalidValue(let message), .outputWrite(let message):
            return message
        }
    }
}

// MARK: - Strict corpus decoding

private struct StrictKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(_ value: String) {
        stringValue = value
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension Decoder {
    func strictContainer(expectedKeys: Set<String>, typeName: String) throws -> KeyedDecodingContainer<StrictKey> {
        let container = try container(keyedBy: StrictKey.self)
        let found = Set(container.allKeys.map(\.stringValue))
        let unknown = found.subtracting(expectedKeys).sorted()
        let missing = expectedKeys.subtracting(found).sorted()
        guard unknown.isEmpty, missing.isEmpty else {
            var details: [String] = []
            if !unknown.isEmpty { details.append("unknown keys: \(unknown.joined(separator: ", "))") }
            if !missing.isEmpty { details.append("missing keys: \(missing.joined(separator: ", "))") }
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "Strict \(typeName) decoding failed (\(details.joined(separator: "; ")))."
                )
            )
        }
        return container
    }
}

private extension KeyedDecodingContainer where Key == StrictKey {
    func required<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try decode(type, forKey: StrictKey(name))
    }

    func requiredOptional<T: Decodable>(_ type: T.Type, _ name: String) throws -> T? {
        let key = StrictKey(name)
        if try decodeNil(forKey: key) { return nil }
        return try decode(type, forKey: key)
    }
}

private struct FixtureCounts: Codable, Equatable {
    let lifecycle: Int
    let total: Int
    let triage: Int

    init(lifecycle: Int, total: Int, triage: Int) {
        self.lifecycle = lifecycle
        self.total = total
        self.triage = triage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["lifecycle", "total", "triage"],
            typeName: "fixtureCounts"
        )
        lifecycle = try container.required(Int.self, "lifecycle")
        total = try container.required(Int.self, "total")
        triage = try container.required(Int.self, "triage")
    }
}

private struct Corpus: Decodable {
    let fixtureCounts: FixtureCounts
    let fixtures: [Fixture]
    let generatedAt: String
    let independenceBoundary: String
    let oracleImplementation: String
    let schemaVersion: String
    let sentinels: [String]
    let specificationSha256: String

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: [
                "fixtureCounts", "fixtures", "generatedAt", "independenceBoundary",
                "oracleImplementation", "schemaVersion", "sentinels", "specificationSha256"
            ],
            typeName: "corpus"
        )
        fixtureCounts = try container.required(FixtureCounts.self, "fixtureCounts")
        fixtures = try container.required([Fixture].self, "fixtures")
        generatedAt = try container.required(String.self, "generatedAt")
        independenceBoundary = try container.required(String.self, "independenceBoundary")
        oracleImplementation = try container.required(String.self, "oracleImplementation")
        schemaVersion = try container.required(String.self, "schemaVersion")
        sentinels = try container.required([String].self, "sentinels")
        specificationSha256 = try container.required(String.self, "specificationSha256")
    }
}

private enum Fixture: Decodable {
    case triage(TriageFixture)
    case lifecycle(LifecycleFixture)

    init(from decoder: Decoder) throws {
        let probe = try decoder.container(keyedBy: StrictKey.self)
        let kind = try probe.decode(String.self, forKey: StrictKey("kind"))
        switch kind {
        case "triage": self = .triage(try TriageFixture(from: decoder))
        case "lifecycle": self = .lifecycle(try LifecycleFixture(from: decoder))
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown fixture kind: \(kind)")
            )
        }
    }

    var id: String {
        switch self {
        case .triage(let fixture): return fixture.id
        case .lifecycle(let fixture): return fixture.id
        }
    }

    var kind: String {
        switch self {
        case .triage: return "triage"
        case .lifecycle: return "lifecycle"
        }
    }

    var category: String {
        switch self {
        case .triage(let fixture): return fixture.category
        case .lifecycle(let fixture): return fixture.category
        }
    }
}

private struct TriageFixture: Decodable {
    let category: String
    let expected: TriageOutput
    let id: String
    let inputs: [TriageInputRecord]
    let kind: String
    let limit: Int
    let now: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["category", "expected", "id", "inputs", "kind", "limit", "now"],
            typeName: "triage fixture"
        )
        category = try container.required(String.self, "category")
        expected = try container.required(TriageOutput.self, "expected")
        id = try container.required(String.self, "id")
        inputs = try container.required([TriageInputRecord].self, "inputs")
        kind = try container.required(String.self, "kind")
        limit = try container.required(Int.self, "limit")
        now = try container.required(Int64.self, "now")
        guard kind == "triage" else {
            throw RunnerError.invalidCorpus("Fixture \(id) has inconsistent kind \(kind).")
        }
    }
}

private struct LifecycleFixture: Decodable {
    let category: String
    let confirmation: ConfirmationRecord?
    let expected: LifecycleOutput
    let id: String
    let item: ActivityItemRecord
    let kind: String
    let lastOpenedAt: Int64?
    let metadata: MetadataRecord
    let now: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: [
                "category", "confirmation", "expected", "id", "item", "kind",
                "lastOpenedAt", "metadata", "now"
            ],
            typeName: "lifecycle fixture"
        )
        category = try container.required(String.self, "category")
        confirmation = try container.requiredOptional(ConfirmationRecord.self, "confirmation")
        expected = try container.required(LifecycleOutput.self, "expected")
        id = try container.required(String.self, "id")
        item = try container.required(ActivityItemRecord.self, "item")
        kind = try container.required(String.self, "kind")
        lastOpenedAt = try container.requiredOptional(Int64.self, "lastOpenedAt")
        metadata = try container.required(MetadataRecord.self, "metadata")
        now = try container.required(Int64.self, "now")
        guard kind == "lifecycle" else {
            throw RunnerError.invalidCorpus("Fixture \(id) has inconsistent kind \(kind).")
        }
    }
}

private struct TriageInputRecord: Codable, Equatable {
    let item: ActivityItemRecord
    let lastOpenedAt: Int64?
    let metadata: MetadataRecord

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["item", "lastOpenedAt", "metadata"],
            typeName: "triage input"
        )
        item = try container.required(ActivityItemRecord.self, "item")
        lastOpenedAt = try container.requiredOptional(Int64.self, "lastOpenedAt")
        metadata = try container.required(MetadataRecord.self, "metadata")
    }

    func coreValue() throws -> WorkTriageInput {
        WorkTriageInput(
            item: try item.coreValue(),
            metadata: try metadata.coreValue(),
            lastOpenedAt: date(lastOpenedAt)
        )
    }
}

private struct MetadataRecord: Codable, Equatable {
    let deadline: Int64?
    let importance: String?
    let nextAction: String?
    let snoozeUntil: Int64?
    let waitingOn: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["deadline", "importance", "nextAction", "snoozeUntil", "waitingOn"],
            typeName: "continuity metadata"
        )
        deadline = try container.requiredOptional(Int64.self, "deadline")
        importance = try container.requiredOptional(String.self, "importance")
        nextAction = try container.requiredOptional(String.self, "nextAction")
        snoozeUntil = try container.requiredOptional(Int64.self, "snoozeUntil")
        waitingOn = try container.requiredOptional(String.self, "waitingOn")
    }

    func coreValue() throws -> WorkContinuityMetadata {
        let parsedImportance: WorkImportance?
        if let importance {
            guard let value = WorkImportance(rawValue: importance) else {
                throw RunnerError.invalidCorpus("Unknown importance value: \(importance)")
            }
            parsedImportance = value
        } else {
            parsedImportance = nil
        }
        return WorkContinuityMetadata(
            importance: parsedImportance,
            deadline: date(deadline),
            nextAction: nextAction,
            waitingOn: waitingOn,
            snoozeUntil: date(snoozeUntil)
        )
    }

    var hasNextAction: Bool { hasText(nextAction) }
    var isWaiting: Bool { hasText(waitingOn) }
}

private struct ConfirmationRecord: Codable, Equatable {
    let confirmedAt: Int64
    let state: String

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["confirmedAt", "state"],
            typeName: "lifecycle confirmation"
        )
        confirmedAt = try container.required(Int64.self, "confirmedAt")
        state = try container.required(String.self, "state")
    }

    func coreValue() throws -> WorkLifecycleConfirmation {
        guard let parsed = WorkLifecycleConfirmedState(rawValue: state) else {
            throw RunnerError.invalidCorpus("Unknown lifecycle confirmation state: \(state)")
        }
        return WorkLifecycleConfirmation(state: parsed, confirmedAt: date(confirmedAt))
    }
}

private struct ActivityItemRecord: Codable, Equatable {
    let attentionReason: String?
    let checkpoint: String
    let createdAt: Int64
    let cwd: String
    let executionState: String
    let goalStatus: String?
    let goalUpdatedAt: Int64?
    let historyComplete: Bool
    let id: String
    let lastActivityAt: Int64?
    let lastFinalAnswerAt: Int64?
    let lastMeaningfulAgentAt: Int64?
    let lastTerminalAt: Int64?
    let lastTerminalState: String?
    let lastUserMessageAt: Int64?
    let lastViewedAt: Int64?
    let projectName: String
    let rolloutPath: String
    let startedAt: Int64?
    let title: String
    let updatedAt: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: [
                "attentionReason", "checkpoint", "createdAt", "cwd", "executionState", "goalStatus",
                "goalUpdatedAt", "historyComplete", "id", "lastActivityAt", "lastFinalAnswerAt",
                "lastMeaningfulAgentAt", "lastTerminalAt", "lastTerminalState", "lastUserMessageAt",
                "lastViewedAt", "projectName", "rolloutPath", "startedAt", "title", "updatedAt"
            ],
            typeName: "activity item"
        )
        attentionReason = try container.requiredOptional(String.self, "attentionReason")
        checkpoint = try container.required(String.self, "checkpoint")
        createdAt = try container.required(Int64.self, "createdAt")
        cwd = try container.required(String.self, "cwd")
        executionState = try container.required(String.self, "executionState")
        goalStatus = try container.requiredOptional(String.self, "goalStatus")
        goalUpdatedAt = try container.requiredOptional(Int64.self, "goalUpdatedAt")
        historyComplete = try container.required(Bool.self, "historyComplete")
        id = try container.required(String.self, "id")
        lastActivityAt = try container.requiredOptional(Int64.self, "lastActivityAt")
        lastFinalAnswerAt = try container.requiredOptional(Int64.self, "lastFinalAnswerAt")
        lastMeaningfulAgentAt = try container.requiredOptional(Int64.self, "lastMeaningfulAgentAt")
        lastTerminalAt = try container.requiredOptional(Int64.self, "lastTerminalAt")
        lastTerminalState = try container.requiredOptional(String.self, "lastTerminalState")
        lastUserMessageAt = try container.requiredOptional(Int64.self, "lastUserMessageAt")
        lastViewedAt = try container.requiredOptional(Int64.self, "lastViewedAt")
        projectName = try container.required(String.self, "projectName")
        rolloutPath = try container.required(String.self, "rolloutPath")
        startedAt = try container.requiredOptional(Int64.self, "startedAt")
        title = try container.required(String.self, "title")
        updatedAt = try container.required(Int64.self, "updatedAt")
    }

    func coreValue() throws -> ActivityItem {
        guard let execution = ActivityExecutionState(rawValue: executionState) else {
            throw RunnerError.invalidCorpus("Unknown executionState value: \(executionState)")
        }
        let attention: ActivityAttentionReason?
        if let attentionReason {
            guard let parsed = ActivityAttentionReason(rawValue: attentionReason) else {
                throw RunnerError.invalidCorpus("Unknown attentionReason value: \(attentionReason)")
            }
            attention = parsed
        } else {
            attention = nil
        }
        let goal = try parseGoalStatus(goalStatus)
        let terminal: TerminalTurnState?
        if let lastTerminalState {
            guard let parsed = TerminalTurnState(rawValue: lastTerminalState) else {
                throw RunnerError.invalidCorpus("Unknown lastTerminalState value: \(lastTerminalState)")
            }
            terminal = parsed
        } else {
            terminal = nil
        }
        return ActivityItem(
            id: id,
            title: title,
            projectName: projectName,
            cwd: cwd,
            rolloutPath: rolloutPath,
            executionState: execution,
            attentionReason: attention,
            goalStatus: goal,
            goalUpdatedAt: date(goalUpdatedAt),
            createdAt: date(createdAt),
            startedAt: date(startedAt),
            updatedAt: date(updatedAt),
            lastActivityAt: date(lastActivityAt),
            lastUserMessageAt: date(lastUserMessageAt),
            lastMeaningfulAgentAt: date(lastMeaningfulAgentAt),
            lastFinalAnswerAt: date(lastFinalAnswerAt),
            lastTerminalAt: date(lastTerminalAt),
            lastTerminalState: terminal,
            lastViewedAt: date(lastViewedAt),
            checkpoint: checkpoint,
            historyComplete: historyComplete
        )
    }

    var timelineActivityAt: Int64 {
        [lastUserMessageAt, lastMeaningfulAgentAt, lastFinalAnswerAt, lastTerminalAt]
            .compactMap { $0 }
            .max() ?? updatedAt
    }
}

// MARK: - Comparable policy outputs

private struct TriageOutput: Codable, Equatable {
    let abstentionReason: String?
    let deferred: [TriageDeferralOutput]
    let rankedCandidates: [TriageCandidateOutput]
    let recommendedActivityID: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["abstentionReason", "deferred", "rankedCandidates", "recommendedActivityID"],
            typeName: "expected triage output"
        )
        abstentionReason = try container.requiredOptional(String.self, "abstentionReason")
        deferred = try container.required([TriageDeferralOutput].self, "deferred")
        rankedCandidates = try container.required([TriageCandidateOutput].self, "rankedCandidates")
        recommendedActivityID = try container.requiredOptional(String.self, "recommendedActivityID")
        if let abstentionReason, WorkTriageAbstentionReason(rawValue: abstentionReason) == nil {
            throw RunnerError.invalidCorpus("Unknown abstentionReason value: \(abstentionReason)")
        }
    }

    init(core: WorkTriageResult) throws {
        abstentionReason = core.abstentionReason?.rawValue
        deferred = try core.deferred.map(TriageDeferralOutput.init(core:))
        rankedCandidates = try core.rankedCandidates.map(TriageCandidateOutput.init(core:))
        recommendedActivityID = core.recommendedActivityID
    }
}

private struct TriageDeferralOutput: Codable, Equatable {
    let activityID: String
    let reason: String
    let until: Int64?

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["activityID", "reason", "until"],
            typeName: "expected triage deferral"
        )
        activityID = try container.required(String.self, "activityID")
        reason = try container.required(String.self, "reason")
        until = try container.requiredOptional(Int64.self, "until")
        guard WorkTriageDeferralReason(rawValue: reason) != nil else {
            throw RunnerError.invalidCorpus("Unknown deferral reason: \(reason)")
        }
    }

    init(core: WorkTriageDeferral) throws {
        activityID = core.activityID
        reason = core.reason.rawValue
        until = try epochSeconds(core.until)
    }
}

private struct TriageCandidateOutput: Codable, Equatable {
    let activityID: String
    let reasons: [TriageReasonOutput]
    let score: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["activityID", "reasons", "score"],
            typeName: "expected triage candidate"
        )
        activityID = try container.required(String.self, "activityID")
        reasons = try container.required([TriageReasonOutput].self, "reasons")
        score = try container.required(Int.self, "score")
    }

    init(core: WorkTriageCandidate) throws {
        activityID = core.activityID
        reasons = try core.reasons.map(TriageReasonOutput.init(core:))
        score = core.score
    }
}

private struct TriageReasonOutput: Codable, Equatable {
    let code: String
    let evidenceAt: Int64?
    let weight: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["code", "evidenceAt", "weight"],
            typeName: "expected triage reason"
        )
        code = try container.required(String.self, "code")
        evidenceAt = try container.requiredOptional(Int64.self, "evidenceAt")
        weight = try container.required(Int.self, "weight")
        guard WorkTriageReasonCode(rawValue: code) != nil else {
            throw RunnerError.invalidCorpus("Unknown triage reason code: \(code)")
        }
    }

    init(core: WorkTriageReason) throws {
        code = core.code.rawValue
        evidenceAt = try epochSeconds(core.evidenceAt)
        weight = core.weight
    }
}

private struct LifecycleOutput: Codable, Equatable {
    let activityID: String
    let evidence: [LifecycleEvidenceOutput]
    let requiresUserConfirmation: Bool
    let state: String

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["activityID", "evidence", "requiresUserConfirmation", "state"],
            typeName: "expected lifecycle output"
        )
        activityID = try container.required(String.self, "activityID")
        evidence = try container.required([LifecycleEvidenceOutput].self, "evidence")
        requiresUserConfirmation = try container.required(Bool.self, "requiresUserConfirmation")
        state = try container.required(String.self, "state")
        guard WorkLifecycleState(rawValue: state) != nil else {
            throw RunnerError.invalidCorpus("Unknown lifecycle state: \(state)")
        }
    }

    init(core: WorkLifecycleAssessment) throws {
        activityID = core.activityID
        evidence = try core.evidence.map(LifecycleEvidenceOutput.init(core:))
        requiresUserConfirmation = core.requiresUserConfirmation
        state = core.state.rawValue
    }
}

private struct LifecycleEvidenceOutput: Codable, Equatable {
    let ageInDays: Int?
    let code: String
    let observedAt: Int64?

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(
            expectedKeys: ["ageInDays", "code", "observedAt"],
            typeName: "expected lifecycle evidence"
        )
        ageInDays = try container.requiredOptional(Int.self, "ageInDays")
        code = try container.required(String.self, "code")
        observedAt = try container.requiredOptional(Int64.self, "observedAt")
        guard WorkLifecycleEvidenceCode(rawValue: code) != nil else {
            throw RunnerError.invalidCorpus("Unknown lifecycle evidence code: \(code)")
        }
    }

    init(core: WorkLifecycleEvidence) throws {
        ageInDays = core.ageInDays
        code = core.code.rawValue
        observedAt = try epochSeconds(core.observedAt)
    }
}

private enum PolicyOutput: Encodable, Equatable {
    case triage(TriageOutput)
    case lifecycle(LifecycleOutput)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .triage(let output): try output.encode(to: encoder)
        case .lifecycle(let output): try output.encode(to: encoder)
        }
    }
}

private extension Fixture {
    var expectedOutput: PolicyOutput {
        switch self {
        case .triage(let fixture): return .triage(fixture.expected)
        case .lifecycle(let fixture): return .lifecycle(fixture.expected)
        }
    }

    func evaluate() throws -> PolicyOutput {
        switch self {
        case .triage(let fixture):
            let result = WorkContinuityRanker.rank(
                try fixture.inputs.map { try $0.coreValue() },
                now: date(fixture.now),
                limit: fixture.limit
            )
            return .triage(try TriageOutput(core: result))
        case .lifecycle(let fixture):
            let result = WorkContinuityLifecycle.assess(
                item: try fixture.item.coreValue(),
                metadata: try fixture.metadata.coreValue(),
                lastOpenedAt: date(fixture.lastOpenedAt),
                confirmation: try fixture.confirmation?.coreValue(),
                now: date(fixture.now)
            )
            return .lifecycle(try LifecycleOutput(core: result))
        }
    }
}

// MARK: - Reports

private struct FixtureFailure: Encodable {
    let fixtureID: String
    let kind: String
    let category: String
    let message: String
    let expectedCanonicalJSON: String?
    let actualCanonicalJSON: String?
}

private struct ConformanceReport: Encodable {
    let passed: Bool
    let fixtureCount: Int
    let passedFixtureCount: Int
    let failures: [FixtureFailure]
}

private struct DeterminismFailure: Encodable {
    let fixtureID: String
    let repetition: Int
    let message: String
}

private struct DeterminismReport: Encodable {
    let passed: Bool
    let repetitionsPerFixture: Int
    let fixtureCount: Int
    let canonicalization: String
    let corpusOutputDigestSHA256: String?
    let corpusOutputDigestFraming: String
    let failures: [DeterminismFailure]
}

private struct SentinelLeak: Encodable {
    let fixtureID: String
    let sentinel: String
}

private struct ContentNeutralityReport: Encodable {
    let passed: Bool
    let scannedFixtureCount: Int
    let scannedSentinelCount: Int
    let serializedSurface: String
    let leaks: [SentinelLeak]
}

private struct ConfirmedStateSafetyReport: Encodable {
    let passed: Bool
    let unconfirmedLifecycleFixtureCount: Int
    let violationFixtureIDs: [String]
}

private struct TechnicalBaselineComparison: Encodable {
    let name: String
    let definition: String
    let exactDecisionAgreementCount: Int
    let exactDecisionAgreementRate: Double
    let disagreementFixtureIDs: [String]
    let mustAbstainViolationCount: Int
    let mustAbstainViolationFixtureIDs: [String]
}

private struct TechnicalBaselinesReport: Encodable {
    let label: String
    let scope: String
    let referenceDecisionDefinition: String
    let fixtureCount: Int
    let mustAbstainFixtureCount: Int
    let comparisons: [TechnicalBaselineComparison]
}

private struct LatencyStatistics: Encodable {
    let inputCount: Int
    let warmupRepetitions: Int
    let measuredRepetitions: Int
    let samplesNanoseconds: [UInt64]
    let medianMilliseconds: Double
    let p95Milliseconds: Double
    let iqrMilliseconds: Double
    let maximumMilliseconds: Double
    let checksum: UInt64
}

private struct PerformanceSeries: Encodable {
    let operation: String
    let interpretation: String
    let measurements: [LatencyStatistics]
}

private struct PerformanceReport: Encodable {
    let descriptiveOnly: Bool
    let clock: String
    let quantileMethod: String
    let processPeakResidentMemoryBytes: UInt64?
    let processPeakResidentMemoryScope: String
    let series: [PerformanceSeries]
}

private struct CorpusIdentity: Encodable {
    let path: String
    let sha256: String
    let frozenExpectedSha256: String
    let specificationSha256: String
    let schemaVersion: String
    let generatedAt: String
    let fixtureCounts: FixtureCounts
    let independenceBoundary: String
}

private struct EnvironmentReport: Encodable {
    let architecture: String
    let operatingSystem: String
    let activeProcessorCount: Int
    let buildConfiguration: String
}

private struct BenchmarkReport: Encodable {
    let reportSchemaVersion: String
    let runnerVersion: String
    let startedAt: String
    let completedAt: String
    let overallPassed: Bool
    let claimBoundary: String
    let corpus: CorpusIdentity
    let conformance: ConformanceReport
    let determinism: DeterminismReport
    let contentNeutrality: ContentNeutralityReport
    let confirmedStateSafety: ConfirmedStateSafetyReport
    let technicalBaselines: TechnicalBaselinesReport
    let performance: PerformanceReport
    let environment: EnvironmentReport
}

// MARK: - Runner

private struct Options {
    let corpusURL: URL
    let outputURL: URL

    static let usage = """
    Usage:
      swift run -c release AiWingmanResearchBenchmark \\
        --corpus Research/fixtures/continuity-policy-corpus-v1.json \\
        --output Research/results/continuity-benchmark-v1.json
    """

    static func parse(_ arguments: [String]) throws -> Options {
        var corpusPath = "Research/fixtures/continuity-policy-corpus-v1.json"
        var outputPath: String?
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--corpus", "--output":
                guard index + 1 < arguments.count else {
                    throw RunnerError.usage("Missing value for \(argument).\n\(usage)")
                }
                let value = arguments[index + 1]
                if argument == "--corpus" { corpusPath = value } else { outputPath = value }
                index += 2
            default:
                throw RunnerError.usage("Unknown argument: \(argument)\n\(usage)")
            }
        }
        guard let outputPath, !outputPath.isEmpty else {
            throw RunnerError.usage("--output is required.\n\(usage)")
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let corpusURL = URL(fileURLWithPath: corpusPath, relativeTo: cwd).standardizedFileURL
        let outputURL = URL(fileURLWithPath: outputPath, relativeTo: cwd).standardizedFileURL
        guard corpusURL != outputURL else {
            throw RunnerError.usage("The output path must not overwrite the frozen corpus.")
        }
        return Options(corpusURL: corpusURL, outputURL: outputURL)
    }
}

private struct BenchmarkRunner {
    let options: Options

    func run() throws -> Bool {
        let started = Date()
        let corpusData = try Data(contentsOf: options.corpusURL, options: [.mappedIfSafe])
        let corpusHash = sha256(corpusData)
        guard corpusHash == frozenCorpusSHA256 else {
            throw RunnerError.invalidCorpus(
                "Frozen corpus SHA-256 mismatch: expected \(frozenCorpusSHA256), got \(corpusHash)."
            )
        }

        let decoder = JSONDecoder()
        let corpus: Corpus
        do {
            corpus = try decoder.decode(Corpus.self, from: corpusData)
        } catch {
            throw RunnerError.invalidCorpus("Strict corpus decode failed: \(error)")
        }
        try validate(corpus)

        let conformanceBundle = try runConformance(corpus)
        let determinism = runDeterminism(corpus.fixtures)
        let contentNeutrality = try runContentNeutrality(
            corpus: corpus,
            conformanceOutputs: conformanceBundle.outputs
        )
        let technicalBaselines = runTechnicalBaselines(corpus.fixtures)
        let performance = try runPerformance()
        let overallPassed = conformanceBundle.report.passed
            && determinism.passed
            && contentNeutrality.passed
            && conformanceBundle.safety.passed

        let report = BenchmarkReport(
            reportSchemaVersion: "1.0",
            runnerVersion: "1.0.0",
            startedAt: iso8601(started),
            completedAt: iso8601(Date()),
            overallPassed: overallPassed,
            claimBoundary: "Synthetic, specification-derived continuity-policy evidence only; not external validation, human-benefit evidence, GUI validation, Codex-schema compatibility evidence, or remote-Wingman validation.",
            corpus: CorpusIdentity(
                path: portableReportPath(options.corpusURL),
                sha256: corpusHash,
                frozenExpectedSha256: frozenCorpusSHA256,
                specificationSha256: corpus.specificationSha256,
                schemaVersion: corpus.schemaVersion,
                generatedAt: corpus.generatedAt,
                fixtureCounts: corpus.fixtureCounts,
                independenceBoundary: corpus.independenceBoundary
            ),
            conformance: conformanceBundle.report,
            determinism: determinism,
            contentNeutrality: contentNeutrality,
            confirmedStateSafety: conformanceBundle.safety,
            technicalBaselines: technicalBaselines,
            performance: performance,
            environment: EnvironmentReport(
                architecture: architectureName,
                operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
                buildConfiguration: buildConfiguration
            )
        )
        try write(report, to: options.outputURL)
        print("AiWingman continuity benchmark: \(overallPassed ? "PASS" : "FAIL")")
        print("Report: \(options.outputURL.path)")
        return overallPassed
    }

    private func validate(_ corpus: Corpus) throws {
        guard corpus.schemaVersion == frozenSchemaVersion else {
            throw RunnerError.invalidCorpus("Unsupported corpus schemaVersion: \(corpus.schemaVersion)")
        }
        guard corpus.specificationSha256 == frozenSpecificationSHA256 else {
            throw RunnerError.invalidCorpus("Frozen specification SHA-256 mismatch in corpus metadata.")
        }
        guard ISO8601DateFormatter().date(from: corpus.generatedAt) != nil else {
            throw RunnerError.invalidCorpus("generatedAt is not a valid ISO-8601 timestamp.")
        }
        guard !corpus.independenceBoundary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RunnerError.invalidCorpus("independenceBoundary must not be empty.")
        }
        guard corpus.oracleImplementation == "Research/generate_continuity_corpus.py" else {
            throw RunnerError.invalidCorpus("Unexpected oracleImplementation: \(corpus.oracleImplementation)")
        }
        guard !corpus.sentinels.isEmpty,
              Set(corpus.sentinels).count == corpus.sentinels.count,
              corpus.sentinels.allSatisfy({ !$0.isEmpty }) else {
            throw RunnerError.invalidCorpus("Sentinels must be non-empty and unique.")
        }
        let triageCount = corpus.fixtures.reduce(0) { $0 + ($1.kind == "triage" ? 1 : 0) }
        let lifecycleCount = corpus.fixtures.count - triageCount
        let observed = FixtureCounts(lifecycle: lifecycleCount, total: corpus.fixtures.count, triage: triageCount)
        guard observed == corpus.fixtureCounts else {
            throw RunnerError.invalidCorpus("fixtureCounts do not match decoded fixtures.")
        }
        guard corpus.fixtureCounts == FixtureCounts(lifecycle: 80, total: 155, triage: 75) else {
            throw RunnerError.invalidCorpus("Frozen v1 fixture counts do not match 80 lifecycle / 75 triage / 155 total.")
        }
        let ids = corpus.fixtures.map(\.id)
        guard Set(ids).count == ids.count else {
            throw RunnerError.invalidCorpus("Fixture identifiers must be unique.")
        }
    }

    private func runConformance(
        _ corpus: Corpus
    ) throws -> (report: ConformanceReport, outputs: [String: PolicyOutput], safety: ConfirmedStateSafetyReport) {
        var failures: [FixtureFailure] = []
        var outputs: [String: PolicyOutput] = [:]
        var safetyViolations: [String] = []
        var unconfirmedLifecycleCount = 0

        for fixture in corpus.fixtures {
            let expected = fixture.expectedOutput
            do {
                let actual = try fixture.evaluate()
                outputs[fixture.id] = actual
                if actual != expected {
                    failures.append(
                        FixtureFailure(
                            fixtureID: fixture.id,
                            kind: fixture.kind,
                            category: fixture.category,
                            message: "Actual policy output did not exactly match the frozen oracle output.",
                            expectedCanonicalJSON: try canonicalString(expected),
                            actualCanonicalJSON: try canonicalString(actual)
                        )
                    )
                }
                if case .lifecycle(let lifecycleFixture) = fixture,
                   lifecycleFixture.confirmation == nil {
                    unconfirmedLifecycleCount += 1
                    if case .lifecycle(let lifecycleOutput) = actual,
                       lifecycleOutput.state == WorkLifecycleState.abandonedConfirmed.rawValue
                        || lifecycleOutput.state == WorkLifecycleState.obsoleteConfirmed.rawValue {
                        safetyViolations.append(fixture.id)
                    }
                }
            } catch {
                failures.append(
                    FixtureFailure(
                        fixtureID: fixture.id,
                        kind: fixture.kind,
                        category: fixture.category,
                        message: "Policy evaluation failed: \(error)",
                        expectedCanonicalJSON: try? canonicalString(expected),
                        actualCanonicalJSON: nil
                    )
                )
            }
        }
        let report = ConformanceReport(
            passed: failures.isEmpty,
            fixtureCount: corpus.fixtures.count,
            passedFixtureCount: corpus.fixtures.count - failures.count,
            failures: failures
        )
        let safety = ConfirmedStateSafetyReport(
            passed: safetyViolations.isEmpty,
            unconfirmedLifecycleFixtureCount: unconfirmedLifecycleCount,
            violationFixtureIDs: safetyViolations
        )
        return (report, outputs, safety)
    }

    private func runDeterminism(_ fixtures: [Fixture]) -> DeterminismReport {
        var failures: [DeterminismFailure] = []
        var digestMaterial = Data()
        var digestAvailable = true
        for fixture in fixtures {
            var baseline: Data?
            for repetition in 1...determinismRepetitions {
                do {
                    let bytes = try canonicalData(fixture.evaluate())
                    if let baseline, baseline != bytes {
                        failures.append(
                            DeterminismFailure(
                                fixtureID: fixture.id,
                                repetition: repetition,
                                message: "Canonical policy output differed from repetition 1."
                            )
                        )
                        break
                    }
                    if baseline == nil { baseline = bytes }
                } catch {
                    failures.append(
                        DeterminismFailure(
                            fixtureID: fixture.id,
                            repetition: repetition,
                            message: "Policy evaluation failed: \(error)"
                        )
                    )
                    break
                }
            }
            if let baseline {
                digestMaterial.append(contentsOf: fixture.id.utf8)
                digestMaterial.append(0x00)
                digestMaterial.append(baseline)
                digestMaterial.append(0x0A)
            } else {
                digestAvailable = false
            }
        }
        return DeterminismReport(
            passed: failures.isEmpty,
            repetitionsPerFixture: determinismRepetitions,
            fixtureCount: fixtures.count,
            canonicalization: "JSONEncoder sortedKeys, direct policy output only",
            corpusOutputDigestSHA256: digestAvailable ? sha256(digestMaterial) : nil,
            corpusOutputDigestFraming: "Frozen fixture order; UTF-8 fixture ID; NUL byte; canonical policy-output JSON; LF byte; SHA-256 over the concatenation. Timing, environment, expected outputs, and report metadata are excluded.",
            failures: failures
        )
    }

    private func runContentNeutrality(
        corpus: Corpus,
        conformanceOutputs: [String: PolicyOutput]
    ) throws -> ContentNeutralityReport {
        var leaks: [SentinelLeak] = []
        var scanned = 0
        for fixture in corpus.fixtures {
            guard let output = conformanceOutputs[fixture.id] else { continue }
            scanned += 1
            let serialized = try canonicalString(output)
            for sentinel in corpus.sentinels where serialized.contains(sentinel) {
                leaks.append(SentinelLeak(fixtureID: fixture.id, sentinel: sentinel))
            }
        }
        return ContentNeutralityReport(
            passed: leaks.isEmpty && scanned == corpus.fixtures.count,
            scannedFixtureCount: scanned,
            scannedSentinelCount: corpus.sentinels.count,
            serializedSurface: "Actual content-free WorkContinuityRanker and WorkContinuityLifecycle output DTOs",
            leaks: leaks
        )
    }

    private func runTechnicalBaselines(_ fixtures: [Fixture]) -> TechnicalBaselinesReport {
        let triageFixtures = fixtures.compactMap { fixture -> TriageFixture? in
            if case .triage(let value) = fixture { return value }
            return nil
        }
        let mustAbstain = triageFixtures.filter { $0.expected.recommendedActivityID == nil }
        let definitions: [(String, String, (TriageFixture) -> String?)] = [
            (
                "recency-only",
                "Always select the input with the latest timeline activity; break ties by ascending activity ID; ignore policy deferrals, history completeness, metadata, thresholds, and lead suppression.",
                recencyOnlyDecision
            ),
            (
                "same-score-no-suppression",
                "Apply the frozen absolute deferrals, incomplete-history exclusion, reason weights, score sorting, and ID tie-break, but remove the 30-point threshold and 10-point lead suppression.",
                sameScoreNoSuppressionDecision
            )
        ]
        let comparisons = definitions.map { name, definition, decide in
            var disagreements: [String] = []
            var mustAbstainViolations: [String] = []
            for fixture in triageFixtures {
                let baseline = decide(fixture)
                if baseline != fixture.expected.recommendedActivityID {
                    disagreements.append(fixture.id)
                }
                if fixture.expected.recommendedActivityID == nil, baseline != nil {
                    mustAbstainViolations.append(fixture.id)
                }
            }
            let agreements = triageFixtures.count - disagreements.count
            return TechnicalBaselineComparison(
                name: name,
                definition: definition,
                exactDecisionAgreementCount: agreements,
                exactDecisionAgreementRate: triageFixtures.isEmpty ? 0 : Double(agreements) / Double(triageFixtures.count),
                disagreementFixtureIDs: disagreements,
                mustAbstainViolationCount: mustAbstainViolations.count,
                mustAbstainViolationFixtureIDs: mustAbstainViolations
            )
        }
        return TechnicalBaselinesReport(
            label: "Synthetic contract comparisons; not human-benefit evidence",
            scope: "Frozen triage fixtures only",
            referenceDecisionDefinition: "Exact equality of recommendedActivityID; nil denotes abstention, and abstention-reason agreement is not counted separately.",
            fixtureCount: triageFixtures.count,
            mustAbstainFixtureCount: mustAbstain.count,
            comparisons: comparisons
        )
    }

    private func runPerformance() throws -> PerformanceReport {
        var triageMeasurements: [LatencyStatistics] = []
        var lifecycleMeasurements: [LatencyStatistics] = []
        for count in performanceSizes {
            let inputs = makePerformanceInputs(count: count)
            let now = date(2_100_000_000)
            triageMeasurements.append(
                measure(inputCount: count) {
                    let result = WorkContinuityRanker.rank(inputs, now: now, limit: 3)
                    return consume(result)
                }
            )
            lifecycleMeasurements.append(
                measure(inputCount: count) {
                    var checksum: UInt64 = 0
                    for input in inputs {
                        let result = WorkContinuityLifecycle.assess(
                            item: input.item,
                            metadata: input.metadata,
                            lastOpenedAt: input.lastOpenedAt,
                            now: now
                        )
                        checksum = checksum &* 16777619 &+ consume(result)
                    }
                    return checksum
                }
            )
        }
        return PerformanceReport(
            descriptiveOnly: true,
            clock: "DispatchTime.uptimeNanoseconds",
            quantileMethod: "Linear interpolation at index (n - 1) * p; IQR = p75 - p25",
            processPeakResidentMemoryBytes: processPeakResidentMemoryBytes(),
            processPeakResidentMemoryScope: "Darwin getrusage(RUSAGE_SELF).ru_maxrss sampled after all performance series. This is the macOS process-lifetime peak in bytes; it is not an allocation total and is not isolated by operation or input size.",
            series: [
                PerformanceSeries(
                    operation: "triage-portfolio",
                    interpretation: "One WorkContinuityRanker.rank call over N synthetic inputs.",
                    measurements: triageMeasurements
                ),
                PerformanceSeries(
                    operation: "lifecycle-batch",
                    interpretation: "N WorkContinuityLifecycle.assess calls over the same synthetic inputs.",
                    measurements: lifecycleMeasurements
                )
            ]
        )
    }
}

// MARK: - Baseline implementations

private func recencyOnlyDecision(_ fixture: TriageFixture) -> String? {
    fixture.inputs
        .sorted {
            if $0.item.timelineActivityAt != $1.item.timelineActivityAt {
                return $0.item.timelineActivityAt > $1.item.timelineActivityAt
            }
            return $0.item.id < $1.item.id
        }
        .first?.item.id
}

private func sameScoreNoSuppressionDecision(_ fixture: TriageFixture) -> String? {
    fixture.inputs
        .filter { baselineDeferral($0, now: fixture.now) == nil && $0.item.historyComplete }
        .compactMap { input -> (id: String, score: Int)? in
            let reasons = baselineReasonWeights(input, now: fixture.now)
            guard !reasons.isEmpty else { return nil }
            return (input.item.id, reasons.reduce(0, +))
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.id < $1.id
        }
        .first?.id
}

private func baselineDeferral(_ input: TriageInputRecord, now: Int64) -> String? {
    if let snooze = input.metadata.snoozeUntil, snooze > now { return "snoozed" }
    if input.metadata.isWaiting { return "waitingOnExternal" }
    let directAttention = input.item.attentionReason != nil
    let snoozeDue = input.metadata.snoozeUntil.map { $0 <= now } ?? false
    let deadlineUrgent = input.metadata.deadline.map { $0 <= now + 3 * 86_400 } ?? false
    let goalComplete = input.item.goalStatus == "complete"
        && !["openSilent", "aborted", "recentlyActive"].contains(input.item.executionState)
    if (input.item.executionState == "completed" || goalComplete)
        && !directAttention && !deadlineUrgent && !snoozeDue {
        return "terminal"
    }
    return nil
}

private func baselineReasonWeights(_ input: TriageInputRecord, now: Int64) -> [Int] {
    var weights: [Int] = []
    switch input.item.attentionReason {
    case "explicitInput": weights.append(100)
    case "goalBlocked": weights.append(90)
    case "newSinceView": weights.append(80)
    case "usageLimited", "budgetLimited": weights.append(70)
    default: break
    }
    if let deadline = input.metadata.deadline {
        let remaining = deadline - now
        if remaining <= 0 { weights.append(65) }
        else if remaining <= 86_400 { weights.append(55) }
        else if remaining <= 3 * 86_400 { weights.append(40) }
        else if remaining <= 7 * 86_400 { weights.append(20) }
    }
    if let snooze = input.metadata.snoozeUntil,
       snooze <= now,
       input.lastOpenedAt.map({ $0 < snooze }) ?? true {
        weights.append(45)
    }
    switch input.metadata.importance {
    case "critical": weights.append(30)
    case "high": weights.append(20)
    case "low": weights.append(-10)
    default: break
    }
    if input.metadata.hasNextAction {
        weights.append(10)
    } else {
        let age = now - input.item.timelineActivityAt
        if age >= 7 * 86_400 { weights.append(age >= 30 * 86_400 ? 18 : 12) }
    }
    if input.item.executionState == "recentlyActive" { weights.append(8) }
    if let opened = input.lastOpenedAt, now - opened >= 0, now - opened <= 15 * 60 {
        weights.append(-15)
    }
    return weights
}

// MARK: - Performance support

private func makePerformanceInputs(count: Int) -> [WorkTriageInput] {
    let now = date(2_100_000_000)
    return (0..<count).map { index in
        let ageDays = index % 61
        let activityAt = now.addingTimeInterval(-Double(ageDays) * day)
        let attention: ActivityAttentionReason? = index % 29 == 0 ? .explicitInput
            : index % 23 == 0 ? .newSinceView
            : index % 19 == 0 ? .goalBlocked
            : nil
        let execution: ActivityExecutionState = index % 17 == 0 ? .recentlyActive
            : index % 31 == 0 ? .completed
            : index % 37 == 0 ? .openSilent
            : .idle
        let goal: ActivityGoalStatus? = index % 19 == 0 ? .blocked
            : index % 41 == 0 ? .paused
            : nil
        let item = ActivityItem(
            id: String(format: "perf-%05d", index),
            title: "Synthetic performance item",
            projectName: "Synthetic benchmark",
            cwd: "/synthetic/performance",
            rolloutPath: "/synthetic/performance.jsonl",
            executionState: execution,
            attentionReason: attention,
            goalStatus: goal,
            goalUpdatedAt: goal == nil ? nil : activityAt,
            createdAt: activityAt.addingTimeInterval(-60),
            startedAt: activityAt,
            updatedAt: activityAt,
            lastActivityAt: activityAt,
            lastUserMessageAt: activityAt,
            lastMeaningfulAgentAt: nil,
            lastFinalAnswerAt: attention == .newSinceView ? activityAt : nil,
            lastTerminalAt: execution == .completed ? activityAt : nil,
            lastTerminalState: execution == .completed ? .completed : nil,
            lastViewedAt: nil,
            checkpoint: "Synthetic",
            historyComplete: index % 43 != 0
        )
        let metadata = WorkContinuityMetadata(
            importance: index % 13 == 0 ? .critical : index % 7 == 0 ? .high : .normal,
            deadline: index % 11 == 0 ? now.addingTimeInterval(Double((index % 9) - 3) * day) : nil,
            nextAction: index % 5 == 0 ? "recorded" : nil,
            waitingOn: index % 47 == 0 ? "external" : nil,
            snoozeUntil: index % 53 == 0 ? now.addingTimeInterval(day) : nil
        )
        return WorkTriageInput(
            item: item,
            metadata: metadata,
            lastOpenedAt: index % 67 == 0 ? now.addingTimeInterval(-300) : nil
        )
    }
}

private func measure(inputCount: Int, operation: () -> UInt64) -> LatencyStatistics {
    var checksum: UInt64 = 0
    for _ in 0..<performanceWarmups {
        checksum = checksum &+ operation()
    }
    var samples: [UInt64] = []
    samples.reserveCapacity(performanceRepetitions)
    for _ in 0..<performanceRepetitions {
        let start = DispatchTime.now().uptimeNanoseconds
        let value = operation()
        let end = DispatchTime.now().uptimeNanoseconds
        checksum = checksum &* 1099511628211 &+ value
        samples.append(end - start)
    }
    let sorted = samples.sorted()
    let median = percentile(sorted, 0.50)
    let p95 = percentile(sorted, 0.95)
    let q25 = percentile(sorted, 0.25)
    let q75 = percentile(sorted, 0.75)
    return LatencyStatistics(
        inputCount: inputCount,
        warmupRepetitions: performanceWarmups,
        measuredRepetitions: performanceRepetitions,
        samplesNanoseconds: samples,
        medianMilliseconds: median / 1_000_000,
        p95Milliseconds: p95 / 1_000_000,
        iqrMilliseconds: (q75 - q25) / 1_000_000,
        maximumMilliseconds: Double(sorted.last ?? 0) / 1_000_000,
        checksum: checksum
    )
}

private func percentile(_ sorted: [UInt64], _ p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let position = Double(sorted.count - 1) * p
    let lower = Int(floor(position))
    let upper = Int(ceil(position))
    if lower == upper { return Double(sorted[lower]) }
    let fraction = position - Double(lower)
    return Double(sorted[lower]) * (1 - fraction) + Double(sorted[upper]) * fraction
}

private func processPeakResidentMemoryBytes() -> UInt64? {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0, usage.ru_maxrss >= 0 else { return nil }
    return UInt64(usage.ru_maxrss)
}

private func consume(_ result: WorkTriageResult) -> UInt64 {
    var value = UInt64(result.rankedCandidates.count &+ result.deferred.count)
    value = value &* 16777619 &+ UInt64(bitPattern: Int64(result.rankedCandidates.first?.score ?? 0))
    value = value &* 16777619 &+ UInt64(result.recommendedActivityID?.utf8.count ?? 0)
    return value
}

private func consume(_ result: WorkLifecycleAssessment) -> UInt64 {
    let stateIndex = WorkLifecycleState.allCases.firstIndex(of: result.state) ?? 0
    return UInt64(stateIndex &* 257 &+ result.evidence.count)
}

// MARK: - Utilities

private func parseGoalStatus(_ raw: String?) throws -> ActivityGoalStatus? {
    guard let raw else { return nil }
    switch raw {
    case "usageLimited": return .usageLimited
    case "budgetLimited": return .budgetLimited
    default:
        guard let parsed = ActivityGoalStatus(rawValue: raw) else {
            throw RunnerError.invalidCorpus("Unknown goalStatus value: \(raw)")
        }
        return parsed
    }
}

private func hasText(_ value: String?) -> Bool {
    guard let value else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func date(_ seconds: Int64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(seconds))
}

private func date(_ seconds: Int64?) -> Date? {
    seconds.map(date)
}

private func epochSeconds(_ value: Date?) throws -> Int64? {
    guard let value else { return nil }
    let seconds = value.timeIntervalSince1970
    let rounded = seconds.rounded()
    guard seconds.isFinite,
          abs(seconds - rounded) < 0.000_001,
          rounded >= Double(Int64.min),
          rounded <= Double(Int64.max) else {
        throw RunnerError.invalidValue("Policy emitted a non-integral or out-of-range evidence time: \(seconds)")
    }
    return Int64(rounded)
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func canonicalData<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private func canonicalString<T: Encodable>(_ value: T) throws -> String {
    guard let result = String(data: try canonicalData(value), encoding: .utf8) else {
        throw RunnerError.invalidValue("Canonical JSON was not UTF-8.")
    }
    return result
}

private func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

private func write<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(0x0A)
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    } catch {
        throw RunnerError.outputWrite("Could not write benchmark report to \(url.path): \(error)")
    }
}

private var architectureName: String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x86_64"
    #else
    return "other"
    #endif
}

private var buildConfiguration: String {
    #if DEBUG
    return "debug"
    #else
    return "release"
    #endif
}

private func portableReportPath(_ url: URL) -> String {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .standardizedFileURL.path
    let path = url.standardizedFileURL.path
    let prefix = cwd.hasSuffix("/") ? cwd : cwd + "/"
    if path.hasPrefix(prefix) {
        return String(path.dropFirst(prefix.count))
    }
    return url.lastPathComponent
}

if CommandLine.arguments.dropFirst().contains("--help") {
    print(Options.usage)
    exit(EXIT_SUCCESS)
}

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    let passed = try BenchmarkRunner(options: options).run()
    exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
} catch {
    fputs("AiWingmanResearchBenchmark error: \(error.localizedDescription)\n", stderr)
    exit(2)
}
