# Why

When MiniMax's weekly quota runs out, the weekly row vanishes from the app
instead of reporting itself as spent - and the app then looks healthy while the
quota is gone. The menu bar keeps its `✓` glyph and the panel shows only the
five-hour row, so the moment the user most needs to see is the moment the app
goes quiet.

The cause is a misreading of the provider's status field. `MiniMaxProvider`
drops any window whose status is not `1`, but MiniMax's status is a three-value
enum: `1` limited, `2` exhausted, `3` unlimited. The exhausted state is a real
window at 100% consumed, and the parser deletes it. Z.ai is unaffected because
its payload carries no status field at all: its exhausted weekly window arrives
as `percentage: 100` and the shared classifier renders the red `✗` the user can
already see in their own Z.ai panel.

# What Changes

- **An exhausted MiniMax window is reported, not dropped.** A window whose
  status is exhausted is reported with its consumed percent at 100, so it
  renders the same way Z.ai's exhausted weekly window renders - `7d 100%` with
  the red `✗` and `limit reached · … left`.
- **The endpoint's status outranks the reported percentage.** An exhausted
  window's percentage can be stale, and the percentage can be absent
  altogether; in both cases the status decides, and the window is reported as
  exhausted.
- **A plan entry is no longer rejected wholesale when the weekly percentage is
  missing.** The entry predicate currently demands both percentages, so an
  exhausted weekly window that omits its percentage costs the five-hour row
  too - the whole subscription then reports "no data" instead of "weekly
  exhausted".
- **Unlimited stays omitted, for a stated reason.** A window reporting
  unlimited quota has no limit to burn and nothing to project against, so its
  row stays absent. This is now a decision the tests pin, distinct from
  exhaustion rather than lumped with it.
- **The spec's `inactive window omitted` scenario is replaced.** It currently
  requires that any window whose status is not `1` be omitted, which is the
  defect itself.

# Capabilities

## New Capabilities

None. This change corrects how an existing capability reads a payload; it
introduces no new behaviour of its own.

## Modified Capabilities

- `quota-subscription-polling` - the `MiniMax payload interpretation`
  requirement. Its `inactive window omitted` scenario requires that a window
  whose status does not indicate an active plan be omitted, which is what
  deletes the exhausted weekly window. The requirement is reworded to separate
  the three statuses the endpoint actually reports: a limited window is
  reported, an exhausted window is reported as fully consumed, and an
  unlimited window is omitted.

# Impact

- `Sources/QuotaBarKit/Providers/MiniMaxProvider.swift` - `makeRow` learns the
  three statuses; `isPlanEntry` stops requiring the weekly percentage to
  accept an entry.
- `Sources/QuotaBarKitTests/ProviderTests.swift` - cases for an exhausted
  window, an exhausted window with a stale percentage, an exhausted window
  with no percentage, and an unlimited window.
- `openspec/specs/quota-subscription-polling/spec.md` - through this change's
  delta.
- No new dependencies, no API changes, no change to Z.ai, whose payload has no
  status field and already behaves correctly.
- User-visible: while a MiniMax window is exhausted, its row is present and
  reads `100%` with the red `✗`, and the menu bar glyph becomes `✗` instead of
  `✓`.

# Non-goals

- **Z.ai's five-hour window has no reset timestamp in the live payload** - the
  `unit: 3` entry carries no `nextResetTime`, so that row shows `no reset
  time` and cannot be projected. The app already renders this honestly; the
  missing field is a provider-side gap and is not addressed here.
- **`weekly_boost_permille` is ignored.** MiniMax reports a weekly display
  multiplier that upstream applies to the weekly percentage; QuotaBar clamps to
  0-100 instead. A separate question about boosted plans.
- **Which model bucket is read.** The parser takes the first entry that looks
  like a plan entry; upstream selects the `general` bucket explicitly. A
  payload carrying several buckets could therefore be read from the wrong one.
- **The window's own reset timestamps** are read as the endpoint reports them
  and are not second-guessed.
