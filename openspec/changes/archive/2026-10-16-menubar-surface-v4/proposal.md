# Proposal

## Why

Three changes the user asked for after seeing the panel on a real machine.

1. **One menu bar item, not one per provider.** With a provider picker inside the
   panel, several items are two entrances to the same panel and it is never clear
   which item opens which provider. It also makes "I cannot see Z.ai" structurally
   impossible — there is exactly one place the data lives.
2. **The Providers checklist becomes a dropdown.** Showing one provider at a time
   is clearer than two checked rows under a panel that shows one of them, and a
   picker cannot be mis-read as "I just switched providers" when it was really
   "I just hid one".
3. **The header's window-summary line goes.** The rows below already carry the
   window label, percent, and verdict; the summary repeated all three one screen
   above. The header keeps its name, verdict glyph, and data-age line.

Plus one presentation defect found while looking at a screenshot: the runway line
changes shape when the verdict is `short` — it drops the `runway` prefix and
appends the shortfall inline, so two rows of the same panel read differently and
the second one reads as noise rather than as a number.

## What Changes

- The menu bar holds a single item, labelled with the currently selected
  provider; the panel's picker changes which provider that is.
- `Providers` becomes a picker: one provider at a time, plus `Show none`, which
  keeps the existing recovery-item path intact.
- The header drops the window-summary line and nothing else.
- The runway line is always prefixed `runway`, and a shortfall is reported on its
  own line in muted text rather than appended inline in the verdict colour.
- The item gains a template image (SF Symbol) that encodes the verdict, so
  severity is legible at a glance and the icon follows the menu bar theme.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: menu bar presence (one item), dropdown content (no
  summary line, picker instead of a checklist), compact status label (template
  image), provider picker (single selection, `Show none`), and shortfall
  annotation (own line, muted).

## Impact

- Affected code: `Sources/QuotaBarKit/Engine/{Settings,MenuBarItems}.swift` and
  `Sources/QuotaBar/{StatusItemHost,SubscriptionMenuView,WindowRowView,AppModel}.swift`.
- `Settings` gains a `selectedProviderId` field; existing `settings.json` files
  load without it and fall back to the first shown provider, so no migration.
- Test suite gains cases for the single-item derivation, selection persistence,
  and the `Show none` path.