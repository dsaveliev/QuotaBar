# Tasks

## 1. Visibility rules

- [x] 1.1 Change `Settings.setHidden` so hiding every subscription is permitted and persisted verbatim, dropping the refuse-the-last-hide guard; verify a full-hide round-trips through `SettingsStore`
- [x] 1.2 Add a pure `desiredMenuBarItems(providers:selected:)` helper in the Kit that returns the shown subscriptions, or a single recovery item when none are shown; verify its cases (both shown, one shown, none shown)

## 2. Status item host

- [x] 2.1 Replace the `MenuBarExtra` scene with an `NSApplicationDelegate` that creates, removes, and re-labels `NSStatusItem`s to match the desired list on every published change; verify both subscriptions produce two items
- [x] 2.2 Host `SubscriptionMenuView` in an `NSPopover` per item with transient behaviour and a fixed 320pt width; verify the panel opens from each item and closes on an outside click
- [x] 2.3 Render the recovery item when nothing is selected: its panel shows the picker and no quota figures; verify the app stays reachable from the menu bar in that state

## 3. Panel layout

- [x] 3.1 Rebuild the dropdown as a fixed-width SwiftUI panel: header, one row per window (label, percent, coloured glyph, full-width bar with pace marker, reset countdown, runway line), and a controls footer; verify no element renders dimmed and bars are visible
- [x] 3.2 Give the verdict glyph and the usage bar one shared colour per verdict, and use monospaced digits for percent and durations; verify colours and digits are applied
- [x] 3.3 Replace the Hide action and the buried "Hidden" list with a Providers picker: a checkmark per subscription plus its live percent, toggling immediately without closing the panel

## 4. Verification

- [x] 4.1 Run `swift run QuotaBarKitTests` and confirm the full suite passes, including the replaced visibility cases
- [x] 4.2 Rebuild and reinstall; verify the menu bar reports both providers through the app's own log, and that each panel is hosted in an `NSPopover`
- [x] 4.3 Exercise the picker end to end: hide every provider, confirm the recovery item appears, confirm hidden subscriptions keep sampling, then re-enable and confirm both items return
- [x] 4.4 Validate with `openspec validate --strict` and archive the change