import Foundation
#if canImport(Testing)
import Testing
@testable import ActivityRadarCore

@Test
func wingmanReviewRejectsUnsupportedExactWasteClaim() throws {
    let review = WingmanAgentReview(
        portfolioSummary: "Portföy betimlemesi",
        promptFindings: [],
        harnessFindings: [],
        unfinishedWork: [],
        tokenFindings: ["Kesin olarak 123 token boşa gitti."],
        recommendations: ["Bir sonraki işi sınırla."],
        limitations: ["Kapsam kısmi olabilir."]
    )
    let data = try JSONEncoder().encode(review)

    #expect(throws: WingmanCodexContractError.self) {
        try WingmanCodexContract.decodeReview(data)
    }
}

@Test
func wingmanJSONLParserRejectsUnknownEventsFailClosed() throws {
    var parser = WingmanCodexJSONLParser()
    let event = try JSONSerialization.data(
        withJSONObject: ["type": "future.tool.started"],
        options: [.sortedKeys]
    )

    parser.consume(line: event)

    #expect(parser.failure == .forbiddenToolEvent("future.tool.started"))
}

@Test
func wingmanJSONLParserRejectsUnknownItemLifecycleWithAgentMessage() throws {
    var parser = WingmanCodexJSONLParser()
    let event = try JSONSerialization.data(
        withJSONObject: [
            "type": "item.future_unknown",
            "item": [
                "type": "agent_message",
                "text": "This must not be accepted as a review."
            ]
        ],
        options: [.sortedKeys]
    )

    parser.consume(line: event)

    #expect(parser.failure == .forbiddenToolEvent("item.future_unknown"))
    #expect(parser.finalReviewData == nil)
}

@Test
func wingmanPacketNamesTokenProxyAndRelativeMetricsHonestly() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let analysis = WingmanPortfolioAnalyzer.analyze(
        WingmanEvidenceSnapshot(
            generatedAt: now,
            scopeStart: now.addingTimeInterval(-90 * 24 * 60 * 60),
            candidateTaskCount: 1,
            scopeMeasuredTokenTotal: 1_000,
            tasks: [contractFixtureTask(id: "W001", title: "Sulama", tokens: 1_000)],
            omittedTaskCount: 0
        )
    )
    let data = try WingmanAgentPacketBuilder.encode(
        WingmanAgentPacketBuilder.make(
            analysis: analysis,
            includePromptExcerpts: false,
            responseLanguage: "en"
        )
    )
    let text = String(decoding: data, as: UTF8.self)

    #expect(text.contains("candidateTreesObservedCumulativeTokenProxyTotal"))
    #expect(text.contains("selectedTreesObservedCumulativeTokenProxyTotal"))
    #expect(text.contains("observedCumulativeTokenProxy"))
    #expect(text.contains("relativeObservedActivityIndex"))
    #expect(text.contains("taskActivityCutoff"))
    #expect(text.contains("selectedTreeCount"))
    #expect(text.contains("detailedTreeCount"))
    #expect(text.contains("omittedDetailedTreeCount"))
    #expect(text.contains(#""schemaVersion" : 6"#))
    #expect(text.contains(#""responseLanguage" : "en""#))
    #expect(text.contains("Date selection brings task trees into scope"))
    #expect(!text.contains("Tarih seçimi görev ağaçlarını"))
    #expect(!text.lowercased().contains("book"))
    #expect(!text.contains("activityIndexLowerBound"))
    #expect(!text.contains("measuredRecursiveTokens"))
    #expect(!text.contains("candidateTreesLifetimeMeasuredTotal"))
    #expect(!text.contains("scopeMeasuredTotal"))
    #expect(!text.contains("scopeStart"))
}

@Test
func wingmanPacketPreviewIsTheExactOutboundJSON() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let analysis = WingmanPortfolioAnalyzer.analyze(
        WingmanEvidenceSnapshot(
            generatedAt: now,
            taskActivityCutoff: nil,
            candidateTaskCount: 1,
            lifetimeTokenTotalForScopedTasks: 1_000,
            tasks: [contractFixtureTask(id: "W001", title: "Sulama", tokens: 1_000)],
            omittedTaskCount: 0
        )
    )

    let withoutPrompts = try WingmanAgentPacketBuilder.preview(
        analysis: analysis,
        includePromptExcerpts: false
    )
    let withPrompts = try WingmanAgentPacketBuilder.preview(
        analysis: analysis,
        includePromptExcerpts: true
    )
    let expectedData = try WingmanAgentPacketBuilder.encode(
        WingmanAgentPacketBuilder.make(analysis: analysis, includePromptExcerpts: true)
    )

    #expect(withoutPrompts.promptExcerptCount == 0)
    #expect(withoutPrompts.themeCount == 0)
    #expect(!withoutPrompts.packetJSON.lowercased().contains("sulama sensörlerini karşılaştır ve araştır?"))
    let withoutPromptPacket = WingmanAgentPacketBuilder.make(
        analysis: analysis,
        includePromptExcerpts: false
    )
    #expect(withoutPromptPacket.tasks.allSatisfy { $0.themes.isEmpty })
    #expect(withoutPromptPacket.themes.isEmpty)
    #expect(withoutPromptPacket.localReviewSignals.isEmpty)
    #expect(withoutPromptPacket.localNextMoves.isEmpty)
    #expect(withPrompts.promptExcerptCount == 1)
    #expect(withPrompts.themeCount > 0)
    #expect(withPrompts.selectedTaskCount == 1)
    #expect(withPrompts.detailedTaskCount == 1)
    #expect(withPrompts.omittedDetailedTaskCount == 0)
    #expect(withPrompts.utf8Bytes == expectedData.count)
    #expect(withPrompts.packetJSON == String(decoding: expectedData, as: UTF8.self))
    #expect(withPrompts.packetJSON.contains("\n  \"tasks\""))
}

private func contractFixtureTask(
    id: String,
    title: String,
    tokens: Int64
) -> WingmanTaskEvidence {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let prompt = "Sulama sensörlerini karşılaştır ve araştır?"
    return WingmanTaskEvidence(
        id: id,
        title: title,
        projectLabel: "Fixture",
        createdAt: now.addingTimeInterval(-3_600),
        updatedAt: now,
        archived: false,
        directTokenUsage: WingmanTokenUsage(source: .sqliteMeasuredTotal, total: tokens),
        recursiveTokenTotal: tokens,
        childCount: 0,
        maximumBranchDepth: 0,
        branchEvidence: [],
        initialPrompt: prompt,
        promptSamples: [
            WingmanPromptEvidence(
                text: prompt,
                occurredAt: now,
                isExplicitQuestion: true,
                isInvestigationRequest: true,
                responseState: .responseRecorded
            )
        ],
        rolloutCoverage: .complete,
        scannedRolloutBytes: 1_000,
        totalRolloutBytes: 1_000,
        activeBucketCountLowerBound: 2,
        activeDayCountLowerBound: 1,
        userMessageCountLowerBound: 1,
        meaningfulAgentMessageCountLowerBound: 1,
        toolCallCountLowerBound: 1,
        completedTurnCountLowerBound: 1,
        abortedTurnCountLowerBound: 0,
        measuredAbortedTurnTokensLowerBound: 0,
        hasObservedOpenTurn: false
    )
}

#endif
