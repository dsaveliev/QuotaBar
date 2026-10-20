# Tasks

## 1. The MiniMax fixture's windows are independent again

- [x] 1.1 In `Fixtures/minimax-token-plan-remains.json`, set `weekly_start_time` to
  `1791657200000` and `weekly_end_time` to `1792262000000`, leaving `start_time`,
  `end_time`, `remains_time` and every figure untouched. Verify: the weekly
  window spans exactly seven days and began three days before the five-hour
  window, so `weekly_start_time` is no longer equal to `start_time`
- [x] 1.2 In the same file, set `weekly_remains_time` to `329400000`, the distance
  from the capture instant implied by `end_time - remains_time` to
  `weekly_end_time`. Verify: `weekly_remains_time` is shorter than the weekly
  window's full length and is no longer equal to it
- [x] 1.3 Every value in the file still ends in `000`. Verify: read each
  timestamp and confirm it is a multiple of a thousand

## 2. The fixture's shape is pinned by a test

- [x] 2.1 Add a case to `MiniMaxProviderTests` in
  `Sources/QuotaBarKitTests/ProviderTests.swift` asserting the fixture's weekly
  window spans exactly seven days, began before the current five-hour window, and
  reports a remaining time equal to the distance from the capture instant to the
  weekly window's end. Verify: the case passes, and it fails against the
  pre-scrub fixture's shape
- [x] 2.2 In the same case, assert that the parser gives the `5h` row and the
  `7d` row different reset timestamps, so a parser reading the wrong field cannot
  pass. Verify: the case fails if the weekly row's reset comes from the
  five-hour window's end
- [x] 2.3 No existing case asserts a MiniMax fixture timestamp, so none needs
  changing. Verify: `swift run QuotaBarKitTests` passes with the new case added

## 3. The README describes the fixtures as they are

- [x] 3.1 Correct the "what was replaced and what was not" section of
  `Fixtures/README.md`: every value in both fixtures is a round number,
  timestamps included, and what survives the rounding is the shape — the
  relationships between the values. Verify: the section no longer claims the
  timestamps were kept as captured, and names the timestamps as replaced
- [x] 3.2 Add the MiniMax rows the new test depends on to that file's table of
  kept properties: the weekly window is independent of the five-hour window and
  spans seven days, and its remaining time is a countdown to its own end. Verify:
  `grep` finds both properties listed
- [x] 3.3 Sharpen the instruction for whoever re-captures a payload: replace the
  figures, and keep the shape holding. Verify: the file tells a contributor
  which relationships must survive their edit

## 4. Verify

- [x] 4.1 `swift run QuotaBarKitTests`. Verify: 159 cases passing — the 158
  that existed before this change, plus the new one
- [x] 4.2 `openspec validate --specs --strict` and `openspec validate
  fixture-window-fidelity --strict`. Verify: both report no advisory
- [x] 4.3 The app still reads the same figures. Verify: the installed app's
  MiniMax panel shows the same percentages and the same weekly reset as before
  the fixture changed, since no application code changed
