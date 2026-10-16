# Spec Delta

## MODIFIED Requirements

### Requirement: Menu bar presence

The system SHALL present exactly one menu bar item, labelled with the currently
selected subscription's short tag (`zai` for Z.ai, `mmx` for MiniMax), and SHALL
NOT appear in the Dock or the app switcher. The item's identity SHALL follow the
current selection immediately, so there is never more than one entrance to the
panel and never a subscription that can be "missing" because it lives behind a
second item.

#### Scenario: both subscriptions visible at once

- **WHEN** the app is running with both subscriptions available
- **THEN** one menu bar item is present, showing the currently selected
  subscription, and the panel behind it can show either

#### Scenario: item count follows the selection

- **WHEN** the user selects a different provider in the panel's picker
- **THEN** the single item's label, icon, and figures switch to that provider
  without a restart and without closing the panel

#### Scenario: nothing selected

- **WHEN** the user selects `Show none` for every subscription
- **THEN** the item is replaced by a single recovery item that opens the picker

#### Scenario: agent, not a foreground app

- **WHEN** the app launches
- **THEN** it runs as a menu bar accessory with no Dock tile, no main window,
  and no menu bar takeover

### Requirement: Provider picker

The system SHALL present, in every panel, a single selection control listing
every supported subscription plus an explicit `Show none` option, SHALL show
which subscription is currently selected, and SHALL apply a change immediately
when it is made.

#### Scenario: picker reflects the current selection

- **WHEN** a panel is open
- **THEN** the control reads as the selected provider's name, and every supported
  subscription appears as a choice

#### Scenario: toggle applies immediately

- **WHEN** the user selects a different provider
- **THEN** the panel's contents and the menu bar item switch to that provider
  without a restart and without closing the panel

#### Scenario: picker lists every supported subscription

- **WHEN** a panel is open
- **THEN** the picker lists all subscriptions the app supports, including any
  that have no usable credential, so the user can see what is available

#### Scenario: panel of a hidden-all app

- **WHEN** the user chooses `Show none`
- **THEN** no provider's limits are shown, and a recovery item remains in the
  menu bar whose panel offers the picker

#### Scenario: choice survives a restart

- **WHEN** the app is relaunched
- **THEN** the previously selected provider, or the recovery state, is restored

### Requirement: Dropdown content

The system SHALL open the panel to a header identifying the displayed
subscription with its verdict glyph and how long ago the data was fetched, one
row per quota window laid out as a horizontal line with its label, a proportional
usage bar, the consumed percent, the verdict glyph, the time until reset, and
the projected runway, and a controls footer containing the provider picker, a
refresh control, the interval setting, and a quit control. The header SHALL NOT
repeat the per-window figures that the rows below already carry.

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

### Requirement: Shortfall annotation

The system SHALL state, for a window whose projection runs dry before its reset,
how much earlier it runs out, on its own line beneath that window's runway line,
in muted text rather than in the verdict's colour. The runway figure itself
SHALL be presented identically for every window, regardless of verdict.

#### Scenario: runway line is uniform

- **WHEN** two windows are shown, one on pace and one short
- **THEN** both runway readings begin with the same `runway` label and show the
  projected duration alone

#### Scenario: shortfall stated

- **WHEN** a window's projection falls before its reset
- **THEN** a line beneath it says how much earlier it ends, in muted text

#### Scenario: blocked window

- **WHEN** a window's verdict is `blocked`
- **THEN** its runway line states that the limit is reached and when it resets,
  rather than projecting a runway