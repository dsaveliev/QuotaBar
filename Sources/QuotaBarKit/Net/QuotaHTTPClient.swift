import Foundation

/// Transport result: status and body text, with the timeout already applied.
public struct TransportResponse: Sendable {
    public let status: Int
    public let text: String

    public init(status: Int, text: String) {
        self.status = status
        self.text = text
    }
}

public enum QuotaFetchError: Error, Equatable, Sendable {
    /// The token was not found; no request was issued.
    case noToken
    case insecureEndpoint
    case network
    case http(Int)
    case badJSON
    case timeout

    public var code: String {
        switch self {
        case .noToken: QuotaErrorCode.noToken.rawValue
        case .insecureEndpoint: QuotaErrorCode.insecureEndpoint.rawValue
        case .network: QuotaErrorCode.network.rawValue
        case .http(let status): QuotaErrorCode.http(status)
        case .badJSON: QuotaErrorCode.badJSON.rawValue
        case .timeout: QuotaErrorCode.timeout.rawValue
        }
    }
}

/// A decoded JSON payload.
///
/// `JSONSerialization` produces nested `NSDictionary`/`NSArray` containers,
/// which Swift cannot prove `Sendable`. They are immutable value-bridged
/// containers here — nothing mutates a payload after decoding — so the
/// unchecked conformance is sound for the one hop between the fetch and the
/// provider's parser.
public struct JSONPayload: @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }
}

public enum QuotaFetchResult: Sendable {
    case success(payload: JSONPayload)
    case failure(QuotaFetchError)
}

/// Single shared fetch wrapper. Each provider supplies its own endpoint and
/// bearer token; this owns timeout, abort, https enforcement, and HTTP-status
/// translation. Payload semantics (MiniMax's `base_resp.status_code`) are the
/// provider's own predicate, applied by the engine after this returns.
public struct QuotaHTTPClient: Sendable {
    public typealias Transport = @Sendable (URL, String, Double) async throws -> TransportResponse

    private let transport: Transport
    public let timeoutMs: Double

    public init(timeoutMs: Double, transport: Transport? = nil) {
        self.timeoutMs = timeoutMs
        if let transport {
            self.transport = transport
        } else {
            self.transport = { url, token, timeoutMs in
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = timeoutMs / 1000
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = timeoutMs / 1000
                configuration.timeoutIntervalForResource = timeoutMs / 1000
                let session = URLSession(configuration: configuration)
                defer { session.finishTasksAndInvalidate() }

                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw QuotaFetchError.network
                }
                return TransportResponse(
                    status: http.statusCode,
                    text: String(decoding: data, as: UTF8.self)
                )
            }
        }
    }

    public func fetch(endpoint: URL, token: String) async -> QuotaFetchResult {
        guard let scheme = endpoint.scheme?.lowercased(), scheme == "https" else {
            return .failure(.insecureEndpoint)
        }

        do {
            let response = try await transport(endpoint, token, timeoutMs)
            if response.status >= 400 { return .failure(.http(response.status)) }
            guard let payload = try? JSONSerialization.jsonObject(
                with: Data(response.text.utf8),
                options: [.fragmentsAllowed]
            ) else {
                return .failure(.badJSON)
            }
            return .success(payload: JSONPayload(payload))
        } catch let error as QuotaFetchError {
            return .failure(error)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .failure(.timeout)
            case .cancelled:
                return .failure(.timeout)
            default:
                return .failure(.network)
            }
        } catch {
            return .failure(.network)
        }
    }
}