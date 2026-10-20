import Foundation
import QuotaBarKit

enum ZaiProviderTests {
    static let fiveHoursMs: Double = 5 * 60 * 60 * 1000
    static let weekMs: Double = 7 * 24 * 60 * 60 * 1000

    static let cases: [TestCase] = [
        ("the live payload parses into a 5h and a 7d row", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "labels")
            Harness.expectEqual(rows[0].percent, 1, "5h percent")
            Harness.expectEqual(rows[0].windowMs, fiveHoursMs, "5h window")
            Harness.expectEqual(rows[1].percent, 40, "7d percent")
            Harness.expectEqual(rows[1].windowMs, weekMs, "7d window")
        }),
        ("currentValue wins over the plan-total usage field", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            // limits[0]: usage 1000 (plan total) but currentValue 0 (this window)
            Harness.expectEqual(rows[0].usage, 0, "5h usage is the window's currentValue")
            Harness.expectEqual(rows[1].usage, 2_000, "7d usage is the window's currentValue")
        }),
        ("the limit is the sum of consumed and remaining", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            Harness.expectEqual(rows[0].limit, 999, "5h limit")
            Harness.expectEqual(rows[1].limit, 5_000, "7d limit")
        }),
        ("reset timestamps are carried through unchanged", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            Harness.expectEqual(rows[0].resetAt, 1_792_003_600_000, "5h resetAt")
            Harness.expectEqual(rows[1].resetAt, 1_792_585_200_000, "7d resetAt")
        }),
        ("an explicit percentage wins over one derived from the counts", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            // limits[0] has percentage 1 while usage/limit derive to 0%; the
            // server's own figure must win.
            Harness.expectEqual(rows[0].percent, 1, "explicit percentage")
        }),
        ("percent is derived from counts when the field is absent", {
            let payload: [String: Any] = [
                "data": ["limits": [
                    ["unit": 3, "currentValue": 25, "remaining": 75, "nextResetTime": 1_000.0],
                ]],
            ]
            let rows = ZaiProvider().parse(payload)
            Harness.expectEqual(rows.count, 1, "row count")
            Harness.expectEqual(rows[0].limit, 100, "limit")
            Harness.expectEqual(rows[0].percent, 25, "derived percent")
        }),
        ("percent is clamped into 0...100", {
            let payload: [String: Any] = [
                "data": ["limits": [
                    ["unit": 3, "currentValue": 10, "remaining": 10, "percentage": 125.0],
                    ["unit": 6, "currentValue": 10, "remaining": 10, "percentage": -5.0],
                ]],
            ]
            let rows = ZaiProvider().parse(payload)
            Harness.expectEqual(rows[0].percent, 100, "clamped high")
            Harness.expectEqual(rows[1].percent, 0, "clamped low")
        }),
        ("rows are ordered 5h before 7d regardless of payload order", {
            let payload: [String: Any] = [
                "data": ["limits": [
                    ["unit": 6, "currentValue": 1, "remaining": 9],
                    ["unit": 3, "currentValue": 2, "remaining": 8],
                ]],
            ]
            Harness.expectEqual(ZaiProvider().parse(payload).map(\.label), ["5h", "7d"], "labels")
        }),
        ("an unknown unit keeps its type as the label and reports no window", {
            let payload: [String: Any] = [
                "data": ["limits": [["unit": 9, "type": "PROMO", "currentValue": 1, "remaining": 9]]],
            ]
            let rows = ZaiProvider().parse(payload)
            Harness.expectEqual(rows[0].label, "PROMO", "label")
            Harness.expectEqual(rows[0].windowMs, nil, "windowMs")
        }),
        ("an unrecognised payload yields no rows rather than throwing", {
            Harness.expectEqual(ZaiProvider().parse(["unexpected": true]).count, 0, "dictionary payload")
            Harness.expectEqual(ZaiProvider().parse([1, 2, 3]).count, 0, "array payload")
            Harness.expectEqual(ZaiProvider().parse("a string").count, 0, "string payload")
            Harness.expectEqual(ZaiProvider().parse(NSNull()).count, 0, "null payload")
        }),
        ("the tolerant scan recovers rows when `limits` is gone", {
            let payload: [String: Any] = [
                "code": 200,
                "data": ["quota_summary": [
                    ["unit": 3, "currentValue": 10, "remaining": 90, "nextResetTime": 1_000.0],
                    ["unit": 6, "currentValue": 20, "remaining": 80, "nextResetTime": 2_000.0],
                ]],
            ]
            let rows = ZaiProvider().parse(payload)
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "labels from the scan")
        }),
        ("the tolerant scan is bounded and stops at the row cap", {
            // 40 sibling entries, each recognisable: the cap must hold at 16.
            let entries = (0..<40).map { index -> [String: Any] in
                ["unit": 9, "type": "T\(index)", "currentValue": Double(index), "remaining": 10]
            }
            let rows = ZaiProvider().parse(["data": ["items": entries]])
            Harness.expectEqual(rows.count, 16, "row cap")
        }),
        ("an unsuccessful envelope is not a successful payload", {
            Harness.expect(
                !ZaiProvider().isSuccessPayload(["code": 401, "success": false, "data": ["limits": []]]),
                "401 with success:false must fail"
            )
            Harness.expect(
                !ZaiProvider().isSuccessPayload(["code": 500, "data": ["limits": [
                    ["unit": 3, "currentValue": 1, "remaining": 1],
                ]]]),
                "a 5xx code must fail even with usable rows"
            )
            let live = try Fixtures.json("zai-limits.json")
            Harness.expect(ZaiProvider().isSuccessPayload(live), "the live payload must succeed")
        }),
        ("registry lookup is exact and case-sensitive", {
            for alias in ["zai", "zai-coding-plan", "zhipuai-coding-plan"] {
                Harness.expectEqual(ProviderRegistry.resolve(providerId: alias)?.id, "zai", "alias \(alias)")
            }
            Harness.expectEqual(ProviderRegistry.resolve(providerId: "Zai-Coding-Plan")?.id, nil, "different case")
            Harness.expectEqual(ProviderRegistry.resolve(providerId: "openai")?.id, nil, "unknown provider")
            Harness.expectEqual(ProviderRegistry.resolve(providerId: nil)?.id, nil, "nil provider")
        }),
    ]
}

enum MiniMaxProviderTests {
    static let fiveHoursMs: Double = 5 * 60 * 60 * 1000
    static let weekMs: Double = 7 * 24 * 60 * 60 * 1000

    static let cases: [TestCase] = [
        ("the live payload parses into a 5h and a 7d row", {
            let rows = MiniMaxProvider().parse(try Fixtures.json("minimax-token-plan-remains.json"))
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "labels")
            Harness.expectEqual(rows[0].percent, 20, "5h percent")
            Harness.expectEqual(rows[1].percent, 50, "7d percent")
        }),
        ("consumed percent is the complement of the reported remaining percent", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 84.0,
                    "current_weekly_status": 1,
                    "current_weekly_remaining_percent": 60.0,
                ]],
                "base_resp": ["status_code": 0],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows[0].percent, 16, "5h")
            Harness.expectEqual(rows[1].percent, 40, "7d")
        }),
        ("rows carry percent-space pseudo-usage and a pseudo-limit of 100", {
            let rows = MiniMaxProvider().parse(try Fixtures.json("minimax-token-plan-remains.json"))
            Harness.expectEqual(rows[0].usage, 20, "5h usage in percent points")
            Harness.expectEqual(rows[0].limit, 100, "5h pseudo-limit")
            Harness.expectEqual(rows[1].usage, 50, "7d usage in percent points")
            Harness.expectEqual(rows[1].limit, 100, "7d pseudo-limit")
        }),
        ("window durations are the plan's declared 5h and 7d", {
            let rows = MiniMaxProvider().parse(try Fixtures.json("minimax-token-plan-remains.json"))
            Harness.expectEqual(rows[0].windowMs, fiveHoursMs, "5h window")
            Harness.expectEqual(rows[1].windowMs, weekMs, "7d window")
        }),
        ("the captured payload's weekly window is its own window", {
            // The endpoint's two windows are independent: the weekly one has its
            // own start, its own end, and counts down to that end. A fixture
            // that flattened them into a copy of the five-hour window would let
            // a parser reading the wrong field pass, so the shape is checked
            // here and not only the figures.
            let payload = try Fixtures.json("minimax-token-plan-remains.json")
            let entries = payload["model_remains"] as? [[String: Any]] ?? []
            guard let entry = entries.first else {
                Harness.expect(false, "the fixture must carry a plan entry")
                return
            }
            func stamp(_ key: String) -> Double? {
                guard let number = entry[key] as? NSNumber else { return nil }
                let value = number.doubleValue
                return value.isFinite ? value : nil
            }
            guard
                let start = stamp("start_time"),
                let end = stamp("end_time"),
                let remains = stamp("remains_time"),
                let weeklyStart = stamp("weekly_start_time"),
                let weeklyEnd = stamp("weekly_end_time"),
                let weeklyRemains = stamp("weekly_remains_time")
            else {
                Harness.expect(false, "the fixture must carry both windows' timestamps")
                return
            }

            // The weekly window spans seven days of its own, and began before
            // the current five-hour window did.
            Harness.expectEqual(weeklyEnd - weeklyStart, weekMs, "the weekly window spans seven days")
            Harness.expect(weeklyStart < start, "the weekly window began before the five-hour window")

            // Its remaining time counts down to its own end, from the capture
            // instant the interval window implies.
            let capture = end - remains
            Harness.expectEqual(weeklyRemains, weeklyEnd - capture, "the weekly remaining time counts down to its own end")
            Harness.expect(
                weeklyRemains < weeklyEnd - weeklyStart,
                "the weekly remaining time is a countdown, not the full window"
            )

            // Each row takes its own window's end, so the two never agree.
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(
                rows.first { $0.label == "5h" }?.resetAt, end,
                "the 5h row resets at the interval window's end"
            )
            Harness.expectEqual(
                rows.first { $0.label == "7d" }?.resetAt, weeklyEnd,
                "the 7d row resets at the weekly window's end"
            )
            Harness.expect(rows[0].resetAt != rows[1].resetAt, "the two rows must not share a reset")
        }),
        ("an exhausted window is reported at 100% while the other still reports", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 2,
                    "current_weekly_remaining_percent": 0.0,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "both windows")
            Harness.expectEqual(rows.first { $0.label == "5h" }?.percent, 50, "5h percent")
            Harness.expectEqual(rows.first { $0.label == "7d" }?.percent, 100, "7d percent")
        }),
        ("an exhausted status outranks a remaining percent above zero", {
            // The endpoint's own status is the authority on whether a window is
            // spent; a percentage left over from before it ran out must not
            // render it as intact.
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 84.0,
                    "current_weekly_status": 2,
                    "current_weekly_remaining_percent": 60.0,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows.first { $0.label == "7d" }?.percent, 100, "7d percent")
        }),
        ("an exhausted window is reported even when its remaining percent is absent", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 2,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "both windows")
            Harness.expectEqual(rows.first { $0.label == "7d" }?.percent, 100, "7d percent")
        }),
        ("an unlimited window is omitted while the other still reports", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 3,
                    "current_weekly_remaining_percent": 100.0,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows.map(\.label), ["5h"], "only the limited window")
        }),
        ("a status the endpoint does not define is read as limited", {
            // A window that vanishes takes its quota off the screen with no way
            // to tell it from a healthy one, so an unrecognised status reads
            // from the percentage rather than dropping the window.
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 0,
                    "current_weekly_remaining_percent": 50.0,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "both windows")
            Harness.expectEqual(rows.first { $0.label == "7d" }?.percent, 50, "7d percent")
        }),
        ("remaining percent is clamped so consumed stays inside 0...100", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": -10.0,
                    "current_weekly_status": 1,
                    "current_weekly_remaining_percent": 150.0,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows[0].percent, 100, "negative remaining clamps to fully used")
            Harness.expectEqual(rows[1].percent, 0, "over-100 remaining clamps to unused")
        }),
        ("an entry that omits one window's percent is still recognised", {
            // The entry carries both windows' timestamps, so it describes a
            // plan. Refusing it over a missing percentage would cost the
            // window the payload does describe its row too.
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 2,
                ]],
            ]
            let rows = MiniMaxProvider().parse(payload)
            Harness.expectEqual(rows.map(\.label), ["5h", "7d"], "both windows")
            Harness.expectEqual(rows.first { $0.label == "5h" }?.percent, 50, "5h percent")
            Harness.expectEqual(rows.first { $0.label == "7d" }?.percent, 100, "7d percent")
        }),
        ("an entry with no window timestamps yields no rows", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 1,
                    "current_weekly_remaining_percent": 50.0,
                ]],
            ]
            Harness.expectEqual(MiniMaxProvider().parse(payload).count, 0, "no rows")
        }),
        ("an empty or unrecognised plan list yields no rows", {
            Harness.expectEqual(MiniMaxProvider().parse(["model_remains": []]).count, 0, "empty list")
            Harness.expectEqual(MiniMaxProvider().parse(["model_remains": [["end_time": 1.0]]]).count, 0, "incomplete entry")
            Harness.expectEqual(MiniMaxProvider().parse(["other": true]).count, 0, "missing key")
        }),
        ("a non-zero base_resp status is a failure, not a success", {
            let payload: [String: Any] = [
                "model_remains": [[
                    "end_time": 1_000.0,
                    "weekly_end_time": 2_000.0,
                    "current_interval_status": 1,
                    "current_interval_remaining_percent": 50.0,
                    "current_weekly_status": 1,
                    "current_weekly_remaining_percent": 50.0,
                ]],
                "base_resp": ["status_code": 1008, "status_msg": "insufficient balance"],
            ]
            Harness.expect(!MiniMaxProvider().isSuccessPayload(payload), "region mismatch must fail")
            let live = try Fixtures.json("minimax-token-plan-remains.json")
            Harness.expect(MiniMaxProvider().isSuccessPayload(live), "the live payload must succeed")
        }),
        ("both regional endpoints are declared, international first", {
            let hosts = MiniMaxProvider().endpoints.map { $0.host ?? "" }
            Harness.expectEqual(hosts, ["api.minimax.io", "api.minimax.cn"], "endpoint hosts")
        }),
        ("registry lookup covers all three OpenCode ids", {
            for alias in ["minimax", "minimax-coding-plan", "minimax-cn-coding-plan"] {
                Harness.expectEqual(ProviderRegistry.resolve(providerId: alias)?.id, "minimax", "alias \(alias)")
            }
            Harness.expectEqual(ProviderRegistry.resolve(providerId: "zai")?.id, "zai", "zai")
        }),
        ("both providers declare the one environment name the spec pins", {
            Harness.expectEqual(ZaiProvider().tokenEnvNames, ["ZAI_TOKEN"], "zai env")
            Harness.expectEqual(MiniMaxProvider().tokenEnvNames, ["MINIMAX_TOKEN"], "minimax env")

            // One scheme, and it is predictable from the provider's name.
            Harness.expect(
                ZaiProvider().tokenEnvNames.allSatisfy { $0.hasSuffix("_TOKEN") }
                    && MiniMaxProvider().tokenEnvNames.allSatisfy { $0.hasSuffix("_TOKEN") },
                "both follow <PROVIDER>_TOKEN"
            )
        }),
        ("the retired environment names are no longer read", {
            // A breaking change, pinned so it cannot be reverted by accident:
            // someone with MINIMAX_API_KEY exported gets no token at all.
            let store = CredentialStore(
                environment: { $0 == "MINIMAX_API_KEY" ? "retired" : nil }
            )
            Harness.expectEqual(
                store.resolve(for: MiniMaxProvider())?.token,
                nil,
                "the retired name resolves nothing"
            )
        }),
        ("the missing-token messages are parallel", {
            let zai = QuotaErrorCode.displayText(for: QuotaErrorCode.noToken.rawValue, provider: ZaiProvider())
            let mini = QuotaErrorCode.displayText(for: QuotaErrorCode.noToken.rawValue, provider: MiniMaxProvider())
            Harness.expect(zai.hasPrefix("no token — set "), "zai shape")
            Harness.expect(mini.hasPrefix("no token — set "), "minimax shape")
            Harness.expectEqual(
                zai.replacingOccurrences(of: "ZAI_TOKEN", with: "VARIABLE"),
                mini.replacingOccurrences(of: "MINIMAX_TOKEN", with: "VARIABLE"),
                "identical but for the variable"
            )
        }),
    ]
}