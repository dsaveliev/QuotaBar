# Spec Delta

## MODIFIED Requirements

### Requirement: Compact status label

The system SHALL render each item's label as the subscription tag, the consumed
percent of every window the subscription reports, separated so they stay
distinguishable, and a verdict glyph for the aggregate verdict. It SHALL attach
to the item an unabbreviated explanation naming each window with its percent,
the verdict in words, and the age of the data.

#### Scenario: healthy label

- **WHEN** the aggregate verdict is `ok` and the windows are at 62% and 41%
- **THEN** the label reads `zai 62%·41% ✓`, showing both windows rather than
  only the more consumed one

#### Scenario: urgent label

- **WHEN** the aggregate verdict is `short` and the windows are at 13% and 42%
- **THEN** the label reads `mmx 13%·42% !!`, so both the severity and which
  window is behind are legible without opening the menu

#### Scenario: single-window subscription

- **WHEN** a subscription reports only one window
- **THEN** the label shows that window's percent alone, without a separator

#### Scenario: explanation

- **WHEN** an item's explanation is requested
- **THEN** it names each window with its own percent, states what the verdict
  means in words, and reports how long ago the data was fetched

#### Scenario: unknown or unmeasured label

- **WHEN** the aggregate verdict is `unknown`
- **THEN** the label ends in `?` rather than presenting a number as if it were
  trustworthy

### Requirement: Live update

The system SHALL update menu bar labels, panel contents, and the provider picker
as refresh results land, without requiring the user to reopen the menu and
without any of the three reading from a snapshot captured before the result
arrived.

#### Scenario: refresh while menu closed

- **WHEN** a scheduled refresh returns new data while no panel is open
- **THEN** the corresponding label shows the new percent and verdict on the next
  render

#### Scenario: refresh while menu open

- **WHEN** a refresh returns new data while that subscription's panel is open
- **THEN** the panel's header, rows, and data age update in place, without being
  reopened

#### Scenario: panel and picker agree

- **WHEN** a panel is open at the same time as its provider picker
- **THEN** both show the same figures, so neither can display a loading or stale
  reading while the other shows live data

### Requirement: Manual refresh

The system SHALL refresh immediately when the user activates refresh-now, SHALL
refresh a subscription when its panel is opened if its data is older than the
configured interval, and SHALL make the request's progress visible for as long
as it is in flight.

#### Scenario: explicit refresh

- **WHEN** the user activates refresh-now
- **THEN** both tracked subscriptions issue a refresh regardless of when their
  timers last fired

#### Scenario: refresh on open

- **WHEN** a panel is opened and the subscription's data is older than the
  configured interval
- **THEN** that subscription issues a refresh before the panel settles

#### Scenario: progress is visible

- **WHEN** a refresh requested from the panel is in flight
- **THEN** the control shows a progress indicator and a distinct label, and the
  data age updates as soon as the result lands

#### Scenario: refresh cannot be stacked

- **WHEN** the user activates refresh while a refresh is already in flight
- **THEN** no second request is started until the first one finishes

## ADDED Requirements

### Requirement: Menu bar item diagnostics

The system SHALL write to its log every menu bar item it creates or removes,
together with the item's label and its laid-out width, and SHALL rewrite that
line whenever the set of items or their labels changes.

#### Scenario: both providers present

- **WHEN** both subscriptions are shown and reporting
- **THEN** the log names both items with their labels and a width greater than
  zero, so a present item is distinguishable from one AppKit refused to lay out

#### Scenario: item removed

- **WHEN** the user hides a subscription
- **THEN** the next log line no longer names that item

#### Scenario: log is quiet when nothing changes

- **WHEN** refreshes land but the set of items and their labels are unchanged
- **THEN** no further menu bar line is written, so the log stays readable