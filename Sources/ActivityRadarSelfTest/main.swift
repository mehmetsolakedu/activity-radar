import ActivityRadarCore
import Foundation

do {
    let passed = try ActivityRadarSelfTests.run()
    for test in passed {
        print("PASS  \(test)")
    }
    print("PASS  \(passed.count)/\(passed.count) self-tests")
} catch {
    FileHandle.standardError.write(Data("FAIL  \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
