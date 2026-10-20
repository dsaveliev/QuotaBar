# Why

The MiniMax fixture no longer has the shape MiniMax's endpoint sends. Its
weekly window was rounded into a copy of the five-hour window and its
`weekly_remains_time` into the full span of the window, so the fixture now
teaches a payload the endpoint never produces — and `Fixtures/README.md`
asserts the opposite, claiming the absolute reset timestamps were "kept as
captured" when every one of them was replaced with a round number.

Nothing the app does is wrong today. This is about the payload the parsers are
checked against, and about a claim the repository makes about itself.

# What Changes

- **`Fixtures/minimax-token-plan-remains.json` — the weekly window becomes
  independent of the five-hour window again.** `weekly_start_time` moves three
  days before `start_time`, and `weekly_end_time` moves to exactly seven days
  after `weekly_start_time`. The five-hour window is untouched.
- **`Fixtures/minimax-token-plan-remains.json` — `weekly_remains_time` becomes a
  countdown to the weekly window's end** instead of the window's full length, so
  the fixture shows a payload captured partway through a weekly window rather
  than one captured at its first instant.
- **Every value in the fixture stays a round number.** The scrubbing that
  created the false shape was right to want round numbers — a window boundary
  needs no more precision than that, and the values are published with the
  source. Only the relationships between them are wrong, and only those change.
- **`Fixtures/README.md` stops claiming the timestamps were kept as captured.**
  It says what was replaced — which includes every timestamp, in both fixtures —
  and it gains the fixture properties that the change now guarantees.
- **`Fixtures/README.md` records that the shape was checked against the live
  endpoint**, so the next person who rounds a value knows which relationships
  must survive the rounding.
- **A test pins the payload's shape.** The MiniMax fixture's weekly window
  begins before the five-hour window, spans exactly seven days, and reports a
  countdown to its own end. A test asserts those relationships, so a future
  scrub that flattens the shape again fails the suite instead of passing
  silently.

# Capabilities

## New Capabilities

None.

## Modified Capabilities

- `quota-subscription-polling`: a new `MiniMax window boundaries` requirement
  stating that each MiniMax row takes its reset timestamp from its own window's
  boundary in the payload — the five-hour row from `end_time`, the weekly row
  from `weekly_end_time` — and that neither window's reset is derived from the
  other. The app already behaves this way; the requirement makes it explicit
  and checkable, and the fixture is what makes it observable.

# Impact

- `Fixtures/minimax-token-plan-remains.json` — four timestamp values change.
  The percentages, the limit, the counts and the envelope are untouched.
- `Fixtures/README.md` — the "what was replaced and what was not" section is
  corrected, and the table of kept properties gains the MiniMax rows.
- `Sources/QuotaBarKitTests/ProviderTests.swift` — one new case asserting the
  fixture's shape. No existing case asserts a MiniMax timestamp, so none needs
  updating; the Z.ai fixture is left alone.
- No application code changes. The parser already reads `end_time` and
  `weekly_end_time`, and the app's behaviour is identical before and after.
- No spec behaviour changes beyond the added requirement, which pins existing
  behaviour rather than altering it.

# Non-goals

- **Deriving a window's duration from the payload.** The parser uses the plan's
  declared durations — five hours and seven days — and the spec says so. The
  endpoint's own spans agree with those constants for this plan tier, and the
  fixture is corrected to agree with them as well. Deriving the duration instead
  would be a behaviour change with its own requirement.
- **Which model bucket is read.** The parser takes the first entry that looks
  like a plan entry; upstream selects the `general` bucket explicitly. Unrelated
  to the shape of the fixture.
- **The Z.ai fixture.** Its two reset timestamps were rounded too, but a
  Z.ai payload carries no window starts, so there is no relationship between
  them to flatten. Only the README's claim about them is wrong, and that is
  corrected above.
- **Restoring the captured timestamps verbatim.** They are already in the git
  history, and they would put the original capture's exact window boundaries back
  into a published file. Round numbers with faithful relationships keep both the
  scrubbing's intent and the endpoint's shape.
