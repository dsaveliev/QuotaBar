import Foundation
import QuotaBarKit

/// A self-contained test harness.
///
/// This toolchain ships neither XCTest nor the swift-testing module, so
/// `swift test` cannot run. The suite is therefore an ordinary executable:
/// cases are async closures, failures are collected per case so one broken
/// expectation does not hide the rest, and the process exits non-zero if any
/// case failed.
///
/// Failures are collected behind a lock. Deliberately NOT actor-isolated: a test
/// body awaits engine actors, and an actor-isolated reporter would force every
/// case closure to inherit main-actor isolation.
final class HarnessState: @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [String] = []
    private var currentCase = ""
    private(set) var caseCount = 0

    func begin(_ name: String) {
        lock.lock(); defer { lock.unlock() }
        currentCase = name
        caseCount += 1
    }

    func fail(_ message: String) {
        lock.lock(); defer { lock.unlock() }
        failures.append("  ✗ \(currentCase)\n      \(message)")
    }

    func failureCount() -> Int {
        lock.lock(); defer { lock.unlock() }
        return failures.count
    }

    func report() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return failures
    }
}

enum Harness {
    static let state = HarnessState()

    static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if !condition() {
            let location = "\(URL(fileURLWithPath: "\(file)").lastPathComponent):\(line)"
            state.fail("\(message())  [\(location)]")
        }
    }

    static func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        expect(actual == expected, "\(label): expected \(expected), got \(actual)", file: file, line: line)
    }

    static func run(_ cases: [TestCase]) async -> Never {
        for (name, body) in cases {
            state.begin(name)
            let before = state.failureCount()
            do {
                try await body()
            } catch {
                state.fail("threw \(error)")
            }
            if state.failureCount() == before {
                print("  ✓ \(name)")
            }
        }

        let failures = state.report()
        print("")
        if failures.isEmpty {
            print("PASS  \(state.caseCount) cases")
            exit(0)
        }
        print("FAILURES (\(failures.count) of \(state.caseCount) cases):")
        for failure in failures { print(failure) }
        exit(1)
    }
}

/// A named async case. `@Sendable` keeps the suite tables safe as globals and
/// stops case bodies from inheriting any ambient actor isolation.
typealias TestCase = (name: String, body: @Sendable () async throws -> Void)

/// Directory containing this file, used to reach the repository's `Fixtures/`.
enum Fixtures {
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // QuotaBarKitTests
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // package root
            .appending(path: "Fixtures", directoryHint: .isDirectory)
    }

    static func json(_ name: String) throws -> [String: Any] {
        let url = directory.appending(path: name)
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HarnessError.badFixture(name)
        }
        return root
    }

    enum HarnessError: Error { case badFixture(String) }
}

/// A clock the tests drive by hand, so no case depends on wall-clock timing.
final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: EpochMillis

    init(_ start: EpochMillis) { value = start }

    var now: EpochMillis {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ newValue: EpochMillis) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }

    func advance(by delta: Double) {
        lock.lock(); defer { lock.unlock() }
        value += delta
    }
}

/// In-memory stand-in for a file the stores read and write.
final class MemoryFile: @unchecked Sendable {
    private let lock = NSLock()
    private var contents: Data?

    init(_ contents: Data? = nil) { self.contents = contents }

    var read: @Sendable (URL) throws -> Data {
        { _ in
            self.lock.lock(); defer { self.lock.unlock() }
            guard let contents = self.contents else {
                throw CocoaError(.fileNoSuchFile)
            }
            return contents
        }
    }

    var write: @Sendable (Data, URL) throws -> Void {
        { data, _ in
            self.lock.lock(); defer { self.lock.unlock() }
            self.contents = data
        }
    }

    var stored: Data? {
        lock.lock(); defer { lock.unlock() }
        return contents
    }
}