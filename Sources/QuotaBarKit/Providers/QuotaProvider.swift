import Foundation

/// A registered coding-plan subscription.
///
/// The contract is deliberately small: only what the parsers and the engine
/// cannot infer from a payload. Adding a subscription means adding one of these
/// and one entry in `ProviderRegistry` — nothing else changes.
public protocol QuotaProvider: Sendable {
    /// Stable id, used as the history and settings key.
    var id: String { get }
    /// Short tag shown in the menu bar, e.g. `zai`.
    var tag: String { get }
    /// Human-readable name for the dropdown header.
    var displayName: String { get }
    /// The environment variable holding this subscription's bearer token.
    var tokenEnvNames: [String] { get }
    /// Endpoint hosts probed in declaration order; the first successful one is
    /// remembered for the lifetime of the process.
    var endpoints: [URL] { get }
    /// Translate a decoded payload into unified rows.
    func parse(_ payload: Any) -> [QuotaRow]
    /// Whether a decoded payload carries a success status. Providers whose
    /// failure is signalled inside a 200 body (MiniMax's `base_resp`) answer
    /// false here so the engine falls through to the next endpoint.
    func isSuccessPayload(_ payload: Any) -> Bool
    /// True when the payload is well-formed but carries no usable plan entry.
    func isEmptyPayload(_ payload: Any) -> Bool
    /// User-facing text for an error code.
    func errorText(_ code: QuotaErrorCode) -> String
}

public enum QuotaErrorCode: String, Sendable, Equatable {
    case noToken = "no-token"
    case insecureEndpoint = "insecure-endpoint"
    case network
    case badJSON = "bad-json"
    case timeout
    case empty

    public static func http(_ status: Int) -> String { "http-\(status)" }

    /// Every code the UI can render as text, including the parameterised one.
    public static func displayText(for code: String, provider: QuotaProvider) -> String {
        if code.hasPrefix("http-") { return code }
        return provider.errorText(QuotaErrorCode(rawValue: code) ?? .network)
    }
}

public enum ProviderRegistry {
    public static let all: [any QuotaProvider] = [ZaiProvider(), MiniMaxProvider()]

    /// Resolve an OpenCode provider id to a registered subscription. Exact and
    /// case-sensitive, matching the plugin's registry.
    public static func resolve(providerId: String?) -> (any QuotaProvider)? {
        guard let providerId else { return nil }
        for provider in ZaiProvider.aliases where provider == providerId { return ZaiProvider() }
        for provider in MiniMaxProvider.aliases where provider == providerId { return MiniMaxProvider() }
        return nil
    }
}

// MARK: - JSON access helpers
//
// The providers parse untyped JSON, so these keep `as? [String: Any]` casts in
// one place instead of scattering optional unwraps through each parser.

enum JSON {
    static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    static func array(_ value: Any?) -> [Any]? {
        value as? [Any]
    }

    static func finiteNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }
}