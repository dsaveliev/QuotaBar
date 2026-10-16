import Foundation

/// User-configurable settings, persisted between launches.
public struct Settings: Codable, Sendable, Equatable {
    /// Supported refresh cadence range, in milliseconds.
    public static let minimumIntervalMs: Double = 10_000
    public static let maximumIntervalMs: Double = Double(Int32.max)
    public static let defaultIntervalMs: Double = 60_000

    public var intervalMs: Double
    /// Provider ids the user has taken out of the menu bar.
    public var hiddenSubscriptions: Set<String>
    /// Which provider the single menu bar item and the panel are currently
    /// showing. Absent means "no preference yet", which resolves to the first
    /// provider that is not hidden.
    public var selectedProviderId: String?

    public init(
        intervalMs: Double = Settings.defaultIntervalMs,
        hiddenSubscriptions: Set<String> = [],
        selectedProviderId: String? = nil
    ) {
        self.intervalMs = intervalMs
        self.hiddenSubscriptions = hiddenSubscriptions
        self.selectedProviderId = selectedProviderId
    }

    /// Clamps the interval into the supported range. A non-finite or
    /// out-of-range value is corrected rather than rejected, so a corrupted
    /// settings file cannot stop the agent from polling.
    public mutating func clamp() {
        guard intervalMs.isFinite else {
            intervalMs = Self.defaultIntervalMs
            return
        }
        intervalMs = min(Self.maximumIntervalMs, max(Self.minimumIntervalMs, intervalMs))
    }

    /// Choose which provider the menu bar item and panel show. Passing nil
    /// means "none", which leaves only the recovery item.
    public mutating func selectProvider(_ providerId: String?) {
        selectedProviderId = providerId
    }

    /// Hide or show a subscription's menu bar item.
    ///
    /// Hiding every subscription is permitted. The app stays reachable because
    /// the surface keeps a single recovery item in the menu bar while nothing
    /// is selected — refusing the last hide would answer a toggle's "yes" with a
    /// silent "no", which is worse than letting the user empty the bar and
    /// giving them an obvious way back.
    public mutating func setHidden(_ hidden: Bool, providerId: String) {
        if hidden {
            hiddenSubscriptions.insert(providerId)
        } else {
            hiddenSubscriptions.remove(providerId)
        }
    }

    public func isHidden(_ providerId: String) -> Bool {
        hiddenSubscriptions.contains(providerId)
    }
}

/// Reads and writes settings as JSON, tolerating a corrupt or partial file.
public struct SettingsStore: Sendable {
    private let url: URL
    private let readFile: @Sendable (URL) throws -> Data
    private let writeFile: @Sendable (Data, URL) throws -> Void

    public init(
        url: URL,
        readFile: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        writeFile: @escaping @Sendable (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.url = url
        self.readFile = readFile
        self.writeFile = writeFile
    }

    public func load() -> Settings {
        guard let data = try? readFile(url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return Settings() }

        var settings = Settings()
        if let interval = JSON.finiteNumber(root["intervalMs"]) { settings.intervalMs = interval }
        if let hidden = root["hiddenSubscriptions"] as? [String] {
            settings.hiddenSubscriptions = Set(hidden)
        }
        settings.selectedProviderId = root["selectedProviderId"] as? String
        settings.clamp()
        return settings
    }

    public func save(_ settings: Settings) {
        var clamped = settings
        clamped.clamp()
        var payload: [String: Any] = [
            "intervalMs": clamped.intervalMs,
            "hiddenSubscriptions": clamped.hiddenSubscriptions.sorted(),
        ]
        if let selected = clamped.selectedProviderId {
            payload["selectedProviderId"] = selected
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? writeFile(data, url)
    }
}

/// `~/Library/Application Support/QuotaBar`, the only directory this app writes.
public enum AppPaths {
    public static func directory(home: URL) -> URL {
        home
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Application Support", directoryHint: .isDirectory)
            .appending(path: "QuotaBar", directoryHint: .isDirectory)
    }

    public static func ensureDirectory(at url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}