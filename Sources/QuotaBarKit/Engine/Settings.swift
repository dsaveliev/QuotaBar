import Foundation

/// User-configurable settings, persisted between launches.
/// Persistence is hand-rolled in `SettingsStore` because the file has to
/// survive being truncated, partially written, or edited by hand. Synthesised
/// `Codable` would do none of that, so it is deliberately absent.
public struct Settings: Sendable, Equatable {
    /// Supported refresh cadence range, in milliseconds.
    public static let minimumIntervalMs: Double = 10_000
    public static let maximumIntervalMs: Double = Double(Int32.max)
    public static let defaultIntervalMs: Double = 60_000

    public var intervalMs: Double
    /// Which provider the single menu bar item and the panel show.
    ///
    /// Three states, not two. "No preference yet" and "the user chose to show
    /// nothing" are different decisions that resolve differently, and they used
    /// to share one representation - `nil` meaning both - which is why choosing
    /// `Show none` silently fell back to the first provider.
    public var selection: ProviderSelection

    public init(
        intervalMs: Double = Settings.defaultIntervalMs,
        selection: ProviderSelection = .automatic
    ) {
        self.intervalMs = intervalMs
        self.selection = selection
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

    /// Choose which provider the menu bar item and panel show. Passing nil is
    /// the picker's `Show none`, which leaves only the recovery item — it is a
    /// choice the user made, not the absence of one.
    public mutating func selectProvider(_ providerId: String?) {
        selection = providerId.map(ProviderSelection.provider) ?? .none
    }
}

/// What the menu bar shows. See `Settings.selection`.
public enum ProviderSelection: Equatable, Sendable {
    /// Nothing recorded yet: show the first available provider.
    case automatic
    /// Show this provider.
    case provider(String)
    /// The user chose to show none; the surface falls back to a recovery item.
    case none

    /// How "show none" is written to settings.json.
    public static let noneKey = "none"
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
        // `hiddenSubscriptions` is deliberately not read: it belonged to the
        // removed multi-select surface, and ignoring it is the whole migration.
        // `selectedProviderId` is read once, for settings written before
        // `selection` existed, where an empty string already meant "show none".
        if let selected = root["selection"] as? String {
            settings.selection = selected == ProviderSelection.noneKey
                ? .none : .provider(selected)
        } else if let legacy = root["selectedProviderId"] as? String {
            settings.selection = legacy.isEmpty ? .none : .provider(legacy)
        }
        settings.clamp()
        return settings
    }

    public func save(_ settings: Settings) {
        var clamped = settings
        clamped.clamp()
        var payload: [String: Any] = ["intervalMs": clamped.intervalMs]
        switch clamped.selection {
        case .automatic: break
        case .provider(let id): payload["selection"] = id
        case .none: payload["selection"] = ProviderSelection.noneKey
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