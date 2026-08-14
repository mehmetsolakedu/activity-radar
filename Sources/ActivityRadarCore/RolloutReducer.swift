import Foundation

struct RolloutSummary {
    var openTurns: [String: Date] = [:]
    var pendingInputCallIDs = Set<String>()
    var lastActivityAt: Date?
    var lastUserMessageAt: Date?
    var lastMeaningfulAgentAt: Date?
    var lastFinalAnswerAt: Date?
    var lastTerminalAt: Date?
    var lastTerminalState: TerminalTurnState?
    var checkpoint: String?
    var historyComplete = true

    var earliestOpenTurnAt: Date? {
        openTurns.values.min()
    }
}

struct RolloutReducer {
    private(set) var summary = RolloutSummary()

    mutating func markHistoryIncomplete() {
        summary.historyComplete = false
    }

    mutating func consume(line: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            let timestampText = object["timestamp"] as? String,
            let timestamp = Self.parseDate(timestampText),
            let envelopeType = object["type"] as? String,
            let payload = object["payload"] as? [String: Any]
        else {
            return
        }

        summary.lastActivityAt = Self.latest(summary.lastActivityAt, timestamp)

        switch envelopeType {
        case "event_msg":
            consumeEvent(payload: payload, timestamp: timestamp)
        case "response_item":
            consumeResponseItem(payload: payload, timestamp: timestamp)
        default:
            break
        }
    }

    private mutating func consumeEvent(payload: [String: Any], timestamp: Date) {
        guard let type = payload["type"] as? String else { return }

        switch type {
        case "task_started":
            if let turnID = payload["turn_id"] as? String {
                summary.openTurns[turnID] = timestamp
            }
        case "task_complete":
            if let turnID = payload["turn_id"] as? String {
                summary.openTurns.removeValue(forKey: turnID)
            }
            if summary.openTurns.isEmpty {
                summary.pendingInputCallIDs.removeAll()
            }
            summary.lastTerminalAt = timestamp
            summary.lastTerminalState = .completed
        case "turn_aborted":
            if let turnID = payload["turn_id"] as? String {
                summary.openTurns.removeValue(forKey: turnID)
            }
            if summary.openTurns.isEmpty {
                summary.pendingInputCallIDs.removeAll()
            }
            summary.lastTerminalAt = timestamp
            summary.lastTerminalState = .aborted
        case "user_message":
            summary.lastUserMessageAt = Self.latest(summary.lastUserMessageAt, timestamp)
        case "agent_message":
            let phase = payload["phase"] as? String
            guard phase == "commentary" || phase == "final_answer" else { return }
            summary.lastMeaningfulAgentAt = Self.latest(summary.lastMeaningfulAgentAt, timestamp)
            if phase == "final_answer" {
                summary.lastFinalAnswerAt = Self.latest(summary.lastFinalAnswerAt, timestamp)
            }
            if let message = payload["message"] as? String,
               let cleaned = Self.cleanSummary(message) {
                summary.checkpoint = cleaned
            }
        default:
            break
        }
    }

    private mutating func consumeResponseItem(payload: [String: Any], timestamp: Date) {
        guard let type = payload["type"] as? String else { return }

        switch type {
        case "message":
            if payload["role"] as? String == "user" {
                summary.lastUserMessageAt = Self.latest(summary.lastUserMessageAt, timestamp)
            }
        case "function_call":
            if payload["name"] as? String == "request_user_input",
               let callID = (payload["call_id"] as? String) ?? (payload["id"] as? String) {
                summary.pendingInputCallIDs.insert(callID)
            }
        case "function_call_output":
            if let callID = payload["call_id"] as? String {
                summary.pendingInputCallIDs.remove(callID)
            }
        default:
            break
        }
    }

    static func parseDate(_ value: String) -> Date? {
        fractionalDateFormatter.date(from: value) ?? basicDateFormatter.date(from: value)
    }

    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let basicDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func latest(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else { return candidate }
        return max(current, candidate)
    }

    private static func cleanSummary(_ raw: String) -> String? {
        var text = ""
        for rawLine in raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.hasPrefix("```"), !line.hasPrefix("~~~") else { continue }

            line = line
                .replacingOccurrences(of: #"!\[[^\]]*\]\([^)]+\)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(
                    of: #"^\s{0,3}(?:[-+*]|\d+[.)]|>)\s+"#,
                    with: "",
                    options: .regularExpression
                )
                .replacingOccurrences(of: #"\*\*([^*\n]+)\*\*"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"__([^_\n]+)__"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"`+([^`\n]+)`+"#, with: "$1", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !line.isEmpty {
                text = line
                break
            }
        }

        guard !text.isEmpty else { return nil }
        if text.count > 180 {
            let end = text.index(text.startIndex, offsetBy: 177)
            return String(text[..<end]) + "…"
        }
        return text
    }
}
