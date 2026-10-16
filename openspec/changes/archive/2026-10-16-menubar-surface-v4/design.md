# Design

## Context

See `proposal.md` for the requested changes and `specs/` for the revised
behaviour. What shapes the implementation:

- The panel is already a full SwiftUI view hosted in an `NSPopover`; changing
  what it shows is view work, not architecture work.
- The menu bar currently reconciles a list of slots. With one item the list has
  one element, and what changes is *which subscription that element is bound to*.
- `Settings` already persists a set of hidden ids; the selection needs a field
  beside it.

## Goals / Non-Goals

**Goals:**

- One menu bar item, whose identity is the selected provider.
- A picker that selects one provider at a time, with an explicit way to select
  none.
- A verdict icon that follows the menu bar theme.
- Runway readings that look the same whatever the verdict.

**Non-Goals:**

- Changing what a verdict means, or when one is trustworthy. The weekly-window
  false alarm is a real modelling weakness, but it changes verdicts rather than
  presentation, and is raised separately.
- Localisation, and any settings beyond the picker and the interval.
- Multiple simultaneous panels; one panel, one provider.

## Decisions

### 1. Selection lives in `Settings`, not in the host

`Settings.selectedProviderId: String?` sits beside `hiddenSubscriptions`. The
host asks `MenuBarItems.desired(...)` which returns a single slot: the selected
provider when it is still shown, otherwise the first shown provider, otherwise
`.recovery`.

*Alternative considered:* keeping the slot list and filtering to one. Rejected:
the fallback rule ("selected provider was hidden, show the first instead") is a
selection rule, and it belongs with the rest of the selection, not in the
reconciliation.

A `settings.json` written before this change has no `selectedProviderId`; it
loads as absent and falls back to the first shown provider, so no migration.

### 2. The picker is a native popup button

`Picker` with `.menu` style, bound to the selection, listing every provider plus
`Show none`. It renders as the same popup control the interval picker already
uses, so the footer reads as two settings rather than as a settings control and a
list of checkboxes.

The old checklist could express "two providers shown, one displayed", which is
exactly the state that produced the confusion. A single-selection control cannot
represent it, so the ambiguity is gone by construction.

### 3. Verdict icon is an SF Symbol template image

`NSImage(systemSymbolName:)` with `isTemplate = true`:

| Verdict | Symbol |
| --- | --- |
| ok | `gauge.with.dots.needle.bottom.50percent` |
| tight | `exclamationmark.triangle` |
| short | `exclamationmark.triangle.fill` |
| blocked | `xmark.octagon.fill` |
| unknown | `questionmark.circle` |
| recovery | `checklist` |

A template image is the correct macOS mechanism: the system recolours it for light
and dark menu bars and for the reduced-transparency setting, which a hand-drawn
SVG cannot do. SVG is also not a documented AppKit image format, so it was
rejected as the carrier.

*Alternative considered:* a coloured non-template image so severity is readable
by colour alone. Rejected: menu bar icons must survive theme changes and
assistance settings; severity is already carried by the glyph in the label.

### 4. Runway line is uniform; shortfall moves to its own line

The `warn` branch previously dropped the `runway` prefix and appended the
shortfall inline, so two rows of the same panel had different shapes. Now every
window renders `runway <projection>` and a short window adds one muted line
beneath: `ends 2d 5h before the reset`. The projection stops changing its
appearance when the verdict changes; only an extra line appears.

*Alternative considered:* colouring the shortfall with the verdict colour, which
is what made it read as alarm. Rejected: the row's bar and glyph already carry
severity; a second loud line for the same fact is noise.

## Risks / Trade-offs

- **Only one provider is glanceable from the menu bar** → the icon encodes
  severity and the label names the provider, so the item still answers "is
  anything wrong"; switching to see another provider is one click.
- **`Show none` is destructive-looking** → it is an explicit, named option rather
  than a checkbox that can be misread, and it leaves a recovery item behind.
- **Selecting a provider that is then hidden** → the fallback shows the first
  available provider rather than an empty item.
- **Symbol names are API, not literals** → they are macOS 13 symbols; a rename in
  a future OS would need a mapping table, which is a small, contained change.

## Migration Plan

None. `settings.json` without `selectedProviderId` loads with the field absent
and falls back to the first shown provider. Rebuild and reinstall with
`./scripts/install.sh`.