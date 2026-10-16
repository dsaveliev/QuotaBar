# Proposal

## Why

An audit of all three specs against the code found that the menu bar label is
described by **three separate requirements**, one of them prescribing a format
the app no longer produces, and two of them saying the same thing.

| Requirement | Says the label is | Current? |
| --- | --- | --- |
| `Compact status label` | percent, then tag, then glyph | **no** — the app dropped the percent from the label |
| `Status label contents` | tag plus glyph | superseded, and one scenario says the item may move on a verdict change, which was reverted |
| `Status label shape` | tag plus glyph | yes |

The residue is from the label series: several times a scenario had to be
renamed, the validator refuses to rename one and refuses to let a MODIFIED
block drop one, and the only legal route was to retire the requirement and add
it under a new name. The retirements did not take.

`Status label contents` also carries the same scenario twice, byte for byte.

Separately, `Runway projection` has two scenarios both titled *"projection
outlasts the reset"* — the second says the exhaustion falls **before** the
reset and is reported as `short`, which is the opposite of its own title. This
is known debt, recorded when it could not be fixed through a delta.

## What Changes

- **`Compact status label` is removed.** It describes a label format that has
  not existed since the figures moved out of the menu bar.
- **`Status label contents` is removed.** `Status label shape` says the same
  thing correctly and carries one scenario fewer.
- **`Runway projection` is retired and re-added** with the two scenarios
  correctly titled: one for a projection that outlasts the reset, one for one
  that does not.

No requirement changes what it asks for. Every guarantee survives in the
requirement that is kept.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label has one requirement, not three.
- `runway-projection`: the two halves of the comparison have distinct titles.

## Impact

- Specification files only. No code, no behaviour, no test.
- The kept requirement, `Status label shape`, already matches the code; it is
  not modified here, only freed of its duplicates.