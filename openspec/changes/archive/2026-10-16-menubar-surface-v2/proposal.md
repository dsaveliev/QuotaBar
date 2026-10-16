# Proposal

## Why

The first working build does not survive contact with the real menu bar. Three
defects, all visible in a screenshot taken on a real machine:

1. **The dropdown is unreadable.** It is styled with a native menu style, so
   macOS renders the SwiftUI content as an `NSMenu`: every element becomes a
   full-height menu row, non-interactive text is dimmed to disabled grey, the
   proportional usage bars disappear entirely, and the verdict colours are gone.
   The panel communicates nothing except its raw text.
2. **Only one of the two subscriptions appears.** With both configured and
   nothing hidden, the menu bar shows `mmx 41% ✓` and no Z.ai item at all. The
   scene-based item slots do not reliably insert a second status item.
3. **Hiding is a one-way door as far as the user can tell.** The control is
   labelled `Hide mmx from Menu Bar`, and the only way back is an "Hidden"
   list that is easy to miss and reads as an afterthought.

The domain layer underneath is sound — it is polling both providers correctly
and projecting runways against live data. Only the surface is wrong. This change
rebuilds the surface; it does not touch the domain.

## What Changes

- **BREAKING (implementation-level, not behavioural):** the surface moves off
  SwiftUI's `MenuBarExtra` scene machinery to `NSStatusItem` + `NSPopover`, so
  the number of menu bar items is driven directly by the subscriptions the user
  has chosen to show. Both subscriptions then reliably appear.
- The dropdown becomes a real SwiftUI panel: compact rows, visible usage bars
  with the pace marker, verdict-coloured glyphs, monospaced digits, and a
  fixed-width layout that no longer reflows per content.
- The provider list becomes a first-class, checkable control — "which providers
  do I want in the menu bar" is answered by ticking boxes, not by hunting for a
  separate Hide action and a buried recovery list.
- Hiding **all** providers is permitted and leaves a single recovery item in the
  menu bar whose only job is to bring providers back. The user is never trapped.
- The Hide action is replaced by the checkbox picker; the old buried "Hidden"
  list is removed, since the picker subsumes it.

## Capabilities

### New Capabilities

None — the surface's behaviour changes, but it stays one cohesive capability.

### Modified Capabilities

- `menubar-quota-surface`: menu bar item presence becomes user-selectable and
  deterministic; the dropdown gains a real panel layout and a provider picker;
  item visibility is reworked so hiding every provider is reversible from the
  menu bar.

## Impact

- Affected code: `Sources/QuotaBar/` only — the app scene, the popover host, and
  the two views. `Sources/QuotaBarKit/` is untouched, which is the point: the
  domain contract is not changing.
- `Sources/QuotaBarKitTests/` gains cases for the visibility rules that move
  from a "refuse to hide the last item" guard to "always leave a way back".
- No new dependencies. Deployment target stays macOS 13.
- No data migration: the existing `hiddenSubscriptions` setting is read as-is,
  so an installed app keeps the user's current choice.