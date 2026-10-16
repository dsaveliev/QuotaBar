## MODIFIED Requirements

### Requirement: Compact status label

The system SHALL render each item's label as the subscription tag, the consumed
percent of every window the subscription reports, separated so they stay
distinguishable, and a verdict glyph for the aggregate verdict. That trailing
glyph is the item's only verdict indicator: no second symbol is placed beside
it. It SHALL attach to the item an unabbreviated explanation naming each window
with its percent, the verdict in words, and the age of the data.

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

#### Scenario: the verdict is stated once

- **WHEN** a subscription's item is shown
- **THEN** the verdict appears once, as the trailing glyph of the text, and no
  leading image carries it a second time

#### Scenario: the recovery item keeps a symbol

- **WHEN** no subscription is selected and the item reads `QuotaBar`
- **THEN** the item still shows its symbol, because that label carries no verdict
  glyph to take the item's place

### Requirement: Menu bar presence

The system SHALL present exactly one menu bar item, labelled with the currently
selected subscription's short tag, and SHALL NOT appear in the Dock or the app
switcher. Changing the selection updates the contents of that item; it SHALL NOT
destroy and rebuild the item, and SHALL NOT close a panel the user has open.

#### Scenario: both subscriptions visible at once

- **WHEN** the app is running with both subscriptions available
- **THEN** one menu bar item is present, showing the currently selected
  subscription, and the panel behind it can show either

#### Scenario: item count follows the selection

- **WHEN** the user selects a different provider in the panel's picker
- **THEN** the single item's label and figures switch to that provider
  without a restart and without closing the panel

#### Scenario: nothing selected

- **WHEN** the user selects `Show none` for every subscription
- **THEN** the item is replaced by a single recovery item that opens the picker

#### Scenario: agent, not a foreground app

- **WHEN** the app launches
- **THEN** it runs as a menu bar accessory with no Dock tile, no main window,
  and no menu bar takeover

#### Scenario: an open panel survives the switch

- **WHEN** the panel is open and the user picks a different provider in it
- **THEN** the panel stays open and shows the new subscription, and the menu bar
  item is updated rather than removed and rebuilt

### Requirement: Dropdown content

The system SHALL compose the panel from a header identifying the displayed
subscription, one row per quota window laid out horizontally, and a controls
footer. The panel SHALL be 280 points wide. Its controls SHALL sit on a single
grid: `Refresh` and `Quit QuotaBar` share one row, and the interval and provider
pickers share a right-hand column of equal width, rather than each control
choosing its own frame and its own divider.

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

#### Scenario: pickers line up

- **WHEN** the panel is open
- **THEN** the interval and provider pickers share one width and one left edge,
  so the two labels read as a column rather than as two unrelated rows

#### Scenario: the panel is not wider than it needs

- **WHEN** the panel is open
- **THEN** it measures 280 points wide and no row in it is padded out to leave
  the controls floating at unrelated positions