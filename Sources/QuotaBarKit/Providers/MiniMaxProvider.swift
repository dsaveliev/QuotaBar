import Foundation

/// MiniMax Token Plan.
///
/// Endpoint `GET /v1/token_plan/remains`, region-detected: `api.minimax.io`
/// first, `api.minimax.cn` when the international host reports a non-zero
/// `base_resp.status_code`.
///
/// Payload shape (captured live from the user's own plan):
/// ```
/// { "model_remains": [ { "start_time": …, "end_time": …,
///     "current_interval_status": 1, "current_interval_remaining_percent": 84,
///     "weekly_start_time": …, "weekly_end_time": …,
///     "current_weekly_status": 1, "current_weekly_remaining_percent": 60 } ],
///   "base_resp": { "status_code": 0, "status_msg": "success" } }
/// ```
///
/// Two differences from Z.ai drive this parser: there is no `unit` field, so
/// the window durations are the plan's declared 5h and 7d; and the plan is
/// percentage-of-time based, so the wire reports *remaining* percent, which is
/// inverted to get consumed percent.
public struct MiniMaxProvider: QuotaProvider {
    public static let aliases = ["minimax", "minimax-coding-plan", "minimax-cn-coding-plan"]

    public let id = "minimax"
    public let tag = "mmx"
    public let displayName = "MiniMax"
    public let authKeys = ["minimax-coding-plan", "minimax-cn-coding-plan", "minimax"]
    public let tokenEnvNames = ["MINIMAX_API_KEY"]
    public let endpoints = [
        URL(string: "https://api.minimax.io/v1/token_plan/remains")!,
        URL(string: "https://api.minimax.cn/v1/token_plan/remains")!,
    ]

    private static let window5hMs: Double = 5 * 60 * 60 * 1000
    private static let window7dMs: Double = 7 * 24 * 60 * 60 * 1000

    public init() {}

    /// A 200 response carrying a non-zero `base_resp.status_code` is a failure
    /// for this provider and must fall through to the next endpoint. Everything
    /// else is envelope success: whether rows are present is decided by the
    /// engine after it commits to this host.
    public func isSuccessPayload(_ payload: Any) -> Bool {
        guard let root = JSON.dictionary(payload) else { return false }
        if let baseResp = JSON.dictionary(root["base_resp"]),
           let statusCode = JSON.finiteNumber(baseResp["status_code"]),
           statusCode != 0 {
            return false
        }
        return true
    }

    public func isEmptyPayload(_ payload: Any) -> Bool {
        parse(payload).isEmpty
    }

    public func errorText(_ code: QuotaErrorCode) -> String {
        switch code {
        case .noToken: "no token (minimax login or MINIMAX_API_KEY)"
        case .noCredentialFile: "no OpenCode credentials for MiniMax"
        default: code.rawValue
        }
    }

    public func parse(_ payload: Any) -> [QuotaRow] {
        guard let root = JSON.dictionary(payload),
              let entries = JSON.array(root["model_remains"]),
              let entry = entries.compactMap(JSON.dictionary).first(where: isPlanEntry)
        else { return [] }

        var rows: [QuotaRow] = []
        if let row = makeRow(
            label: "5h",
            resetAt: JSON.finiteNumber(entry["end_time"]),
            windowMs: Self.window5hMs,
            remainingPercent: JSON.finiteNumber(entry["current_interval_remaining_percent"]),
            status: JSON.finiteNumber(entry["current_interval_status"])
        ) {
            rows.append(row)
        }
        if let row = makeRow(
            label: "7d",
            resetAt: JSON.finiteNumber(entry["weekly_end_time"]),
            windowMs: Self.window7dMs,
            remainingPercent: JSON.finiteNumber(entry["current_weekly_remaining_percent"]),
            status: JSON.finiteNumber(entry["current_weekly_status"])
        ) {
            rows.append(row)
        }
        return RowOrder.sort(rows)
    }

    private func isPlanEntry(_ entry: [String: Any]) -> Bool {
        return JSON.finiteNumber(entry["end_time"]) != nil
            && JSON.finiteNumber(entry["weekly_end_time"]) != nil
            && JSON.finiteNumber(entry["current_interval_remaining_percent"]) != nil
            && JSON.finiteNumber(entry["current_weekly_remaining_percent"]) != nil
    }

    /// Builds a percent-space row: `usage = 100 - remaining`, `limit = 100`, so
    /// the shared runway projection works in percent points per unit time.
    private func makeRow(
        label: String,
        resetAt: EpochMillis?,
        windowMs: Double,
        remainingPercent: Double?,
        status: Double?
    ) -> QuotaRow? {
        guard let remainingPercent, remainingPercent.isFinite else { return nil }
        guard status == 1 else { return nil }  // 1 = active in plan
        let usedPercent = min(100, max(0, 100 - remainingPercent))
        return QuotaRow(
            label: label,
            usage: usedPercent,
            limit: 100,
            percent: usedPercent,
            resetAt: resetAt,
            windowMs: windowMs
        )
    }
}