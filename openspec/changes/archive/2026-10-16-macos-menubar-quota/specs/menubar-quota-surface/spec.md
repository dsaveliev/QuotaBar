# Spec Delta

## Purpose

Defines what the user actually sees in the macOS menu bar: one compact status
item per subscription, the dropdown that carries the full picture, and the
controls the user has there.

## ADDED Requirements

### Requirement: Menu bar presence

The system SHALL present one menu bar item per tracked subscription, labelled
with that subscription's short tag (`zai` for Z.ai, `mmx` for MiniMax), and
SHALL NOT appear in the Dock or the app switcher.

#### Scenario: both subscriptions visible at once

- **WHEN** the app is running with both subscriptions configured
- **THEN** two independent menu bar items are present and each updates from its
  own subscription's data

#### Scenario: agent, not a foreground app

- **WHEN** the app launches
- **THEN** it runs as a menu bar accessory with no Dock tile, no main window,
  and no menu bar takeover

### Requirement: Compact status label

The system SHALL render each item's label as the subscription tag, the highest
consumed percent across that subscription's windows, and a verdict glyph for the
aggregate verdict.

#### Scenario: healthy label

- **WHEN** the aggregate verdict is `ok` and the highest consumed percent is 62
- **THEN** the label reads `zai 62% ✓`

#### Scenario: urgent label

- **WHEN** the aggregate verdict is `short`
- **THEN** the label reads `zai 96% !!`, so severity is legible without
  opening the menu

#### Scenario: unknown or unmeasured label

- **WHEN** the aggregate verdict is `unknown`
- **THEN** the label ends in `?` rather than presenting a number as if it were
  trustworthy

### Requirement: Label states

The system SHALL show a distinct label for each of the data states — live,
loading, error, and missing credential — and SHALL keep the subscription's tag
visible in every one of them.

#### Scenario: before the first refresh completes

- **WHEN** a subscription has not yet returned data
- **THEN** its label shows the tag followed by an ellipsis

#### Scenario: refresh failure

- **WHEN** the most recent refresh of a subscription failed
- **THEN** its label shows the tag followed by a question mark, and the previous
  numbers are not presented as current

#### Scenario: missing credential

- **WHEN** no credential resolves for a subscription
- **THEN** its label indicates the setup problem instead of a percent, and the
  dropdown states which credential is missing and where it is looked up

### Requirement: Dropdown content

The system SHALL open each subscription's dropdown to a header identifying the
subscription with its data age, one block per quota window, and a controls
section.

#### Scenario: per-window block

- **WHEN** a subscription reports a window
- **THEN** the block shows the window label, a proportional usage bar, the
  consumed percent, the verdict glyph, the time until reset, and the projected
  runway

#### Scenario: header freshness

- **WHEN** the dropdown is open
- **THEN** the header shows the subscription name and how long ago the data was
  fetched

#### Scenario: controls

- **WHEN** the dropdown is open
- **THEN** it offers a refresh-now control, an interval setting, a toggle to
  show or hide that subscription's menu bar item, and a quit control

### Requirement: Shortfall annotation

The system SHALL annotate a window whose projection runs dry before its reset
with the magnitude of the shortfall.

#### Scenario: shortfall stated

- **WHEN** a window's verdict is `short`
- **THEN** its runway line states the projected runway and the amount by which
  it falls short of the reset

#### Scenario: blocked window

- **WHEN** a window's verdict is `blocked`
- **THEN** its runway line states when the limit is reached rather than
  projecting a runway

### Requirement: Live update

The system SHALL update menu bar labels and dropdown content as refresh results
land, without requiring the user to reopen the menu.

#### Scenario: refresh while menu closed

- **WHEN** a scheduled refresh returns new data while no dropdown is open
- **THEN** the corresponding label shows the new percent and verdict on the next
  render

#### Scenario: refresh while menu open

- **WHEN** a scheduled refresh returns new data while that subscription's
  dropdown is open
- **THEN** the open dropdown's numbers update in place

### Requirement: Manual refresh

The system SHALL refresh immediately when the user activates refresh-now, and
SHALL refresh a subscription when its dropdown is opened if its data is older
than the configured interval.

#### Scenario: explicit refresh

- **WHEN** the user activates refresh-now
- **THEN** both tracked subscriptions issue a refresh regardless of when their
  timers last fired

#### Scenario: refresh on open

- **WHEN** a dropdown is opened and the subscription's data is older than the
  configured interval
- **THEN** that subscription issues a refresh before the dropdown settles

### Requirement: Interval setting

The system SHALL let the user change the refresh interval from the dropdown, and
SHALL apply the new interval to the next scheduled refresh without a restart.

#### Scenario: interval changed

- **WHEN** the user selects a new refresh interval
- **THEN** subsequent refreshes occur at the new cadence and the choice persists
  across restarts

#### Scenario: out-of-range interval rejected

- **WHEN** a selected interval is below the supported minimum or above the
  supported maximum
- **THEN** it is clamped into the supported range rather than accepted

### Requirement: Item visibility

The system SHALL let the user hide a subscription's menu bar item without
stopping its polling or losing its data, and SHALL restore the item when the
user shows it again.

#### Scenario: item hidden

- **WHEN** the user hides a subscription's menu bar item
- **THEN** the item disappears from the menu bar while the subscription keeps
  refreshing and its settings choice persists across restarts

#### Scenario: hidden item still reachable

- **WHEN** at least one subscription's item is visible
- **THEN** the hidden subscription can still be re-enabled from the visible
  item's dropdown

#### Scenario: last item hidden

- **WHEN** the user attempts to hide the only visible menu bar item
- **THEN** the item stays visible, since the app would otherwise be unreachable
  from the menu bar

### Requirement: Quit

The system SHALL terminate cleanly on quit, persisting settings and sample
history so the next launch resumes with the same configuration and projection
basis.

#### Scenario: quit and relaunch

- **WHEN** the user quits the app and launches it again
- **THEN** the interval setting, item visibility choices, and sample histories
  are as they were at quit