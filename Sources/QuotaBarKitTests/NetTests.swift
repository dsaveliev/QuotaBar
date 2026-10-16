import Foundation
import QuotaBarKit

enum CredentialTests {
    private static func makeStore(env: [String: String]) -> CredentialStore {
        CredentialStore(environment: { env[$0] })
    }

    static let cases: [TestCase] = [
        ("each provider reads only its own variable", {
            let store = makeStore(env: [
                "ZAI_TOKEN": "zai-value", "MINIMAX_TOKEN": "minimax-value",
            ])
            Harness.expectEqual(store.resolve(for: ZaiProvider())?.token, "zai-value", "zai")
            Harness.expectEqual(
                store.resolve(for: MiniMaxProvider())?.token, "minimax-value", "minimax"
            )
            Harness.expectEqual(
                store.resolve(for: ZaiProvider())?.source, .environment("ZAI_TOKEN"), "source"
            )
        }),
        ("a missing variable resolves nothing", {
            let store = makeStore(env: ["ZAI_TOKEN": "zai-value"])
            Harness.expectEqual(
                store.resolve(for: MiniMaxProvider())?.token, nil, "no minimax variable here"
            )
        }),
        ("a whitespace-only variable is not a credential", {
            let store = makeStore(env: ["ZAI_TOKEN": "   \n  "])
            Harness.expectEqual(
                store.resolve(for: ZaiProvider())?.token, nil, "blank resolves nothing"
            )
        }),
        ("the retired variable names are not read", {
            let store = makeStore(env: [
                "Z_AI_TOKEN": "old", "MINIMAX_API_KEY": "old",
            ])
            Harness.expectEqual(store.resolve(for: ZaiProvider())?.token, nil, "Z_AI_TOKEN ignored")
            Harness.expectEqual(
                store.resolve(for: MiniMaxProvider())?.token, nil, "MINIMAX_API_KEY ignored"
            )
        }),
        ("no credential file is consulted at all", {
            // The store no longer takes a file reader, so it cannot open one.
            // The provider is the only thing that says where a token may come
            // from, and it names one variable.
            Harness.expectEqual(ZaiProvider().tokenEnvNames, ["ZAI_TOKEN"], "zai")
            Harness.expectEqual(MiniMaxProvider().tokenEnvNames, ["MINIMAX_TOKEN"], "minimax")
        }),
        ("the missing-token messages are parallel", {
            let zai = QuotaErrorCode.displayText(
                for: QuotaErrorCode.noToken.rawValue, provider: ZaiProvider()
            )
            let mini = QuotaErrorCode.displayText(
                for: QuotaErrorCode.noToken.rawValue, provider: MiniMaxProvider()
            )
            Harness.expect(zai.contains("ZAI_TOKEN") && zai.contains("install.sh"), "zai names the step")
            Harness.expect(mini.contains("MINIMAX_TOKEN") && mini.contains("install.sh"), "minimax too")
            Harness.expectEqual(
                zai.replacingOccurrences(of: "ZAI_TOKEN", with: "VARIABLE"),
                mini.replacingOccurrences(of: "MINIMAX_TOKEN", with: "VARIABLE"),
                "identical but for the variable"
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