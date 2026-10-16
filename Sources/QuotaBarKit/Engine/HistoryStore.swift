import Foundation

/// Persists per-window usage sample histories so a restart resumes projection
/// from prior samples instead of starting from nothing.
///
/// Malformed entries are dropped individually; a single bad record never costs
/// the whole history.
public struct HistoryStore: Sendable {
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

    /// Keys are `providerId:label`, which is what keeps one subscription's
    /// samples out of another subscription's projection.
    public func load() -> [String: [Sample]] {
        guard let data = try? readFile(url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let raw = root["samples"] as? [String: Any]
        else { return [:] }

        var result: [String: [Sample]] = [:]
        for (key, value) in raw {
            guard let entries = JSON.array(value) else { continue }
            let samples = entries.compactMap { entry -> Sample? in
                guard let record = JSON.dictionary(entry),
                      let t = JSON.finiteNumber(record["t"]),
                      let usage = JSON.finiteNumber(record["usage"]),
                      t.isFinite, usage.isFinite
                else { return nil }
                return Sample(t: t, usage: usage)
            }
            guard !samples.isEmpty else { continue }
            result[key] = samples
        }
        return result
    }

    public func save(_ histories: [String: [Sample]]) {
        let raw = histories.mapValues { samples in
            samples.map { ["t": $0.t, "usage": $0.usage] }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: ["samples": raw]) else { return }
        try? writeFile(data, url)
    }
}