# Design

## Context

See `proposal.md` — Why, for the motivation.

The three things this change touches share one cause: the surface treats
"which provider is selected" as part of the menu bar item's *identity*, and
treats layout as a set of independently chosen numbers. Both are the residue of
a model the app no longer has — the old surface had one item per subscription,
so slot and identity really were the same thing.

What exists today:

- `MenuBarItems.desired(providers:settings:)` returns **at most one** slot
  (`.subscription(id)` or `.recovery`), and is pure and unit-tested.
- `StatusItemHost` keys `items`, `popovers` and `slotsByButton` by that slot.
  A new provider means a new slot, so `reconcile()` removes one item and adds
  another — new `NSStatusItem`, new `NSPopover`, new hosting controller, and the
  open popover explicitly closed by `removeItem`.
- `SubscriptionMenuView` captures `subscriptionId` at construction and reads
  `model.snapshot(id:)` with it, so its content is pinned to whichever provider
  the item was created for.
- `panelWidth` is 320; the two pickers carry independent `.frame(width:)` values
  of 82 and 140, and the controls are three bands separated by two dividers.
- `updateLabel` attaches a template `NSImage` of the verdict glyph in front of
  the title, which already ends in the same glyph.

One fact worth knowing before touching the image: template images are rendered
monochrome by the menu bar, so the leading glyph was **never** verdict-coloured.
Removing it is pure de-duplication and cannot lose colour.

## Goals / Non-Goals

**Goals:**

- A selection change is a content update. The status item, its popover and its
  hosting controller are created once and live until the app quits.
- An open panel stays open across a selection change, including into and out of
  the recovery state.
- One width, one grid, no per-control frame widths.

**Non-Goals:**

- No change to `MenuBarItems.desired`. It is correct, pure and tested; the bug
  is in how the host uses its return value.
- No per-window colour in the menu bar label. Making the trailing glyph carry
  the verdict's colour in a menu bar title is not something `NSStatusBarButton`
  offers, and it is out of scope.
- No change to the item's text format, the verdict ladder, or polling.
- Not making the app target unit-testable. See Risks.

## Decisions

### The host holds one item and treats the slot as content

Keep `MenuBarItems.desired` exactly as it is. Change what the host does with it.

`StatusItemHost` keeps a single `NSStatusItem`, a single `NSPopover` and a
single hosting controller, plus a `currentSlot` recording what that item is
currently displaying. `reconcile()` becomes:

1. If `desired` is empty and there is no item, create one showing the recovery
   slot.
2. If `desired.first` differs from `currentSlot`, update the label, tooltip and
   image in place and record the new slot. Nothing is created or destroyed.

Rejected: adding a separate `ItemIdentity` type and keying the dictionaries by
it. It adds a second notion of "what slot is this" to keep in step with the
first, and buys nothing — the host only ever wants one item. The one-item form
makes "there is exactly one menu bar item" a type-level fact rather than a
runtime invariant.

Rejected: keeping the dictionaries keyed by slot and special-casing the
subscription-to-subscription transition. That special case is precisely the
teardown being removed, just with a condition on it.

### The panel reads the selection instead of capturing it

This is what makes the above work. `SubscriptionMenuView` currently takes
`subscriptionId` and captures it in the hosting controller's root view, so a
provider change cannot reach it without rebuilding the controller.

Replace that parameter with a read of the model. `AppModel` already exposes the
shown subscription (`shown`), and `selectProvider` publishes, so an
`@ObservedObject` view that asks the model re-renders on the change by itself.
The root view then needs to choose between subscription content and the recovery
picker; both are cheap SwiftUI, so one root view switching on the model's
selection covers both, and `Show none` stops rebuilding anything too.

This is also why the guarantee survives as a *structural* property rather than a
branch: there is no captured id left to go stale, so there is nothing that
*could* require a rebuild on selection change.

### The width is one constant, and the grid is two columns

`panelWidth` becomes 280. Content width is that minus 24pt of padding, 256pt.

The controls become a 2×2 grid: actions on the left (`Refresh`, then
`Quit QuotaBar`), settings on the right (`every`, then `provider`), with both
pickers at one width and one left edge. The two dividers between the bands go;
the one above the controls stays, because that one separates data from controls
rather than splitting one control area into three.

Removed: the `.frame(width: 82)` and `.frame(width: 140)` on the pickers, and
the `Spacer(minLength:)` that separated `Refresh` from `every`. The grid
positions them; a spacer would make the alignment depend on the remaining
width rather than on the grid.

Rejected: a three-column row (`Refresh | every | provider`) with `Quit` below.
It is shorter, but it leaves two differently-sized controls sharing a row with
nothing on the left of `provider`, which is the unevenness being fixed.

## Risks / Trade-offs

- **Long strings now have less room.** At 256pt of content, an error body such
  as `no token (minimax login or MINIMAX_API_KEY)` wraps to two lines. That is
  acceptable — the panel grows downward, which is what it already does for a
  long provider name — and it is the intended trade for 40pt of dead width.
  → Mitigation: check the widest strings in the panel before shipping and widen
  back if any of them truncates rather than wraps.

- **A single item is a stronger coupling than a dictionary of them.** If a
  future requirement wants a second menu bar item, the host has to be rebuilt
  rather than extended. That is a deliberate consequence of a spec that says
  "exactly one menu bar item"; the day that changes, this design is the thing to
  revisit, and it will be visible.

- **The "no rebuild" guarantee is not unit-tested.** The app target has no test
  harness, and `MenuBarItems.desired` is a pure function that cannot express
  "did the host rebuild". → Mitigation: verify on the installed app by watching
  the log line and the panel across a switch, and rely on the structural change
  (nothing captures the provider id) for the part that would otherwise need a
  test.

- **Removing the leading symbol slightly shortens the bar but loses nothing
  else**, because template images are monochrome. Worth stating explicitly
  because the image looked like it was encoding the verdict.

## Migration Plan

None. Nothing persisted refers to slots — `settings.json` holds the selection,
which is unchanged. Existing installs pick this up on the next
`./scripts/install.sh`.

## Open Questions

None. The width, the control arrangement and the recovery item's symbol were
resolved with the user before drafting.