# Tasks

## 1. Panel freshness

- [x] 1.1 Change `SubscriptionMenuView` to take a subscription id and resolve the snapshot from the model on every render; verify the panel's header, rows, and picker cannot disagree
- [x] 1.2 Verify with the live app that an open panel shows the same figures as the picker while a refresh lands

## 2. Label

- [x] 2.1 Render every window's percent in the menu bar label instead of only the most consumed; verify a two-window subscription reads `mmx 13%·42% !!` and a one-window subscription has no separator
- [x] 2.2 Attach a tooltip naming each window, the verdict in words, and the data age; verify the text and that a missing snapshot degrades to the id
- [x] 2.3 Update the label test that asserted the old single-percent form; verify the suite passes

## 3. Refresh feedback

- [x] 3.1 Publish `isRefreshing` on the model for the duration of a manual refresh; verify a second activation while in flight issues no request
- [x] 3.2 Swap the Refresh control to a spinner plus a distinct label while in flight and disable it; verify the data age updates when the result lands
- [x] 3.3 Show a spinner next to the loading text in the panel body so a cold start is visibly in progress rather than blank

## 4. Diagnostics

- [x] 4.1 Include each item's laid-out width in the menu bar log line, and rewrite the line only when items or labels change; verify the log names both providers with a non-zero width and stays quiet between refreshes

## 5. Verification

- [x] 5.1 Run `swift run QuotaBarKitTests` and confirm the full suite passes
- [x] 5.2 Rebuild, reinstall, and confirm the agent runs with both items present and both labels live
- [x] 5.3 Validate with `openspec validate --strict` and archive the change