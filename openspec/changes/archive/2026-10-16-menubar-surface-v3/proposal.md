# Proposal

## Why

A screenshot of the rebuilt panel on a real machine showed three defects the
previous round did not catch, because none of them are visible in a unit test:

1. **The panel is permanently stuck on "loading".** The popover's hosting
   controller is built once, when the status item is created, and the view was
   handed a `SubscriptionSnapshot` **value**. Only the model is observed, so the
   menu bar label and the provider picker update while the panel keeps rendering
   the snapshot from the moment it was created — which is always the initial
   placeholder. The panel and its own picker disagree in the same screenshot:
   "Loading…" above, 42% and 52% below.
2. **The label shows one number for two windows.** `mmx 42%` is the weekly
   window. The five-hour window sits at 13% and is invisible, so the label does
   not say which window is about to run out — the single thing the label exists
   to say.
3. **Refresh looks broken.** It fires, but nothing on screen changes for seconds
   and there is no sign the click registered, so it reads as a dead button.

## What Changes

- The panel resolves its snapshot from the model by subscription id on every
  render instead of capturing one at construction. This is a defect fix, not a
  behaviour change: the panel is specified to show live data, and it was not.
- The menu bar label shows every window's percent (`mmx 13%·42% !!`), and the
  item gains a tooltip carrying the unabbreviated reading — each window named,
  the verdict in words, and the data age.
- The Refresh control shows a spinner and a changed label while the request is
  in flight, and cannot be re-triggered until it lands; the data-age line updates
  the moment it does.
- Menu bar items are logged with their laid-out width, so "my provider is
  missing" can be distinguished from "AppKit never gave it a size" — the failure
  this surface has already produced once.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label requirement now covers multi-window
  subscriptions and tooltips; the live-update requirement is tightened to cover
  an open panel; the manual-refresh requirement gains a visible in-flight state.

## Impact

- Affected code: `Sources/QuotaBar/` (host, panel, model) and two Kit files
  (`MenuBarItems.swift` for the tooltip, `SubscriptionSnapshot.swift` for the
  label). No change to polling, projection, verdicts, or persistence.
- Test suite gains cases for the multi-window label and the tooltip text.
- No migration: labels change shape, settings are untouched.