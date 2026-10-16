# Proposal

## Why

`opencode-quota` already computes coding-plan limits and a burn-rate runway
projection, but that computation only exists while an OpenCode TUI session is
running and only for the single provider that session's model points at. Outside
OpenCode — in a terminal, in an editor, in another agent — there is no
indication of how much of the Z.ai or MiniMax plan is left or whether the
current pace outlasts the window. The menu bar is the one surface macOS keeps
visible regardless of what the user is doing, so a small menu bar agent gives
both subscriptions ambient visibility without needing to open anything.

## What Changes

- Add a native macOS menu bar agent (Swift + SwiftUI `MenuBarExtra`, `LSUIElement`)
  that shows **both** subscriptions simultaneously, one menu bar item per
  provider. It polls independently of any editor or agent session.
- Port the quota domain model from `opencode-quota` into Swift: unified quota
  rows, the burn-rate runway projection, the five-verdict ladder
  (`ok`/`tight`/`short`/`blocked`/`unknown`), and the duration/percent
  formatters — same semantics, same edge cases, so the two surfaces agree.
- Poll the two real endpoints directly: Z.ai
  `https://api.z.ai/api/monitor/usage/quota/limit` and MiniMax
  `https://api.minimax.io/v1/token_plan/remains` (with `.cn` fallback),
  including MiniMax's region detection and its percent-space pseudo-usage
  synthesis.
- Resolve credentials at runtime from `~/.local/share/opencode/auth.json`
  (`zai-coding-plan`, `zai`, `minimax-coding-plan`, `minimax-cn-coding-plan`,
  `minimax`) with `ZAI_TOKEN` / `Z_AI_TOKEN` / `MINIMAX_API_KEY` env
  fallback. Tokens are never logged and never rendered.
- Persist the per-window usage sample history to disk so a runway projection
  survives app restarts and is available immediately on launch instead of
  degrading to "no data" until two samples accumulate.
- Ship an Xcode-free build path: SwiftPM builds a plain executable, a script
  assembles and ad-hoc codesigns the `.app` bundle, and a `LaunchAgent` plist
  provides login persistence.

## Capabilities

### New Capabilities

- `quota-subscription-polling`: credential resolution per provider, endpoint
  probing with region detection, payload parsing into the unified quota row
  model, the polling cadence, and the error taxonomy surfaced in the UI.
- `runway-projection`: per-window usage sampling, burn-rate derivation,
  projected runway vs. window reset, and the verdict ladder derived from
  those numbers.
- `menubar-quota-surface`: the menu bar items and their dropdown contents —
  compact status labels, per-window gauges, freshness, error and loading
  states, manual refresh, and quit.

### Modified Capabilities

None — this is a new repository with no existing capability specs.

## Impact

- New standalone repository: no existing source files are modified. The only
  relationship to `opencode-quota` is deliberate behavioural parity of the
  domain logic, and the shared credential file.
- New toolchain: Swift 6.2 / SwiftPM, AppKit + SwiftUI (`MenuBarExtra`,
  deployment target macOS 13). No third-party dependencies.
- Build produces `QuotaBar.app` (ad-hoc signed, `LSUIElement`) installed into
  `/Applications`, plus `dev.dmitrii.quota-bar.plist` in
  `~/Library/LaunchAgents`.
- Reads `~/.local/share/opencode/auth.json` (read-only) and writes only under
  `~/Library/Application Support/QuotaBar`.
- Network egress: exactly the two provider quota hosts, `Authorization: Bearer`
  only, https only.