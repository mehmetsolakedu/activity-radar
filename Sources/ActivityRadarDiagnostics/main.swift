import ActivityRadarCore
import Foundation

private struct ContentFreeDiagnosticReport: Encodable {
    let schemaVersion = 1
    let generatedAt: Date
    let itemCount: Int
    let hasMore: Bool
    let executionStateCounts: [String: Int]
    let attentionReasonCounts: [String: Int]
    let goalStatusCounts: [String: Int]
    let completeHistoryCount: Int
    let partialHistoryCount: Int
    let privacy: PrivacyBoundary

    struct PrivacyBoundary: Encodable {
        let includesTaskIdentifiers = false
        let includesTitlesOrMessages = false
        let includesFilePaths = false
        let includesCheckpoints = false
    }
}

private func counts<Value: RawRepresentable>(
    _ values: [Value]
) -> [String: Int] where Value.RawValue == String {
    Dictionary(grouping: values.map(\.rawValue), by: { $0 }).mapValues(\.count)
}

private func write(_ text: String, to handle: FileHandle) {
    handle.write(Data(text.utf8))
}

private func sanitizedDiagnosticError(_ error: Error) -> String {
    guard let readerError = error as? ActivityReaderError else {
        return "Activity Radar diagnostic failed without exposing local task data."
    }
    switch readerError {
    case .missingCodexState:
        return "Codex local state was not found at ~/.codex/state_5.sqlite. Open Codex and create at least one task first."
    case .sqliteOpen:
        return "Codex local state exists but could not be opened read-only."
    case .sqliteQuery:
        return "Codex local state opened, but its data could not be queried."
    case .incompatibleSchema(let detail):
        return "Codex local state uses an incompatible schema: \(detail)"
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.contains("-h") {
    write(
        "ActivityRadarDiagnostics emits aggregate, content-free local compatibility data.\n",
        to: .standardOutput
    )
    exit(0)
}

guard arguments.isEmpty else {
    write("Unknown argument. Use --help.\n", to: .standardError)
    exit(2)
}

do {
    let snapshot = try CodexActivityReader().load(limit: 200)
    let report = ContentFreeDiagnosticReport(
        generatedAt: snapshot.generatedAt,
        itemCount: snapshot.items.count,
        hasMore: snapshot.hasMore,
        executionStateCounts: counts(snapshot.items.map(\.executionState)),
        attentionReasonCounts: counts(snapshot.items.compactMap(\.attentionReason)),
        goalStatusCounts: counts(snapshot.items.compactMap(\.goalStatus)),
        completeHistoryCount: snapshot.items.filter(\.historyComplete).count,
        partialHistoryCount: snapshot.items.filter { !$0.historyComplete }.count,
        privacy: .init()
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    write(String(decoding: try encoder.encode(report), as: UTF8.self) + "\n", to: .standardOutput)
} catch {
    write(sanitizedDiagnosticError(error) + "\n", to: .standardError)
    exit(1)
}
