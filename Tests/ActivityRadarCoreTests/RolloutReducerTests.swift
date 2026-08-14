#if canImport(Testing)
import Foundation
import Testing
@testable import ActivityRadarCore

@Test
func turnLifecycleAndFinalAnswer() {
    var reducer = RolloutReducer()
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#))
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:05.000Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Görev tamamlandı."}}"#))

    #expect(reducer.summary.openTurns.count == 1)
    #expect(reducer.summary.checkpoint == "Görev tamamlandı.")
    #expect(reducer.summary.lastFinalAnswerAt != nil)

    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:06.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#))

    #expect(reducer.summary.openTurns.isEmpty)
    #expect(reducer.summary.lastTerminalState == .completed)
}

@Test
func concurrentTurnsLeaveOneOpen() {
    var reducer = RolloutReducer()
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#))
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:01.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-2"}}"#))
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:02.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#))

    #expect(Set(reducer.summary.openTurns.keys) == Set(["turn-2"]))
}

@Test
func pendingInputClearsOnlyWithMatchingOutput() {
    var reducer = RolloutReducer()
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input","call_id":"call-1"}}"#))
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:01.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"other"}}"#))

    #expect(reducer.summary.pendingInputCallIDs == Set(["call-1"]))

    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:02.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call-1"}}"#))
    #expect(reducer.summary.pendingInputCallIDs.isEmpty)
}

@Test
func abortedTurn() {
    var reducer = RolloutReducer()
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#))
    reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:03.000Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1"}}"#))

    #expect(reducer.summary.openTurns.isEmpty)
    #expect(reducer.summary.lastTerminalState == .aborted)
}

@Test
func codexDeepLinkContract() throws {
    let url = try #require(CodexActivityReader.deepLink(for: "123e4567-e89b-42d3-a456-426614174000"))
    #expect(url.absoluteString == "codex://threads/123e4567-e89b-42d3-a456-426614174000")
}

@Test
func pausedGoalRemainsParkedDespiteRolloutActivity() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    var summary = RolloutSummary()
    summary.lastActivityAt = now.addingTimeInterval(-5)

    let reason = ActivityAttentionPolicy.reason(
        summary: summary,
        goalStatus: .paused,
        viewedAt: now.addingTimeInterval(-60),
        unviewedResultsAfter: nil,
        now: now
    )

    #expect(reason == nil)
}

@Test
func markdownCleanupKeepsTechnicalCharacters() {
    var reducer = RolloutReducer()
    reducer.consume(
        line: data(
            #"{"timestamp":"2026-07-27T10:00:05.000Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"**Hedef Tamamlandı** C# #42 5*3 *.pdf"}}"#
        )
    )

    #expect(reducer.summary.checkpoint == "Hedef Tamamlandı C# #42 5*3 *.pdf")
}

private func data(_ value: String) -> Data {
    Data(value.utf8)
}
#endif
