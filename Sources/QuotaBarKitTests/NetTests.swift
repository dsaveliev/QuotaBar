import Foundation
import QuotaBarKit

enum CredentialTests {
    static let home = URL(fileURLWithPath: "/Users/tester")

    private static func makeStore(
        authJSON: String?,
        env: [String: String] = [:]
    ) -> CredentialStore {
        let file = MemoryFile(authJSON.map { Data($0.utf8) })
        return CredentialStore(
            readFile: file.read,
            environment: { env[$0] }
        )
    }

    static let cases: [TestCase] = [
        ("the first auth.json key holding a non-empty value wins", {
            let store = makeStore(authJSON: #"{"zai-coding-plan": {"key": "first"}, "zai": {"key": "second"}}"#)
            Harness.expectEqual(
                store.resolve(for: ZaiProvider(), home: home)?.token, "first", "zai preference order"
            )
            Harness.expectEqual(
                store.resolve(for: MiniMaxProvider(), home: home)?.token, nil, "minimax has no entry here"
            )
        }),
        ("MiniMax falls through its keys in order", {
            let store = makeStore(authJSON: #"{"minimax": {"key": "third"}}"#)
            Harness.expectEqual(
                store.resolve(for: MiniMaxProvider(), home: home)?.token, "third", "last key"
            )
        }),
        ("a blank key falls through to the next entry", {
            let store = makeStore(authJSON: #"{"zai-coding-plan": {"key": "  "}, "zai": {"key": "used"}}"#)
            Harness.expectEqual(store.resolve(for: ZaiProvider(), home: home)?.token, "used", "skipped blank")
        }),
        ("the environment is consulted only when the file yields nothing", {
            let withFile = makeStore(
                authJSON: #"{"zai": {"key": "from-file"}}"#,
                env: ["ZAI_TOKEN": "from-env"]
            )
            Harness.expectEqual(
                withFile.resolve(for: ZaiProvider(), home: home)?.source, .authFile, "file wins"
            )

            let withoutFile = makeStore(authJSON: #"{"other": {"key": "x"}}"#, env: ["ZAI_TOKEN": "from-env"])
            Harness.expectEqual(
                withoutFile.resolve(for: ZaiProvider(), home: home)?.token, "from-env", "env fallback"
            )
            Harness.expectEqual(
                withoutFile.resolve(for: ZaiProvider(), home: home)?.source, .environment("ZAI_TOKEN"), "env source"
            )
        }),
        ("environment names are tried in declaration order", {
            let store = makeStore(authJSON: nil, env: ["Z_AI_TOKEN": "second-env"])
            Harness.expectEqual(
                store.resolve(for: ZaiProvider(), home: home)?.token, "second-env", "second env name"
            )
        }),
        ("a malformed credential file falls through to the environment silently", {
            let store = makeStore(authJSON: "{not json", env: ["ZAI_TOKEN": "from-env"])
            Harness.expectEqual(store.resolve(for: ZaiProvider(), home: home)?.token, "from-env", "env fallback")
            Harness.expect(!store.isAuthFileUnreadable(home: home), "a present malformed file is not 'unreadable'")
        }),
        ("an absent credential file is reported as unreadable and resolves nothing", {
            let store = makeStore(authJSON: nil, env: [:])
            Harness.expectEqual(store.resolve(for: ZaiProvider(), home: home)?.token, nil, "no token")
            Harness.expect(store.isAuthFileUnreadable(home: home), "absent file is unreadable")
        }),
        ("an entry without a string key contributes nothing", {
            let store = makeStore(authJSON: #"{"zai": {"key": 42}, "zai-coding-plan": "not-an-object"}"#)
            Harness.expectEqual(store.resolve(for: ZaiProvider(), home: home)?.token, nil, "no usable entry")
        }),
        ("the credential file lives at the OpenCode path", {
            Harness.expectEqual(
                CredentialStore.defaultAuthFileURL(home: home).path,
                "/Users/tester/.local/share/opencode/auth.json",
                "auth file path"
            )
        }),
    ]
}

enum QuotaHTTPClientTests {
    private static let endpoint = URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")!

    private static func client(
        _ transport: @escaping @Sendable (URL, String, Double) async throws -> TransportResponse
    ) -> QuotaHTTPClient {
        QuotaHTTPClient(timeoutMs: 8_000, transport: transport)
    }

    private static func code(
        of result: QuotaFetchResult
    ) -> String? {
        if case .failure(let error) = result { return error.code }
        return nil
    }

    static let cases: [TestCase] = [
        ("a 2xx JSON body is a success", {
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, _, _ in
                TransportResponse(status: 200, text: #"{"data":{"limits":[]}}"#)
            }
            guard case .success(let payload) = await client(transport).fetch(endpoint: endpoint, token: "t") else {
                return Harness.expect(false, "expected success")
            }
            Harness.expect(payload.value is [String: Any], "payload is a decoded object")
        }),
        ("the bearer token travels in the Authorization header only", {
            let box = TokenBox()
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, token, _ in
                box.record(token)
                return TransportResponse(status: 200, text: "{}")
            }
            _ = await client(transport).fetch(endpoint: endpoint, token: "secret-token")
            Harness.expectEqual(box.value, "secret-token", "token passed to transport")
        }),
        ("statuses at or above 400 become http-N", {
            for status in [400, 401, 403, 404, 429, 500, 503] {
                let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, _, _ in
                    TransportResponse(status: status, text: "{}")
                }
                Harness.expectEqual(
                    code(of: await client(transport).fetch(endpoint: endpoint, token: "t")),
                    "http-\(status)", "status \(status)"
                )
            }
        }),
        ("a non-JSON body becomes bad-json", {
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, _, _ in
                TransportResponse(status: 200, text: "<html>nope</html>")
            }
            Harness.expectEqual(
                code(of: await client(transport).fetch(endpoint: endpoint, token: "t")), "bad-json", "bad json"
            )
        }),
        ("a transport throw becomes a network error", {
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, _, _ in
                throw CocoaError(.fileNoSuchFile)
            }
            Harness.expectEqual(
                code(of: await client(transport).fetch(endpoint: endpoint, token: "t")), "network", "network"
            )
        }),
        ("a URL timeout becomes a timeout, distinctly from a network error", {
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, _, _ in
                throw URLError(.timedOut)
            }
            Harness.expectEqual(
                code(of: await client(transport).fetch(endpoint: endpoint, token: "t")), "timeout", "timeout"
            )
        }),
        ("a non-https endpoint is refused before any request is issued", {
            let box = TokenBox()
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, token, _ in
                box.record(token)
                return TransportResponse(status: 200, text: "{}")
            }
            let insecure = URL(string: "http://api.z.ai/api/monitor/usage/quota/limit")!
            Harness.expectEqual(
                code(of: await client(transport).fetch(endpoint: insecure, token: "t")),
                "insecure-endpoint", "insecure endpoint"
            )
            Harness.expectEqual(box.value, nil, "no request was issued")
        }),
        ("an error code never carries the token", {
            let transport: @Sendable (URL, String, Double) async throws -> TransportResponse = { _, _, _ in
                TransportResponse(status: 403, text: "forbidden")
            }
            let result = await client(transport).fetch(endpoint: endpoint, token: "super-secret-token")
            guard let code = code(of: result) else { return Harness.expect(false, "expected failure") }
            Harness.expect(!code.contains("super-secret-token"), "error code must not embed the token")
        }),
    ]
}

/// Captures the token a transport was handed, for header assertions.
final class TokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: String?

    func record(_ token: String) {
        lock.lock(); defer { lock.unlock() }
        recorded = token
    }

    var value: String? {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }
}