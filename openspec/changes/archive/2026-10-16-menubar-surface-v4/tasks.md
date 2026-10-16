# Tasks

## 1. Selection

- [x] 1.1 Add `selectedProviderId` to `Settings`, persisted and defaulted to absent, with a setter used by the picker; verify a settings file written before this change loads without it and falls back
- [x] 1.2 Change `MenuBarItems.desired` to return exactly one slot — the selected provider, else the first shown provider, else recovery; verify each branch, including a selected provider that is hidden
- [x] 1.3 Wire the host's reconciliation and label update to the single slot; verify the item's label and icon follow the selection

## 2. Panel

- [x] 2.1 Remove the window-summary line from the header, keeping the name, verdict glyph, and data-age line; verify the header renders only those
- [x] 2.2 Replace the Providers checklist with a `Picker` in menu style listing every provider plus `Show none`; verify selecting a provider switches the panel and the menu bar item without closing it
- [x] 2.3 Verify `Show none` leaves the recovery item and that re-selecting a provider from it restores the item

## 3. Icon

- [x] 3.1 Add a verdict-to-symbol mapping and set it as the item's template image, with an accessibility description; verify every verdict maps to a non-nil symbol on macOS 13
- [x] 3.2 Verify the icon changes with the verdict and that the recovery item shows its own symbol

## 4. Runway line

- [x] 4.1 Render every window's runway line as `runway <projection>` regardless of verdict; verify an `ok` and a `short` window produce identically shaped readings
- [x] 4.2 Move the shortfall to its own muted line beneath the window and reword it; verify a short window shows the projection and the shortfall separately

## 5. Verification

- [x] 5.1 Update and extend the test suite; run `swift run QuotaBarKitTests` and confirm it passes
- [x] 5.2 Validate with `openspec validate --strict` and archive the change
- [x] 5.3 Rebuild, reinstall, and confirm the agent runs with a single item whose log line names the selected provider