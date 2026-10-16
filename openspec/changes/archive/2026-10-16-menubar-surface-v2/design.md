# Design

## Context

See `proposal.md` for the three observed defects and `specs/` for the revised
behaviour. What matters technically:

- The current surface is a SwiftUI `App` scene declaring four
  `MenuBarExtra(isInserted:content:label:)` slots. Two problems follow from
  that choice, both confirmed on a real machine rather than reasoned about:
  the `.menu` style hands the content to `NSMenu`, and a variable number of
  `isInserted` scene slots does not reliably produce more than one status item.
- `Sources/QuotaBarKit/` is correct and stays untouched. The domain contract is
  not part of this change.
- Deployment target stays macOS 13.

## Goals / Non-Goals

**Goals:**

- Menu bar item count derived directly from the user's selection, so every
  chosen subscription reliably appears.
- A panel that renders bars, colour, and full-contrast text.
- One obvious place to choose which providers are shown, reachable from any
  item, including when nothing is shown.

**Non-Goals:**

- Changing what the numbers mean. Verdicts, runway, staleness, and formatting
  are unchanged.
- Adding providers or making endpoints user-configurable.
- A settings window, a preferences pane, or any separate UI surface — everything
  stays inside the popover, because a menu bar accessory with a modal settings
  window is a worse experience than one with a well-organised popover.

## Decisions

### 1. `NSStatusItem` + `NSPopover` instead of `MenuBarExtra`

The app becomes an `NSApplicationDelegate`-driven process: a `Settings { EmptyView() }`
SwiftUI scene supplies nothing, and the delegate owns the status items.

Items are reconciled on every published model change: desired = the visible
subscriptions (or the single recovery item when there are none); the delegate
creates, removes, and re-labels `NSStatusItem`s to match, keyed by subscription
id. Toggling a checkbox therefore mutates the menu bar directly and
synchronously, with no dependence on scene insertion semantics.

*Alternative considered:* keeping `MenuBarExtra` with a different slot strategy
(or `.window` style, which alone fixes the layout). Rejected for presence: the
item count would still be at the mercy of scene machinery that has already been
observed to drop an item, and that failure mode is silent — the user sees a
missing subscription with no error anywhere. `NSStatusItem` fails loudly
instead: a missing item is a bug in a visible reconciliation, not in the
system's scene graph.

### 2. The popover hosts real SwiftUI

`NSPopover` with `.behavior = .transient`, content size ~320×nil, hosting
`SubscriptionMenuView` via `NSHostingView`. Everything renders as ordinary
SwiftUI: bars are `Capsule`s filled by a `GeometryReader`, the verdict glyph and
bar share one `Color`, digits are `.monospacedDigit()`, and text is
`.foregroundStyle(.primary)` rather than whatever a menu row would apply.

*Alternative considered:* a native `NSMenu` with custom `NSView` items. Rejected:
reimplementing layout by hand for the sake of avoiding `NSPopover`, while losing
live SwiftUI state updates for free.

### 3. Provider picker replaces Hide

The footer carries a "Providers" section: one row per supported subscription,
each a toggle button showing a checkmark when shown and its live percent
alongside. Toggling writes `hiddenSubscriptions`, persists it, and tells the
engine — which is all the reconciliation the status items need.

*Alternative considered:* keeping "Hide x" plus a separate "Hidden" list.
Rejected: two places to look for one concept, and the user's actual question was
"how do I get it back", which the picker answers in the same control that hides
it.

### 4. Hiding everything is allowed; a recovery item remains

The old rule refused to hide the last item. That is a trap-shaped rule: the
user is told "no" by a control that looks like a toggle. Instead, unchecking the
last provider removes every status item and inserts a single recovery item whose
panel is the picker alone. The app is always reachable, and the action the user
asked for always happens.

`Settings.setHidden` therefore loses its "refuse the last hide" guard; the
regression test for it is replaced by one asserting that the empty selection is
persisted verbatim and that the recovery item is what the UI renders.

### 5. Layout budget

The panel is a fixed 320pt wide so rows align across items. Each window row is
two lines: label + percent + glyph on the first, the 6pt bar spanning the full
width, then reset and runway on the third line — at 320pt that stays legible
without wrapping, which the screenshot shows it currently does not.

## Risks / Trade-offs

- **`NSStatusItem` ordering is owned by AppKit**, not by us → items appear in the
  order the user sees them and macOS may reorder on relaunch; acceptable, since
  the label carries the identity.
- **Reconciliation bugs would show as missing items** → `reconcile` is a pure
  function from snapshots to a desired item list, unit-tested; the AppKit side
  only applies the diff.
- **A popover can be dismissed by a click elsewhere** → `.transient` behaviour,
  which is the expected menu-bar idiom; refresh-on-open is already in place.
- **Two providers' data arriving at different times** → each item is
  independent; one showing `?` while the other shows a percent is correct, not a
  bug.
- **The user may still want the old one-item layout** → out of scope; the item
  count is user-controlled anyway, so hiding one provider gives exactly that.

## Migration Plan

`hiddenSubscriptions` is read unchanged, so an installed app keeps the user's
current selection with no migration step. Replacing the surface is a rebuild and
reinstall: `./scripts/install.sh`. Rollback is `./scripts/uninstall.sh` plus
rebuilding from the archived spec.