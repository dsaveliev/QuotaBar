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
/// Three differences from Z.ai drive this parser: there is no `unit` field, so
/// the window durations are the plan's declared 5h and 7d; the plan is
/// percentage-of-time based, so the wire reports *remaining* percent, which is
/// inverted to get consumed percent; and each window carries a plan status,
/// which says whether the plan meters a limit against that window at all.
public struct MiniMaxProvider: QuotaProvider {
    public static let aliases = ["minimax", "minimax-coding-plan", "minimax-cn-coding-plan"]

    public let id = "minimax"
    public let tag = "mmx"
    public let displayName = "MiniMax"
    public let tokenEnvNames = ["MINIMAX_TOKEN"]
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
        case .noToken: "no token — set MINIMAX_TOKEN, then run ./scripts/install.sh so the agent can see it"
        default: code.rawValue
        }
    }

    public func parse(_ payload: Any) -> [QuotaRow] {
        guard let root = JSON.dictionary(payload),
              let entries = JSON.array(root["model_remains"])
        else { return [] }

        // The first entry that describes a usable window wins. An entry that
        // yields no row is skipped rather than ending the search, so it cannot
        // shadow a later entry that does describe the plan.
        for entry in entries.compactMap(JSON.dictionary) where isPlanEntry(entry) {
            let rows = rows(from: entry)
            if !rows.isEmpty { return RowOrder.sort(rows) }
        }
        return []
    }

    /// An entry carries a plan when it reports both windows' reset timestamps.
    /// The remaining percents are not required: an exhausted window can omit
    /// its percentage, and refusing the entry for that would cost the other
    /// window its row too.
    private func isPlanEntry(_ entry: [String: Any]) -> Bool {
        return JSON.finiteNumber(entry["end_time"]) != nil
            && JSON.finiteNumber(entry["weekly_end_time"]) != nil
    }

    private func rows(from entry: [String: Any]) -> [QuotaRow] {
        var rows: [QuotaRow] = []
        if let row = makeRow(
            label: "5h",
            resetAt: JSON.finiteNumber(entry["end_time"]),
            windowMs: Self.window5hMs,
            remainingPercent: JSON.finiteNumber(entry["current_interval_remaining_percent"]),
            status: PlanStatus(JSON.finiteNumber(entry["current_interval_status"]))
        ) {
            rows.append(row)
        }
        if let row = makeRow(
            label: "7d",
            resetAt: JSON.finiteNumber(entry["weekly_end_time"]),
            windowMs: Self.window7dMs,
            remainingPercent: JSON.finiteNumber(entry["current_weekly_remaining_percent"]),
            status: PlanStatus(JSON.finiteNumber(entry["current_weekly_status"]))
        ) {
            rows.append(row)
        }
        return rows
    }

    /// Builds a percent-space row: `usage = 100 - remaining`, `limit = 100`, so
    /// the shared runway projection works in percent points per unit time.
    ///
    /// The plan status decides what the window reports. An exhausted window is
    /// at its limit, so it is reported at 100 with the same limit of 100 - the
    /// shared verdict ladder calls that blocked, which is the same route
    /// Z.ai's exhausted window takes. An unlimited window has no limit to be
    /// at and nothing to project, so it is not reported at all.
    private func makeRow(
        label: String,
        resetAt: EpochMillis?,
        windowMs: Double,
        remainingPercent: Double?,
        status: PlanStatus
    ) -> QuotaRow? {
        let usedPercent: Double
        switch status {
        case .exhausted:
            usedPercent = 100
        case .limited:
            guard let remainingPercent, remainingPercent.isFinite else { return nil }
            usedPercent = min(100, max(0, 100 - remainingPercent))
        case .unlimited:
            return nil
        }
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

/// What the plan status says about one of a plan's windows.
///
/// The endpoint reports `1` for a limited window, `2` for an exhausted one,
/// and `3` for an unlimited one. A status the endpoint does not define is
/// read as limited: the percentage is still there, and a window that vanishes
/// takes its quota off the screen with no way to tell it from a healthy one.
private enum PlanStatus {
    case limited
    case exhausted
    case unlimited

    init(_ raw: Double?) {
        guard let raw else {
            self = .limited
            return
        }
        switch raw {
        case 2: self = .exhausted
        case 3: self = .unlimited
        default: self = .limited
        }
    }
}