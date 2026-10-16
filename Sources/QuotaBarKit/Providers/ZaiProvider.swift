import Foundation

/// Zhipu / Z.AI coding plan.
///
/// Both hosts (`api.z.ai`, `open.bigmodel.cn`) return identical payloads, so
/// one provider covers all three OpenCode provider ids.
///
/// Payload shape (captured live from the user's own plan):
/// ```
/// { "code": 200, "success": true, "data": {
///     "limits": [ { "type": "CREDIT_LIMIT", "unit": 3, "usage": 1000,
///                   "currentValue": 0, "remaining": 999, "percentage": 1,
///                   "nextResetTime": 1792003600000 }, … ],
///     "level": "basic" } }
/// ```
/// `unit` 3 is the five-hour window, 6 the weekly one. `currentValue` is what
/// has been consumed inside the current window and takes precedence over the
/// plan-total `usage`; the window's limit is `currentValue + remaining`.
public struct ZaiProvider: QuotaProvider {
    public static let aliases = ["zai", "zai-coding-plan", "zhipuai-coding-plan"]

    public let id = "zai"
    public let tag = "zai"
    public let displayName = "Z.ai"
    public let tokenEnvNames = ["ZAI_TOKEN"]
    public let endpoints = [
        URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")!,
        URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!,
    ]

    /// Depth and row caps for the tolerant fallback scan; the `limits` fast
    /// path is used whenever the payload still carries it.
    private static let maxScanDepth = 6
    private static let maxRows = 16
    private static let scanFields = [
        "usage", "currentValue", "remaining", "percentage", "nextResetTime",
    ]

    private static let window5hMs: Double = 5 * 60 * 60 * 1000
    private static let window7dMs: Double = 7 * 24 * 60 * 60 * 1000

    public init() {}

/// Envelope-level success only. Whether the payload carries quota rows is a
    /// separate question the engine answers after it commits to this endpoint,
    /// so a plan that genuinely reports no windows is `empty` rather than a
    /// reason to probe the next host.
    public func isSuccessPayload(_ payload: Any) -> Bool {
        guard let root = JSON.dictionary(payload) else { return false }
        if let success = root["success"] as? Bool, !success { return false }
        if let code = JSON.finiteNumber(root["code"]), code >= 400 { return false }
        return true
    }

    public func isEmptyPayload(_ payload: Any) -> Bool {
        parse(payload).isEmpty
    }

    public func errorText(_ code: QuotaErrorCode) -> String {
        switch code {
        case .noToken: "no token — set ZAI_TOKEN, then run ./scripts/install.sh so the agent can see it"
        default: code.rawValue
        }
    }

    public func parse(_ payload: Any) -> [QuotaRow] {
        var rows: [QuotaRow] = []

        // Fast path: the documented `limits` array.
        let data = JSON.dictionary(JSON.dictionary(payload)?["data"])
        if let limits = JSON.array(data?["limits"]), !limits.isEmpty {
            for entry in limits {
                if rows.count >= Self.maxRows { break }
                if let record = JSON.dictionary(entry) { rows.append(mapEntry(record)) }
            }
            return RowOrder.sort(rows)
        }

        // Fallback: bounded scan for recognisable entries, so a shape change
        // degrades to fewer rows rather than to no rows at all.
        scanForRows(payload, depth: 0, rows: &rows)
        return RowOrder.sort(rows)
    }

    // MARK: - Entry mapping

    private func windowMs(forUnit unit: Double?) -> Double? {
        if unit == 3 { return Self.window5hMs }
        if unit == 6 { return Self.window7dMs }
        return nil
    }

    private func label(for entry: [String: Any]) -> String {
        if JSON.finiteNumber(entry["unit"]) == 3 { return "5h" }
        if JSON.finiteNumber(entry["unit"]) == 6 { return "7d" }
        if let type = JSON.string(entry["type"]), !type.isEmpty { return type }
        return "quota"
    }

    private func mapEntry(_ entry: [String: Any]) -> QuotaRow {
        let currentValue = JSON.finiteNumber(entry["currentValue"])
        let usageField = JSON.finiteNumber(entry["usage"])
        let usage = currentValue ?? usageField
        let remaining = JSON.finiteNumber(entry["remaining"])

        var limit: Double?
        if let usage, let remaining {
            let sum = usage + remaining
            if sum.isFinite { limit = sum }
        }

        var percent: Double?
        if let percentage = JSON.finiteNumber(entry["percentage"]) {
            percent = min(100, max(0, percentage))
        } else if let usage, let limit, limit > 0 {
            percent = (usage / limit) * 100
        }

        return QuotaRow(
            label: label(for: entry),
            usage: usage,
            limit: limit,
            percent: percent,
            resetAt: JSON.finiteNumber(entry["nextResetTime"]),
            windowMs: windowMs(forUnit: JSON.finiteNumber(entry["unit"]))
        )
    }

    /// An object counts as a quota entry when at least two of the recognised
    /// numeric fields are present.
    private func looksLikeEntry(_ record: [String: Any]) -> Bool {
        Self.scanFields.filter { JSON.finiteNumber(record[$0]) != nil }.count >= 2
    }

    private func scanForRows(
        _ node: Any,
        depth: Int,
        rows: inout [QuotaRow]
    ) {
        if rows.count >= Self.maxRows || depth > Self.maxScanDepth { return }

        if let array = JSON.array(node) {
            for item in array { scanForRows(item, depth: depth + 1, rows: &rows) }
            return
        }
        guard let record = JSON.dictionary(node) else { return }

        // Depth and row caps already bound this recursion, so no cycle
        // bookkeeping is needed: JSON from `JSONSerialization` is a finite tree.
        if looksLikeEntry(record) { rows.append(mapEntry(record)) }
        for value in record.values {
            scanForRows(value, depth: depth + 1, rows: &rows)
        }
    }
}