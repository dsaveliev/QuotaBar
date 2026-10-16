# Tasks

## 1. The menu bar item

- [x] 1.1 Stop attaching a verdict image to a subscription item, leaving the
  trailing glyph in the text as the only verdict indicator; keep the symbol for
  the recovery slot, whose `QuotaBar` label carries no glyph. Verify: the item
  reads `zai 1%·52% ✓` with nothing in front of it, and the recovery item still
  shows its symbol
- [x] 1.2 Drop the now-unused `imageHugsTitle` / `imageLeading` handling from
  the update path so the item has one way to be drawn. Verify: `swift build` is
  clean and no unused-symbol warning remains in `StatusItemHost`

## 2. One item, created once

- [x] 2.1 Replace `StatusItemHost`'s dictionaries keyed by
  `MenuBarItems.Slot` with a single `NSStatusItem`, a single `NSPopover` and a
  `currentSlot` recording what that item currently shows. Verify: `swift build`
  passes and no `items` / `popovers` / `slotsByButton` dictionary remains
- [x] 2.2 Rewrite `reconcile()` so a slot change updates label, tooltip and
  image in place and creates or destroys nothing. Verify: selecting a different
  provider produces no `removeStatusItem` / new `NSStatusItem` — a single log
  line changes its label in place
- [x] 2.3 Remove `removeItem`'s `popovers[key]?.close()`, which is what closed
  the panel mid-use, and the `logStateIfChanged` bookkeeping that depended on
  slot-keyed items. Verify: the log still names the item and its width, once,
  whenever the label changes

## 3. The panel follows the selection

- [x] 3.1 Stop passing `subscriptionId` into `SubscriptionMenuView`; have it
  read the shown subscription from the model so a selection change republishes
  into the existing view. Verify: `AppModel` is still the only source, and the
  parameter is gone from the type
- [x] 3.2 Add one root view that renders subscription content or the recovery
  picker from the model's selection, so switching to `Show none` and back also
  stops rebuilding the popover. Verify: `Show none` shows the picker panel and
  `QuotaBar` in the bar, and switching back restores the subscription panel,
  neither closing the popover

## 4. Width and grid

- [x] 4.1 Change `StatusItemHost.panelWidth` from 320 to 280. Verify: the panel
  measures 280pt on screen
- [x] 4.2 Replace the three control bands with a 2×2 grid — `Refresh` and
  `Quit QuotaBar` in a left column, `every` and `provider` in a right column —
  both pickers at one width and one left edge, and delete the two dividers that
  split them. Verify: the two pickers share a left edge and a width in the
  screenshot, and one divider remains above the controls
- [x] 4.3 Delete the per-control `.frame(width: 82)` and `.frame(width: 140)`
  and the `Spacer(minLength:)` between `Refresh` and `every`. Verify: no fixed
  width remains on either picker

## 5. Verify and ship

- [x] 5.1 Run `swift run QuotaBarKitTests`; `MenuBarItems.desired` is unchanged,
  so the count must not move. Verify: same number of passing cases as before
  this change
- [x] 5.2 `openspec validate --specs --strict` after archiving; verify: no
  advisory
- [x] 5.3 `./scripts/install.sh`, then switch provider with the panel open and
  confirm from the log that the item's label changes in place, the panel stays
  open, and `Show none` reaches the recovery item without a reload. Verify:
  `tail ~/Library/Logs/QuotaBar/quotabar.err.log` shows one continuous item
  rather than a remove/add pair
- [x] 5.4 Check the panel's width and its longest lines. Width is confirmed by
  measurement on the installed app: the content measures exactly 280pt, and the
  306pt popover window is AppKit's own chrome around it. The lines present in
  ordinary use — the data-age line and the shortfall line — fit on one line in a
  screenshot. The no-token error body was NOT exercised, because producing it
  means breaking a working credential, which is not worth doing to check a wrap.
  SwiftUI `Text` wraps by default and this one has no line limit, so the
  expectation is sound; the confirmation is the screenshot that is missing.