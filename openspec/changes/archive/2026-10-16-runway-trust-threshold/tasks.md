# Tasks

## 1. Threshold

- [x] 1.1 Add `windowMs` to `VerdictInput` and a `minimumSpanMs(forWindow:)` rule of one twentieth of the window's duration, floored at one minute; verify a five-hour window requires fifteen minutes and a weekly one about eight hours
- [x] 1.2 Apply the threshold in the ladder in place of the flat one-minute check, keeping `blocked` ahead of it; verify a window below its threshold is `unknown` and one exactly at it proceeds

## 2. Measuring state

- [x] 2.1 Add `isMeasuring` and `measuredFraction` to `WindowSnapshot` and populate them in the engine from the row's duration and the projection's span; verify both are nil-free and consistent
- [x] 2.2 Render `runway measuring…` for a measuring window and keep `runway …` for a window with too few samples; verify the two are distinguishable
- [x] 2.3 Show how far along the wait a measuring window is, so it does not read as a hang
- [x] 2.4 Mention the measuring state in the item's explanation

## 3. Tests

- [x] 3.1 Add verdict cases for a window below, at, and above its proportional threshold, and for the unknown-duration fallback
- [x] 3.2 Update the engine case that expected a verdict from a two-minute history so it waits past the threshold; verify it still proves persistence across a restart
- [x] 3.3 Add a case asserting the weekly window is `unknown` shortly after launch and that `blocked` still short-circuits during measurement

## 4. Verification

- [x] 4.1 Run `swift run QuotaBarKitTests` and confirm the suite passes
- [x] 4.2 Rebuild, reinstall, and confirm the weekly window reports measuring rather than a shortfall while the five-hour window reaches a verdict
- [x] 4.3 Validate with `openspec validate --strict` and archive the change