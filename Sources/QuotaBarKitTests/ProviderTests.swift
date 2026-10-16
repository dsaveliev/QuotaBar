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
            Harness.expectEqual(rows[1].percent, 52, "7d percent")
            Harness.expectEqual(rows[1].windowMs, weekMs, "7d window")
        }),
        ("currentValue wins over the plan-total usage field", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            // limits[0]: usage 12000 (plan total) but currentValue 0 (this window)
            Harness.expectEqual(rows[0].usage, 0, "5h usage is the window's currentValue")
            Harness.expectEqual(rows[1].usage, 31_205, "7d usage is the window's currentValue")
        }),
        ("the limit is the sum of consumed and remaining", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            Harness.expectEqual(rows[0].limit, 11_999, "5h limit")
            Harness.expectEqual(rows[1].limit, 59_999, "7d limit")
        }),
        ("reset timestamps are carried through unchanged", {
            let rows = ZaiProvider().parse(try Fixtures.json("zai-limits.json"))
            Harness.expectEqual(rows[0].resetAt, 1_792_160_835_161, "5h resetAt")
            Harness.expectEqual(rows[1].resetAt, 1_792_577_321_993, "7d resetAt")
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
            Harness.expectEqual(rows[0].percent, 16, "5h percent")
            Harness.expectEqual(rows[1].percent, 40, "7d percent")
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
            Harness.expectEqual(rows[0].usage, 16, "5h usage in percent points")
            Harness.expectEqual(rows[0].limit, 100, "5h pseudo-limit")
            Harness.expectEqual(rows[1].usage, 40, "7d usage in percent points")
            Harness.expectEqual(rows[1].limit, 100, "7d pseudo-limit")
        }),
        ("window durations are the plan's declared 5h and 7d", {
            let rows = MiniMaxProvider().parse(try Fixtures.json("minimax-token-plan-remains.json"))
            Harness.expectEqual(rows[0].windowMs, fiveHoursMs, "5h window")
            Harness.expectEqual(rows[1].windowMs, weekMs, "7d window")
        }),
        ("an inactive window is omitted while the active one still reports", {
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
            Harness.expectEqual(rows.map(\.label), ["5h"], "only the active window")
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
        ("both providers declare the auth keys and env names the spec pins", {
            Harness.expectEqual(ZaiProvider().authKeys, ["zai-coding-plan", "zai"], "zai auth keys")
            Harness.expectEqual(ZaiProvider().tokenEnvNames, ["ZAI_TOKEN", "Z_AI_TOKEN"], "zai env")
            Harness.expectEqual(
                MiniMaxProvider().authKeys,
                ["minimax-coding-plan", "minimax-cn-coding-plan", "minimax"],
                "minimax auth keys"
            )
            Harness.expectEqual(MiniMaxProvider().tokenEnvNames, ["MINIMAX_API_KEY"], "minimax env")
        }),
    ]
}