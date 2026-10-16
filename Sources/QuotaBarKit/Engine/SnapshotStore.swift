import Foundation

/// The figures a subscription reported on its last successful refresh, and when
/// it reported them.
///
/// This exists so a restart shows numbers instead of an ellipsis. It stores
/// measurements, not conclusions: the verdict built from them is withheld until
/// a refresh this launch confirms them, because a burn rate stops being measured
/// the moment the app exits.
///
/// Malformed entries are dropped individually, the same way `HistoryStore` does.
/// A single bad record costs that subscription's figures and nothing else.
public struct SnapshotStore: Sendable {
    /// Older than this and the figures are not worth showing: a number from a
    /// fortnight ago next to a live-looking menu bar is worse than an ellipsis.
    /// The sample history keeps far more, because a burn rate needs the span;
    /// that asymmetry is deliberate.
    public static let retentionMs: Double = 7 * 24 * 60 * 60 * 1000

    /// One subscription's last known figures.
    public struct Entry: Sendable, Equatable {
        public let rows: [QuotaRow]
        /// When these rows were fetched, not when they were restored.
        public let fetchedAt: EpochMillis

        public init(rows: [QuotaRow], fetchedAt: EpochMillis) {
            self.rows = rows
            self.fetchedAt = fetchedAt
        }
    }

    private let url: URL
    private let now: @Sendable () -> EpochMillis
    private let readFile: @Sendable (URL) throws -> Data
    private let writeFile: @Sendable (Data, URL) throws -> Void

    public init(
        url: URL,
        now: @escaping @Sendable () -> EpochMillis = { Date().timeIntervalSince1970 * 1000 },
        readFile: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        writeFile: @escaping @Sendable (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.url = url
        self.now = now
        self.readFile = readFile
        self.writeFile = writeFile
    }

    /// Entries keyed by provider id, so one subscription's figures can never be
    /// shown for another. Anything older than the retention window is dropped
    /// here rather than pruned on write, because a user who never launches the
    /// app would otherwise keep every file at whatever it was.
    public func load() -> [String: Entry] {
        guard let data = try? readFile(url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return [:] }

        let cutoff = now() - Self.retentionMs
        var result: [String: Entry] = [:]
        for (providerId, value) in root {
            guard let record = JSON.dictionary(value),
                  let fetchedAt = JSON.finiteNumber(record["fetchedAt"]),
                  fetchedAt.isFinite, fetchedAt > cutoff,
                  let rawRows = JSON.array(record["rows"])
            else { continue }

            let rows = rawRows.compactMap(decodeRow)
            guard !rows.isEmpty else { continue }
            result[providerId] = Entry(rows: rows, fetchedAt: fetchedAt)
        }
        return result
    }

    public func save(_ entries: [String: Entry]) {
        let cutoff = now() - Self.retentionMs
        var payload: [String: Any] = [:]
        for (providerId, entry) in entries where entry.fetchedAt > cutoff {
            payload[providerId] = [
                "fetchedAt": entry.fetchedAt,
                "rows": entry.rows.map(encodeRow),
            ]
        }
        guard !payload.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: payload)
        else { return }
        try? writeFile(data, url)
    }

    // MARK: - Row coding

    private func decodeRow(_ value: Any) -> QuotaRow? {
        guard let record = JSON.dictionary(value) else { return nil }
        let label = record["label"] as? String
        guard let label, !label.isEmpty else { return nil }
        return QuotaRow(
            label: label,
            usage: finite(record["usage"]),
            limit: finite(record["limit"]),
            percent: finite(record["percent"]),
            resetAt: finite(record["resetAt"]),
            windowMs: finite(record["windowMs"])
        )
    }

    private func encodeRow(_ row: QuotaRow) -> [String: Any] {
        var record: [String: Any] = ["label": row.label]
        // Optionals are omitted rather than written as null, so the file stays
        // readable and a row that never had a reset does not gain one.
        for (key, value) in [
            ("usage", row.usage), ("limit", row.limit), ("percent", row.percent),
            ("resetAt", row.resetAt), ("windowMs", row.windowMs),
        ] {
            if let value { record[key] = value }
        }
        return record
    }

    private func finite(_ value: Any?) -> Double? {
        guard let number = JSON.finiteNumber(value), number.isFinite else { return nil }
        return number
    }
}