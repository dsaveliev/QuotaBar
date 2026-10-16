# Proposal

## Why

The panel is wider than its content needs, its controls do not line up, and
switching provider tears the menu bar item down and builds it again — so the
panel the user is looking at closes while they use it.

The rebuild is the expensive one. `StatusItemHost` keys its items and popovers
by `MenuBarItems.Slot`, and the slot carries the provider id. Selecting a
different provider therefore changes the slot's identity, and `reconcile()`
answers that as "remove one item, add another": a new `NSStatusItem`, a new
`NSPopover`, a new hosting controller, and the old popover closed. Switching
provider is a change of *content*, but the surface has only ever had one slot,
so it should never have been a change of *structure*.

The layout complaints share a root cause: nothing in the panel is defined in
terms of anything but its own content. `panelWidth` is a fixed 320pt whatever
the content says, the two pickers are separately sized frames (82pt and 140pt),
their labels are different strings, and the rows push their two ends to
opposite edges of a width chosen before anything was measured. Remove the
duplicated verdict glyph, define one column grid, and pick a width that fits.

## What Changes

- **The menu bar item loses its leading symbol.** It currently renders as
  `[✓] zai 1%·52% ✓` — the verdict twice, once as a template image and once
  as the trailing glyph in the text. The text glyph stays and carries the
  verdict's colour; the item becomes `zai 1%·52% ✓`. The recovery slot keeps
  its symbol, because its label is the word `QuotaBar` with no glyph to carry
  one.
- **Switching provider no longer rebuilds the menu bar item.** The status item
  and its popover are created once and kept. The panel swaps which snapshot it
  reads, and an open panel updates in place instead of closing.
- **The panel is 280pt wide**, down from 320. The longest strings the panel
  renders still fit on one line; if that stops being true the width can go back,
  but 320 was chosen before anything was measured and 40pt of it was dead.
- **The controls sit on one grid.** Two rows: `Refresh` and `Quit QuotaBar` on
  the left of the first, `every` and `provider` stacked in a right-hand column
  of equal width. The three separate bands and their two dividers go, since they
  divided a control area into sections rather than aligning it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the menu bar label loses its duplicated leading
  symbol, the item's identity stops changing when the provider does, and the
  panel gains a stated width and a stated control grid.

## Impact

- `Sources/QuotaBar/StatusItemHost.swift` — item and popover lifetime,
  `reconcile()`, `updateLabel()`, and the image handling in the menu bar item.
- `Sources/QuotaBar/SubscriptionMenuView.swift` — `panelWidth`, the controls
  section, `ProviderPicker`.
- `Sources/QuotaBarKit/Engine/MenuBarItems.swift` — `Slot` stops carrying the
  provider id, or gains a separate identity the host can key on.
- Tests in `Sources/QuotaBarKitTests/SettingsTests.swift` cover
  `MenuBarItems.desired`, which is unchanged; the reconciliation changes are in
  the app target and are not unit-tested today.
- No data migration: nothing is persisted about slots, only about the selection.
- The app is rebuilt and reinstalled so the change is visible.