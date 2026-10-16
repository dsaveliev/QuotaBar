## MODIFIED Requirements

### Requirement: Dropdown content

The system SHALL compose the panel from a header identifying the displayed
subscription, one row per quota window laid out horizontally, and a controls
footer. The header SHALL NOT repeat the per-window figures that the rows below
already carry.

#### Scenario: per-window block

- **WHEN** a subscription reports a window
- **THEN** the row shows the window label, a visible proportional usage bar
  marking elapsed window time, the consumed percent, the verdict glyph, the
  time until reset, and the projected runway

#### Scenario: header freshness

- **WHEN** the panel is open
- **THEN** the header shows the subscription name, the aggregate verdict glyph,
  and how long ago the data was fetched, and no per-window summary line

#### Scenario: readable, not dimmed

- **WHEN** the panel is open
- **THEN** text and bars render at full contrast, and the verdict glyph and bar
  carry the verdict's colour, rather than appearing as inactive menu items

#### Scenario: controls

- **WHEN** the panel is open
- **THEN** it offers a provider picker, a refresh-now control, an interval
  setting, and a quit control

### Requirement: Label states

The system SHALL show a distinct label for each of the three data states — live,
loading, and error — and SHALL keep the subscription's tag visible in every one
of them. A missing credential SHALL be an error state like any other, with the
dropdown rather than the label naming which credential is missing and where it
is looked up, so the label stays narrow enough to read at a glance.

#### Scenario: before the first refresh completes

- **WHEN** a subscription has not yet returned data
- **THEN** its label shows the tag followed by an ellipsis

#### Scenario: refresh failure

- **WHEN** the most recent refresh of a subscription failed
- **THEN** its label shows the tag followed by a question mark, and the previous
  numbers are not presented as current

#### Scenario: missing credential

- **WHEN** no credential resolves for a subscription
- **THEN** its label shows the error state's question mark rather than a
  percent, and the dropdown states which credential is missing and where it is
  looked up

## ADDED Requirements

### Requirement: Menu bar item logging

The system SHALL write to its log every menu bar item it creates or removes,
together with the item's label and its laid-out width, and SHALL rewrite that
line whenever the set of items or their labels changes.

#### Scenario: the item is present

- **WHEN** a subscription is selected and reporting
- **THEN** the log names the item with its label and a width greater than zero,
  so a present item is distinguishable from one AppKit refused to lay out

#### Scenario: the item follows the selection

- **WHEN** the user selects a different provider
- **THEN** the next log line names the new item and no longer names the old one

#### Scenario: the recovery item takes over

- **WHEN** the user selects `Show none`
- **THEN** the next log line names the recovery item instead of a subscription

#### Scenario: log is quiet when nothing changes

- **WHEN** refreshes land but the item and its label are unchanged
- **THEN** no further menu bar line is written, so the log stays readable

## REMOVED Requirements

### Requirement: Menu bar item diagnostics

The system SHALL write to its log every menu bar item it creates or removes,
together with the item's label and its laid-out width, and SHALL rewrite that
line whenever the set of items or their labels changes.

Removed because two of its three scenarios can no longer be reached: they fire
when "both subscriptions are shown" and when "the user hides a subscription",
and the menu bar holds one item chosen by a picker, so neither situation
exists. The requirement is replaced by `Menu bar item logging`, which states
the same logging rule against the selection changing. No guarantee is lost.

### Requirement: Item visibility

The system SHALL let the user choose which subscriptions appear in the menu bar,
SHALL keep hidden subscriptions polling and retaining their data, and SHALL
always leave at least one menu bar item through which the user can change that
choice again.

Removed because it describes per-subscription visibility, a model the surface
does not have: the menu bar holds one item, and the picker selects which
provider it shows rather than which providers are visible. Its scenarios are
written in terms of unchecking a subscription, which no control does. The
guarantee it was reaching for — never stranding the user behind an empty menu
bar — is already stated by the "nothing selected" scenario of `Menu bar
presence` and the "panel of a hidden-all app" scenario of `Provider picker`, so
no guarantee is lost with the requirement.