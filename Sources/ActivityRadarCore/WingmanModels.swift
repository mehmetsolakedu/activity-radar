import Foundation

public enum WingmanEvidenceCoverage: String, Codable, Sendable {
    case complete
    case partial
    case unavailable
}

public enum WingmanTokenSource: String, Codable, Sendable {
    case sqliteMeasuredTotal
    case rolloutMeasuredBreakdown
}

public struct WingmanTokenUsage: Codable, Equatable, Sendable {
    public let source: WingmanTokenSource
    public let total: Int64
    public let input: Int64?
    public let cachedInput: Int64?
    public let cacheWriteInput: Int64?
    public let output: Int64?
    public let reasoningOutput: Int64?

    public init(
        source: WingmanTokenSource,
        total: Int64,
        input: Int64? = nil,
        cachedInput: Int64? = nil,
        cacheWriteInput: Int64? = nil,
        output: Int64? = nil,
        reasoningOutput: Int64? = nil
    ) {
        self.source = source
        self.total = max(0, total)
        self.input = input.map { max(0, $0) }
        self.cachedInput = cachedInput.map { max(0, $0) }
        self.cacheWriteInput = cacheWriteInput.map { max(0, $0) }
        self.output = output.map { max(0, $0) }
        self.reasoningOutput = reasoningOutput.map { max(0, $0) }
    }

    public var hasBreakdown: Bool {
        input != nil && output != nil
    }
}

public enum WingmanPromptResponseState: String, Codable, Sendable {
    case responseRecorded
    case continuedAfterResponse
    case noRecordedResponse
    case unknown
}

public struct WingmanPromptEvidence: Codable, Equatable, Sendable {
    public let text: String
    public let occurredAt: Date?
    public let isExplicitQuestion: Bool
    public let isInvestigationRequest: Bool
    public let responseState: WingmanPromptResponseState

    public init(
        text: String,
        occurredAt: Date?,
        isExplicitQuestion: Bool,
        isInvestigationRequest: Bool,
        responseState: WingmanPromptResponseState
    ) {
        self.text = text
        self.occurredAt = occurredAt
        self.isExplicitQuestion = isExplicitQuestion
        self.isInvestigationRequest = isInvestigationRequest
        self.responseState = responseState
    }
}

public struct WingmanTaskEvidence: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let projectLabel: String
    public let createdAt: Date
    public let updatedAt: Date
    public let archived: Bool
    public let directTokenUsage: WingmanTokenUsage
    public let recursiveTokenTotal: Int64
    public let childCount: Int
    public let maximumBranchDepth: Int
    public let branchEvidence: [String]
    public let initialPrompt: String?
    public let promptSamples: [WingmanPromptEvidence]
    public let rolloutCoverage: WingmanEvidenceCoverage
    public let scannedRolloutBytes: Int64
    public let totalRolloutBytes: Int64
    public let activeBucketCountLowerBound: Int
    public let activeDayCountLowerBound: Int
    public let userMessageCountLowerBound: Int
    public let meaningfulAgentMessageCountLowerBound: Int
    public let toolCallCountLowerBound: Int
    public let completedTurnCountLowerBound: Int
    public let abortedTurnCountLowerBound: Int
    public let measuredAbortedTurnTokensLowerBound: Int64
    public let hasObservedOpenTurn: Bool

    /// The largest cumulative token counter observed anywhere in the task tree.
    /// Spawned rollouts share counter history, so descendant counters are not
    /// additive. This proxy avoids repeated shared-prefix counting, but is not
    /// an exact billed-token or wasted-token total.
    public var observedCumulativeTokenProxy: Int64 { recursiveTokenTotal }

    public init(
        id: String,
        title: String,
        projectLabel: String,
        createdAt: Date,
        updatedAt: Date,
        archived: Bool,
        directTokenUsage: WingmanTokenUsage,
        recursiveTokenTotal: Int64,
        childCount: Int,
        maximumBranchDepth: Int,
        branchEvidence: [String],
        initialPrompt: String?,
        promptSamples: [WingmanPromptEvidence],
        rolloutCoverage: WingmanEvidenceCoverage,
        scannedRolloutBytes: Int64,
        totalRolloutBytes: Int64,
        activeBucketCountLowerBound: Int,
        activeDayCountLowerBound: Int,
        userMessageCountLowerBound: Int,
        meaningfulAgentMessageCountLowerBound: Int,
        toolCallCountLowerBound: Int,
        completedTurnCountLowerBound: Int,
        abortedTurnCountLowerBound: Int,
        measuredAbortedTurnTokensLowerBound: Int64,
        hasObservedOpenTurn: Bool
    ) {
        self.id = id
        self.title = title
        self.projectLabel = projectLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archived = archived
        self.directTokenUsage = directTokenUsage
        self.recursiveTokenTotal = max(0, recursiveTokenTotal)
        self.childCount = max(0, childCount)
        self.maximumBranchDepth = max(0, maximumBranchDepth)
        self.branchEvidence = branchEvidence
        self.initialPrompt = initialPrompt
        self.promptSamples = promptSamples
        self.rolloutCoverage = rolloutCoverage
        self.scannedRolloutBytes = max(0, scannedRolloutBytes)
        self.totalRolloutBytes = max(0, totalRolloutBytes)
        self.activeBucketCountLowerBound = max(0, activeBucketCountLowerBound)
        self.activeDayCountLowerBound = max(0, activeDayCountLowerBound)
        self.userMessageCountLowerBound = max(0, userMessageCountLowerBound)
        self.meaningfulAgentMessageCountLowerBound = max(0, meaningfulAgentMessageCountLowerBound)
        self.toolCallCountLowerBound = max(0, toolCallCountLowerBound)
        self.completedTurnCountLowerBound = max(0, completedTurnCountLowerBound)
        self.abortedTurnCountLowerBound = max(0, abortedTurnCountLowerBound)
        self.measuredAbortedTurnTokensLowerBound = max(0, measuredAbortedTurnTokensLowerBound)
        self.hasObservedOpenTurn = hasObservedOpenTurn
    }
}

public struct WingmanEvidenceSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let taskActivityCutoff: Date?
    public let candidateTaskCount: Int
    public let lifetimeTokenTotalForScopedTasks: Int64
    public let tasks: [WingmanTaskEvidence]
    public let omittedTaskCount: Int

    public var scopeStart: Date? { taskActivityCutoff }
    public var scopeMeasuredTokenTotal: Int64 { lifetimeTokenTotalForScopedTasks }
    public var scopeObservedCumulativeTokenProxyTotal: Int64 {
        lifetimeTokenTotalForScopedTasks
    }

    public init(
        generatedAt: Date,
        taskActivityCutoff: Date?,
        candidateTaskCount: Int,
        lifetimeTokenTotalForScopedTasks: Int64,
        tasks: [WingmanTaskEvidence],
        omittedTaskCount: Int
    ) {
        self.generatedAt = generatedAt
        self.taskActivityCutoff = taskActivityCutoff
        self.candidateTaskCount = max(0, candidateTaskCount)
        self.lifetimeTokenTotalForScopedTasks = max(0, lifetimeTokenTotalForScopedTasks)
        self.tasks = tasks
        self.omittedTaskCount = max(0, omittedTaskCount)
    }

    public init(
        generatedAt: Date,
        scopeStart: Date?,
        candidateTaskCount: Int,
        scopeMeasuredTokenTotal: Int64,
        tasks: [WingmanTaskEvidence],
        omittedTaskCount: Int
    ) {
        self.init(
            generatedAt: generatedAt,
            taskActivityCutoff: scopeStart,
            candidateTaskCount: candidateTaskCount,
            lifetimeTokenTotalForScopedTasks: scopeMeasuredTokenTotal,
            tasks: tasks,
            omittedTaskCount: omittedTaskCount
        )
    }
}

public struct WingmanTaskAnalysis: Equatable, Sendable, Identifiable {
    public let id: String
    public let evidence: WingmanTaskEvidence
    public let relativeObservedActivityIndex: Double
    public let selectedThemes: [String]

    public var activityIndex: Double { relativeObservedActivityIndex }

    public init(
        id: String,
        evidence: WingmanTaskEvidence,
        relativeObservedActivityIndex: Double,
        selectedThemes: [String]
    ) {
        self.id = id
        self.evidence = evidence
        self.relativeObservedActivityIndex = relativeObservedActivityIndex.isFinite
            ? max(0, relativeObservedActivityIndex)
            : 0
        self.selectedThemes = selectedThemes
    }

    public init(
        id: String,
        evidence: WingmanTaskEvidence,
        activityIndex: Double,
        selectedThemes: [String]
    ) {
        self.init(
            id: id,
            evidence: evidence,
            relativeObservedActivityIndex: activityIndex,
            selectedThemes: selectedThemes
        )
    }
}

public struct WingmanThemeAnalysis: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let taskCount: Int
    public let curiosityWeight: Double
    public let workWeight: Double
    public let weightedDegree: Double
    public let pageRank: Double
    public let component: Int

    public init(
        id: String,
        label: String,
        taskCount: Int,
        curiosityWeight: Double,
        workWeight: Double,
        weightedDegree: Double,
        pageRank: Double,
        component: Int
    ) {
        self.id = id
        self.label = label
        self.taskCount = taskCount
        self.curiosityWeight = curiosityWeight
        self.workWeight = workWeight
        self.weightedDegree = weightedDegree
        self.pageRank = pageRank
        self.component = component
    }
}

public struct WingmanGraphEdge: Equatable, Sendable {
    public let sourceID: String
    public let targetID: String
    public let weight: Double

    public init(sourceID: String, targetID: String, weight: Double) {
        self.sourceID = sourceID
        self.targetID = targetID
        self.weight = weight.isFinite ? max(0, weight) : 0
    }
}

public struct WingmanQuestionBranch: Equatable, Sendable, Identifiable {
    public let id: String
    public let taskID: String
    public let taskTitle: String
    public let excerpt: String
    public let state: WingmanPromptResponseState
    public let isInvestigationRequest: Bool

    public init(
        id: String,
        taskID: String,
        taskTitle: String,
        excerpt: String,
        state: WingmanPromptResponseState,
        isInvestigationRequest: Bool
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.excerpt = excerpt
        self.state = state
        self.isInvestigationRequest = isInvestigationRequest
    }
}

public enum WingmanReviewSignalKind: String, Codable, Sendable {
    case abortedTurns
    case openTurns
    case highBranching
    case noContinuation
    case noRecordedResponse
    case similarWork
    case partialCoverage
}

public struct WingmanReviewSignal: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: WingmanReviewSignalKind
    public let title: String
    public let detail: String
    public let relatedTaskIDs: [String]

    public init(
        id: String,
        kind: WingmanReviewSignalKind,
        title: String,
        detail: String,
        relatedTaskIDs: [String]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.relatedTaskIDs = relatedTaskIDs
    }
}

public struct WingmanPortfolioAnalysis: Equatable, Sendable {
    public let generatedAt: Date
    public let taskActivityCutoff: Date?
    public let candidateTaskCount: Int
    public let omittedTaskCount: Int
    public let lifetimeTokenTotalForScopedTasks: Int64
    public let selectedTaskLifetimeTokenTotal: Int64
    public let measuredAbortedTurnTokensLowerBound: Int64
    public let completeCoverageTaskCount: Int
    public let partialCoverageTaskCount: Int
    public let tasks: [WingmanTaskAnalysis]
    public let themes: [WingmanThemeAnalysis]
    public let themeEdges: [WingmanGraphEdge]
    public let taskSimilarityEdges: [WingmanGraphEdge]
    public let questionBranches: [WingmanQuestionBranch]
    public let reviewSignals: [WingmanReviewSignal]
    public let recommendedNextMoves: [String]

    public var scopeStart: Date? { taskActivityCutoff }
    public var scopeMeasuredTokenTotal: Int64 { lifetimeTokenTotalForScopedTasks }
    public var selectedMeasuredTokenTotal: Int64 { selectedTaskLifetimeTokenTotal }
    public var scopeObservedCumulativeTokenProxyTotal: Int64 {
        lifetimeTokenTotalForScopedTasks
    }
    public var selectedObservedCumulativeTokenProxyTotal: Int64 {
        selectedTaskLifetimeTokenTotal
    }

    public init(
        generatedAt: Date,
        taskActivityCutoff: Date?,
        candidateTaskCount: Int,
        omittedTaskCount: Int,
        lifetimeTokenTotalForScopedTasks: Int64,
        selectedTaskLifetimeTokenTotal: Int64,
        measuredAbortedTurnTokensLowerBound: Int64,
        completeCoverageTaskCount: Int,
        partialCoverageTaskCount: Int,
        tasks: [WingmanTaskAnalysis],
        themes: [WingmanThemeAnalysis],
        themeEdges: [WingmanGraphEdge],
        taskSimilarityEdges: [WingmanGraphEdge],
        questionBranches: [WingmanQuestionBranch],
        reviewSignals: [WingmanReviewSignal],
        recommendedNextMoves: [String]
    ) {
        self.generatedAt = generatedAt
        self.taskActivityCutoff = taskActivityCutoff
        self.candidateTaskCount = max(0, candidateTaskCount)
        self.omittedTaskCount = max(0, omittedTaskCount)
        self.lifetimeTokenTotalForScopedTasks = max(0, lifetimeTokenTotalForScopedTasks)
        self.selectedTaskLifetimeTokenTotal = max(0, selectedTaskLifetimeTokenTotal)
        self.measuredAbortedTurnTokensLowerBound = max(0, measuredAbortedTurnTokensLowerBound)
        self.completeCoverageTaskCount = max(0, completeCoverageTaskCount)
        self.partialCoverageTaskCount = max(0, partialCoverageTaskCount)
        self.tasks = tasks
        self.themes = themes
        self.themeEdges = themeEdges
        self.taskSimilarityEdges = taskSimilarityEdges
        self.questionBranches = questionBranches
        self.reviewSignals = reviewSignals
        self.recommendedNextMoves = recommendedNextMoves
    }

    public init(
        generatedAt: Date,
        scopeStart: Date?,
        candidateTaskCount: Int,
        omittedTaskCount: Int,
        scopeMeasuredTokenTotal: Int64,
        selectedMeasuredTokenTotal: Int64,
        measuredAbortedTurnTokensLowerBound: Int64,
        completeCoverageTaskCount: Int,
        partialCoverageTaskCount: Int,
        tasks: [WingmanTaskAnalysis],
        themes: [WingmanThemeAnalysis],
        themeEdges: [WingmanGraphEdge],
        taskSimilarityEdges: [WingmanGraphEdge],
        questionBranches: [WingmanQuestionBranch],
        reviewSignals: [WingmanReviewSignal],
        recommendedNextMoves: [String]
    ) {
        self.init(
            generatedAt: generatedAt,
            taskActivityCutoff: scopeStart,
            candidateTaskCount: candidateTaskCount,
            omittedTaskCount: omittedTaskCount,
            lifetimeTokenTotalForScopedTasks: scopeMeasuredTokenTotal,
            selectedTaskLifetimeTokenTotal: selectedMeasuredTokenTotal,
            measuredAbortedTurnTokensLowerBound: measuredAbortedTurnTokensLowerBound,
            completeCoverageTaskCount: completeCoverageTaskCount,
            partialCoverageTaskCount: partialCoverageTaskCount,
            tasks: tasks,
            themes: themes,
            themeEdges: themeEdges,
            taskSimilarityEdges: taskSimilarityEdges,
            questionBranches: questionBranches,
            reviewSignals: reviewSignals,
            recommendedNextMoves: recommendedNextMoves
        )
    }
}

public struct WingmanAgentReview: Codable, Equatable, Sendable {
    public let portfolioSummary: String
    public let promptFindings: [String]
    public let harnessFindings: [String]
    public let unfinishedWork: [String]
    public let tokenFindings: [String]
    public let recommendations: [String]
    public let limitations: [String]

    public init(
        portfolioSummary: String,
        promptFindings: [String],
        harnessFindings: [String],
        unfinishedWork: [String],
        tokenFindings: [String],
        recommendations: [String],
        limitations: [String]
    ) {
        self.portfolioSummary = portfolioSummary
        self.promptFindings = promptFindings
        self.harnessFindings = harnessFindings
        self.unfinishedWork = unfinishedWork
        self.tokenFindings = tokenFindings
        self.recommendations = recommendations
        self.limitations = limitations
    }
}

public struct WingmanAgentUsage: Codable, Equatable, Sendable {
    public let inputTokens: Int64
    public let cachedInputTokens: Int64
    public let outputTokens: Int64
    public let reasoningOutputTokens: Int64

    public init(
        inputTokens: Int64,
        cachedInputTokens: Int64,
        outputTokens: Int64,
        reasoningOutputTokens: Int64
    ) {
        self.inputTokens = max(0, inputTokens)
        self.cachedInputTokens = max(0, cachedInputTokens)
        self.outputTokens = max(0, outputTokens)
        self.reasoningOutputTokens = max(0, reasoningOutputTokens)
    }
}
