# Tasks

## 1. The parser learns the three statuses

- [x] 1.1 Give `MiniMaxProvider` a `PlanStatus` enum that reads the wire value
  `2` as exhausted, `3` as unlimited, and every other value — including an
  absent one — as limited. Verify: `swift build` is clean
- [x] 1.2 Branch `makeRow` on that status instead of guarding on `status == 1`:
  an exhausted window is reported with `usedPercent` 100, a limited window with
  `100 - remainingPercent` as it is today, and an unlimited window is not
  reported. The row keeps its percent-space shape — `usage` equal to the used
  percent, `limit` 100 — so `usage >= limit` is what makes it blocked. Verify:
  `swift build` is clean
- [x] 1.3 A window whose status reports an exhausted plan is reported at 100%
  while the other window still reports its own percent. Verify: the case in
  `MiniMaxProviderTests` fails against the old parser, which drops the row
- [x] 1.4 An exhausted window is reported at 100% even when the payload reports
  a remaining percent above zero for it. Verify: the case fails if the
  percentage is preferred over the status
- [x] 1.5 An exhausted window is reported at 100% when the payload omits its
  remaining percent entirely. Verify: the case fails if the percentage is
  required
- [x] 1.6 A window whose status reports an unlimited plan is omitted, and the
  other window is still reported. Verify: the case fails if the unlimited
  window is reported
- [x] 1.7 A window whose status is one the endpoint does not define is reported
  from its remaining percent, as a limited window would be. Verify: the case
  fails against the old parser, which dropped the row

## 2. The parser recognises an entry by its timestamps

- [x] 2.1 Stop requiring both remaining percents in `isPlanEntry`: an entry is
  recognised when it carries both windows' reset timestamps. Verify: `swift
  build` is clean
- [x] 2.2 Select the first entry that yields at least one reportable window,
  skipping entries that yield none, so an entry that describes no usable window
  cannot shadow a later one that describes the plan. Verify: `swift build` is
  clean
- [x] 2.3 An entry that omits one window's remaining percent is still
  recognised, and the window the payload does describe is still reported
  alongside it. Verify: the case fails against the old parser, which rejected
  the whole entry
- [x] 2.4 A payload whose entries carry no window timestamps yields no rows, so
  the subscription reports the empty-payload error. Verify: the case fails if
  such an entry is accepted

## 3. The exhausted window reaches the user

- [x] 3.1 An exhausted MiniMax window is `blocked`, not `unknown`, and it does
  not wait for evidence to say so. Verify: the engine case fails against the
  old parser, which reported no weekly window at all
- [x] 3.2 The panel's runway line for an exhausted MiniMax window reads `limit
  reached`, and the menu bar's glyph for the subscription is `✗`. Verify: the
  engine case reads the snapshot's window verdict and the aggregate verdict
- [x] 3.3 The exhausted window's row still carries its reset timestamp and its
  window duration, so the panel shows when the window resets and paces the bar.
  Verify: the engine case reads `resetInMs` and `windowMs` off the window

## 4. Documentation

- [x] 4.1 Update the test count in `README.md` to the number the suite reports.
  Verify: `swift run QuotaBarKitTests` prints the same count the README states
- [x] 4.2 Record in the README what an exhausted MiniMax window shows, if the
  README describes what the panel shows for each provider. Verify: `grep` finds
  the description where the README covers the other providers' windows, or the
  README is left alone because it does not

## 5. Verify and ship

- [x] 5.1 `swift run QuotaBarKitTests`. Verify: 149 plus the new cases, passing
- [x] 5.2 `openspec validate --specs --strict` and `openspec validate
  minimax-exhausted-window --strict`. Verify: both report no advisory
- [x] 5.3 `./scripts/install.sh`, then open the MiniMax panel while its weekly
  quota is spent. Verify: the weekly row is present and reads `100%` with the
  red `✗`, the menu bar shows `✗`, and the five-hour row is unaffected
