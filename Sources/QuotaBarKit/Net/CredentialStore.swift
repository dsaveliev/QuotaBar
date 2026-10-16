import Foundation

/// Resolves a subscription's bearer token.
///
/// The OpenCode credential file is opened read-only on every refresh, so a
/// login performed after the agent started is picked up on the next tick. The
/// token is returned to the caller and nowhere else: it is never stored on
/// disk, never rendered, and never included in an error.
public struct CredentialStore: Sendable {
    public enum Source: Sendable, Equatable {
        case authFile
        case environment(String)
    }

    public struct Resolved: Sendable, Equatable {
        public let token: String
        public let source: Source
    }

    /// `~/.local/share/opencode/auth.json` — the file OpenCode itself uses.
    public static func defaultAuthFileURL(home: URL) -> URL {
        home
            .appending(path: ".local", directoryHint: .isDirectory)
            .appending(path: "share", directoryHint: .isDirectory)
            .appending(path: "opencode", directoryHint: .isDirectory)
            .appending(path: "auth.json", directoryHint: .notDirectory)
    }

    private let readFile: @Sendable (URL) throws -> Data
    private let environment: @Sendable (String) -> String?

    public init(
        readFile: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        environment: @escaping @Sendable (String) -> String? = { ProcessInfo.processInfo.environment[$0] }
    ) {
        self.readFile = readFile
        self.environment = environment
    }

    /// Precedence: the provider's auth.json keys in order, then its environment
    /// variable names in order. First hit wins.
    public func resolve(
        for provider: any QuotaProvider,
        home: URL
    ) -> Resolved? {
        if let key = tokenFromAuthFile(provider: provider, home: home) {
            return Resolved(token: key, source: .authFile)
        }
        for name in provider.tokenEnvNames {
            if let value = environment(name), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return Resolved(token: value, source: .environment(name))
            }
        }
        return nil
    }

    /// Whether the credential file itself could not be read, as opposed to
    /// being readable but holding no entry for this provider. Only the former
    /// is worth telling the user about; a present-but-malformed file falls
    /// through to the environment silently, as the spec requires.
    public func isAuthFileUnreadable(home: URL) -> Bool {
        (try? readFile(Self.defaultAuthFileURL(home: home))) == nil
    }

    private func tokenFromAuthFile(provider: any QuotaProvider, home: URL) -> String? {
        let url = Self.defaultAuthFileURL(home: home)
        guard let data = try? readFile(url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }

        for key in provider.authKeys {
            guard let entry = JSON.dictionary(root[key]),
                  let token = JSON.string(entry["key"]),
                  !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            return token
        }
        return nil
    }
}