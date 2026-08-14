import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(64)
}

do {
    let logURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let data = try Data(contentsOf: logURL)
    guard
        let log = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        log["status"] as? String == "Accepted",
        log.keys.contains("issues")
    else {
        exit(1)
    }

    let issues = log["issues"]!
    let hasNoIssues = issues is NSNull || ((issues as? [Any])?.isEmpty == true)
    exit(hasNoIssues ? 0 : 1)
} catch {
    exit(1)
}
