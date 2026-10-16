# Spec Delta

## MODIFIED Requirements

### Requirement: Menu bar presence

The system SHALL present one menu bar item per subscription the user has chosen
to show, labelled with that subscription's short tag (`zai` for Z.ai, `mmx` for
MiniMax), and SHALL NOT appear in the Dock or the app switcher. The number of
items SHALL be derived directly from the current selection, so that adding,
removing, or toggling a subscription is reflected in the menu bar immediately
and for every subscription, not only for the first.

#### Scenario: both subscriptions visible at once

- **WHEN** the app is running and the user has both subscriptions shown
- **THEN** two independent menu bar items are present and each updates from its
  own subscription's data

#### Scenario: item count follows the selection

- **WHEN** the user changes which subscriptions are shown
- **THEN** the menu bar gains or loses exactly the corresponding items, with no
  item left behind and none missing

#### Scenario: agent, not a foreground app

- **WHEN** the app launches
- **THEN** it runs as a menu bar accessory with no Dock tile, no main window,
  and no menu bar takeover

### Requirement: Dropdown content

The system SHALL open each subscription's dropdown to a fixed-width panel
containing a header identifying the subscription with its data age, one row per
quota window laid out as a horizontal line with its label, a proportional usage
bar, the consumed percent, the verdict glyph, the time until reset, and the
projected runway, and a controls footer. The panel SHALL render these as
ordinary interface elements, so that bars and colours are visible and text is
not dimmed as inactive.

#### Scenario: per-window block

- **WHEN** a subscription reports a window
- **THEN** the row shows the window label, a visible proportional usage bar
  marking elapsed window time, the consumed percent, the verdict glyph, the
  time until reset, and the projected runway

#### Scenario: header freshness

- **WHEN** the dropdown is open
- **THEN** the header shows the subscription name and how long ago the data was
  fetched

#### Scenario: readable, not dimmed

- **WHEN** the dropdown is open
- **THEN** text and bars render at full contrast, and the verdict glyph and bar
  carry the verdict's colour, rather than appearing as inactive menu items

#### Scenario: controls

- **WHEN** the dropdown is open
- **THEN** it offers a refresh-now control, an interval setting, the provider
  picker, and a quit control

### Requirement: Item visibility

The system SHALL let the user choose which subscriptions appear in the menu bar,
SHALL keep hidden subscriptions polling and retaining their data, and SHALL
always leave at least one menu bar item through which the user can change that
choice again.

#### Scenario: item hidden

- **WHEN** the user unchecks a subscription in the provider picker
- **THEN** its item disappears from the menu bar while the subscription keeps
  refreshing, keeps its sample history, and its choice persists across restarts

#### Scenario: hidden item still reachable

- **WHEN** at least one subscription is shown
- **THEN** the provider picker lists every subscription, including hidden ones,
  and re-enabling one restores its menu bar item

#### Scenario: last item hidden

- **WHEN** the user unchecks the last shown subscription
- **THEN** a single recovery item remains in the menu bar whose panel offers the
  provider picker, so the user can bring subscriptions back without reinstalling
  or editing a file

#### Scenario: choice survives a restart

- **WHEN** the app is relaunched after the user changed which subscriptions are
  shown
- **THEN** the menu bar shows exactly the subscriptions the user chose

## ADDED Requirements

### Requirement: Provider picker

The system SHALL present, in every panel, one checkable control per supported
subscription, showing whether it is currently shown and its live percent, and
SHALL apply a change to the menu bar immediately when it is toggled.

#### Scenario: picker reflects the current selection

- **WHEN** a panel is open
- **THEN** each subscription is listed with a checkmark when it is shown and no
  checkmark when it is hidden, together with its current percent

#### Scenario: toggle applies immediately

- **WHEN** the user toggles a subscription in the picker
- **THEN** its menu bar item appears or disappears without a restart and without
  closing the panel

#### Scenario: picker lists every supported subscription

- **WHEN** a panel is open
- **THEN** the picker lists all subscriptions the app supports, including any
  that have no usable credential, so the user can see what is available

#### Scenario: panel of a hidden-all app

- **WHEN** every subscription is hidden and the recovery item's panel is opened
- **THEN** the panel shows the picker with every subscription unchecked, and no
  quota figures for subscriptions that have no visible item