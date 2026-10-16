import Foundation

/// Resolves a subscription's bearer token.
///
/// The environment is the only source. An earlier version also read a
/// credential file written by another tool, which made this app depend on that
/// tool's data layout and produced a precedence to reason about; both are gone.
///
/// The app resolves on every refresh, so a variable present in its environment
/// is picked up without a restart. The token goes no further: it is not stored,
/// not logged, and not rendered. Where it is persisted for the login agent is
/// the installer's business — see `scripts/install.sh`.
public struct CredentialStore: Sendable {
    public enum Source: Sendable, Equatable {
        case environment(String)
    }

    public struct Resolved: Sendable, Equatable {
        public let token: String
        public let source: Source
    }

    private let environment: @Sendable (String) -> String?

    public init(
        environment: @escaping @Sendable (String) -> String? = { ProcessInfo.processInfo.environment[$0] }
    ) {
        self.environment = environment
    }

    /// The subscription's own variable, if it holds something. Whitespace is
    /// not a token, and a blank variable resolves nothing rather than producing a
    /// header that is guaranteed to fail with a confusing status.
    public func resolve(for provider: any QuotaProvider) -> Resolved? {
        for name in provider.tokenEnvNames {
            guard let value = environment(name),
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            return Resolved(token: value, source: .environment(name))
        }
        return nil
    }
}