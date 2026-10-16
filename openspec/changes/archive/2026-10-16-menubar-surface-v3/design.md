# Design

## Context

See `proposal.md` for the three observed defects and `specs/` for the revised
behaviour. The technical shape of the problem:

- `NSPopover` content is an `NSHostingController` whose root view is constructed
  once. That is the constraint the whole fix turns on: anything the panel needs
  to change has to arrive through an *observed* reference, not through a value
  captured at construction.
- `SubscriptionMenuView` already observed `AppModel`. The panel's own snapshot
  did not — it was a `let` parameter, so the view could not and did not change.
- The menu bar label is the only always-visible surface, so anything it omits is
  effectively invisible until the user opens a panel.

## Goals / Non-Goals

**Goals:**

- Panel, label, and picker read from one live source, so they cannot disagree.
- The label says which window is behind, not just how much is used.
- A control that is working looks like it is working.

**Non-Goals:**

- Changing what the numbers mean, or the polling cadence semantics.
- Adding a preferences window; everything stays in the panel.
- Localising the UI. The copy stays English for now; strings are already inline
  at their use sites, so a later localisation pass is additive.

## Decisions

### 1. The panel takes an id, not a snapshot

`SubscriptionMenuView(model:subscriptionId:)` resolves the snapshot from
`model.snapshot(id:)` inside `body`. The panel is then correct by construction:
there is no value that *can* go stale, so no future change can reintroduce this
bug by forgetting to make something observable.

*Alternative considered:* making the captured snapshot observable (`@Published`
holder in the host). Rejected: it keeps a second source of truth and a
synchronisation step; the id form deletes the problem instead of managing it.

### 2. Label shows all windows; tooltip carries the full reading

`mmx 13%·42% !!`. Two windows are the common case and both matter: the weekly
window is what surprises people, the five-hour window is what they act on. A
single number cannot express both.

The tooltip (`MiniMax — 5h 13%, 7d 42% · !! will run out before the reset ·
updated just now`) is where the unabbreviated version lives, which is why the
label can stay compact without becoming cryptic.

*Alternative considered:* show only the window with the worst verdict. Rejected:
the number would then change meaning between refreshes, which is worse than a
number that is merely wide.

### 3. Refresh reports its own progress

`AppModel.isRefreshing` is published for the duration of the call. The control
swaps its label to "Refreshing…" with a spinner, disables itself, and the data
age updates the instant the result lands. Re-triggering while in flight is
ignored — the engine already collapses overlapping requests, so a second click
would do nothing anyway, and saying so visually is more honest than pretending
to queue it.

### 4. Log menu bar geometry

The menu bar line now carries each item's laid-out width. An item that exists in
our state but was never given a size by AppKit is invisible and previously
indistinguishable from one that is fine; the width separates the two cases. The
line is rewritten only when the set of items or their labels changes, so a poll
every minute does not bury it.

## Risks / Trade-offs

- **Wider labels take more menu bar space** (`mmx 13%·42% !!` is roughly 120pt)
  → users who find it too wide can untick a provider in the picker; the tooltip
  covers readability.
- **A spinner on every 60s auto-refresh would be noise** → the spinner is tied to
  the manual control only; scheduled refreshes are silent, as before.
- **`isRefreshing` gates refresh-on-open too** → if a manual refresh is running
  when a panel opens, the panel does not start a second one; it shows the same
  in-flight result a moment later.
- **Tooltip text is English and inline** → acceptable now, additive to change
  later.

## Migration Plan

None. Settings are untouched; labels change shape only. Rebuild and reinstall
with `./scripts/install.sh`.