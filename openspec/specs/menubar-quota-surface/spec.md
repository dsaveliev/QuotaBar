# menubar-quota-surface Specification

## Purpose
Defines what the user actually sees in the macOS menu bar: a single compact
status item for the selected subscription, the dropdown that carries the full
picture, and the controls the user has there.

## Requirements

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

### Requirement: Compact status label

The system SHALL render each item's label as the consumed percent of every
window the subscription reports, then the subscription tag, then a verdict glyph
for the aggregate verdict, with the windows separated from each other by a
space so they stay distinguishable. The verdict glyph SHALL be the item's only
verdict indicator: no second symbol is placed beside it. It SHALL attach to the
item an unabbreviated explanation naming each window with its percent, the
verdict in words, and the age of the data. The label SHALL be rendered so that
every character it contains has the same advance width, so the item's rendered
width follows the number of windows and does not change as figures or verdicts
change.

#### Scenario: healthy label

- **WHEN** the aggregate verdict is `ok` and the windows are at 62% and 41%
- **THEN** the label reads ` 62% 41% zai  ✓`, so the figures lead, the tag
  separates them from the verdict, and both windows are shown rather than only
  the more consumed one

#### Scenario: urgent label

- **WHEN** the aggregate verdict is `short` and the windows are at 13% and 42%
- **THEN** the label reads ` 13% 42% mmx  !!`, so both the severity and which
  window is behind are legible without opening the menu

#### Scenario: single-window subscription

- **WHEN** a subscription reports only one window
- **THEN** the label shows that window's percent, the tag, and the verdict, with
  no trailing separator

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

#### Scenario: figures from before this launch

- **WHEN** the app starts and a subscription has figures restored from a
  previous run that no refresh this launch has confirmed yet
- **THEN** its label shows those figures immediately and withholds the verdict,
  ending in `?` until the first live answer arrives

#### Scenario: the item does not resize as figures change

- **WHEN** a subscription's figures change from two digits to three, or from
  one percent to a different one entirely
- **THEN** the item's rendered width is unchanged, so the menu bar does not
  reflow and the figures the user is reading do not shift sideways

#### Scenario: the item does not resize as the verdict changes

- **WHEN** the aggregate verdict changes between glyphs of different natural
  widths, such as a two-character mark and a single check
- **THEN** the item's rendered width is unchanged, because the glyph occupies
  the same width as any other character in the label

#### Scenario: each field reserves its widest value

- **WHEN** a live label is rendered
- **THEN** each percent occupies four characters, the provider tag three, and the
  verdict glyph two, so the widest possible figures define the item's width

#### Scenario: padding is never trailing

- **WHEN** a live label is rendered
- **THEN** the space reserved for a shorter figure precedes it rather than
  following it, so no field ends the label on padding

#### Scenario: equal characters are required, not merely equal padding

- **WHEN** the label's fixed fields are reserved by padding
- **THEN** the padding is only equivalent in width if every character shares one
  advance width; a font that spaces digits evenly but renders the percent sign
  or the verdict glyph wider leaves the item still resizing, and SHALL NOT be
  used for the label

#### Scenario: the figures carry no punctuation

- **WHEN** a subscription reports more than one window
- **THEN** the windows are separated by a space and no other character, so
  three-digit percentages read as two figures rather than running together

#### Scenario: the tag separates the figures from the verdict

- **WHEN** a live label is rendered
- **THEN** the provider tag sits between the last figure and the verdict glyph,
  so a reader does not take the verdict for a further figure or the figures for
  a reading of the verdict

### Requirement: Label states

The system SHALL show a distinct label for each of the three data states — live,
loading, and error — and SHALL keep the subscription's tag visible in every one
of them. A missing credential SHALL be an error state like any other, with the
dropdown rather than the label naming which credential is missing and where it
is looked up, so the label stays narrow enough to read at a glance. Loading
applies only before any figures exist; afterwards figures are shown and only
the verdict is withheld.

#### Scenario: before the first refresh completes

- **WHEN** a subscription has no figures to show, because it has never been
  fetched and none were restored from a previous run
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

#### Scenario: the verdict is stated once

- **WHEN** a subscription's item is shown
- **THEN** the verdict appears once, as the trailing glyph of the text, and no
  leading image carries it a second time

#### Scenario: the recovery item keeps a symbol

- **WHEN** no subscription is selected and the item reads `QuotaBar`
- **THEN** the item still shows its symbol, because that label carries no verdict
  glyph to take the item's place

#### Scenario: figures from before this launch

- **WHEN** the app starts and a subscription has figures restored from a
  previous run that no refresh this launch has confirmed yet
- **THEN** its label shows those figures immediately and withholds the verdict,
  reading `?` until the first live answer arrives

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

### Requirement: Quit

The system SHALL terminate cleanly on quit and persist settings and sample
history, so the next launch resumes with the same configuration and projection
basis. A normal exit SHALL be final: the app stays off until the user starts it
again. An abnormal exit SHALL be recovered automatically, and the app SHALL be
running whenever the user is logged in.

#### Scenario: quit and relaunch

- **WHEN** the user quits the app and launches it again
- **THEN** the interval setting, item visibility choices, and sample histories
  are as they were at quit

#### Scenario: a graceful quit stays off

- **WHEN** the user quits the app from its panel
- **THEN** the app is no longer running and is not started again by itself

#### Scenario: an abnormal exit is recovered

- **WHEN** the app terminates without exiting normally, such as a crash or a
  forced kill
- **THEN** the app is started again automatically

#### Scenario: the app is present at login

- **WHEN** the user logs in
- **THEN** the app is running

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

### Requirement: Status label contents

The system SHALL render each item's label as the subscription tag and a verdict
glyph for the aggregate verdict, and SHALL NOT put a window's consumed percent
in it. The verdict glyph SHALL be the item's only verdict indicator: no second
symbol is placed beside it. It SHALL attach to the item an unabbreviated
explanation naming each window with its percent, the verdict in words, and the
age of the data, so the figures the label omits are one hover away. The label
SHALL be rendered so that every character it contains has the same advance
width, so the item's rendered width follows its own shape and nothing else. The tag and the glyph SHALL be
written with no separator and no padding between them, so the item reads as the
subscription's state rather than as two fields.

#### Scenario: healthy label

- **WHEN** the aggregate verdict is `ok`
- **THEN** the label reads `zai✓`, naming the subscription and nothing but its
  state

#### Scenario: urgent label

- **WHEN** the aggregate verdict is `short`
- **THEN** the label reads `mmx!!`, so a subscription needing attention is
  legible without opening the menu

#### Scenario: single-window subscription

- **WHEN** a subscription reports only one window
- **THEN** its label is the same as for a subscription reporting several, since
  the label does not vary with the number of windows

#### Scenario: explanation

- **WHEN** an item's explanation is requested
- **THEN** it names each window with its own percent, states what the verdict
  means in words, and reports how long ago the data was fetched

#### Scenario: unknown or unmeasured label

- **WHEN** the aggregate verdict is `unknown`
- **THEN** the label ends in `?` rather than presenting a figure as if it were
  trustworthy

#### Scenario: the verdict is stated once

- **WHEN** a subscription's item is shown
- **THEN** the verdict appears once, as the trailing glyph of the text, and no
  leading image carries it a second time

#### Scenario: the recovery item keeps a symbol

- **WHEN** no subscription is selected and the item reads `QuotaBar`
- **THEN** the item still shows its symbol, because that label carries no verdict
  glyph to take the item's place

#### Scenario: figures from before this launch

- **WHEN** the app starts and a subscription has figures restored from a
  previous run that no refresh this launch has confirmed yet
- **THEN** its item shows the subscription and withholds the verdict, ending in
  `?` until the first live answer arrives, and the tooltip carries the figures

#### Scenario: the item does not resize as figures change

- **WHEN** a subscription's figures change from two digits to three, or from one
  percent to a different one entirely
- **THEN** the item's rendered width is unchanged, because the label carries no
  figure that could change it

#### Scenario: the item does not resize as figures change

- **WHEN** a subscription's figures change from two digits to three, or from one
  percent to a different one entirely
- **THEN** the item's rendered width is unchanged, because the label carries no
  figure that could change it

#### Scenario: the item may move when the verdict changes

- **WHEN** the aggregate verdict changes between a one-character glyph and a
  two-character one
- **THEN** the item MAY change width by exactly that one character, which is
  accepted: it happens on a verdict change and not on a refresh

#### Scenario: the tag and the glyph are one word

- **WHEN** a live label is rendered
- **THEN** no space, separator or padding sits between the provider tag and the
  verdict glyph

#### Scenario: the figures are not in the label

- **WHEN** a live label is rendered
- **THEN** it carries no percent and no separator between windows, so there is
  nothing in it that a reader could confuse with the verdict

#### Scenario: the figures are always reachable

- **WHEN** the user asks for an item's explanation
- **THEN** it names every window the subscription reports with its percent,
  even though the label shows none

### Requirement: Status label shape

The system SHALL render each item's label as the subscription tag and a verdict
glyph for the aggregate verdict, and SHALL NOT put a window's consumed percent
in it. The verdict glyph SHALL be the item's only verdict indicator: no second
symbol is placed beside it. It SHALL attach to the item an unabbreviated
explanation naming each window with its percent, the verdict in words, and the
age of the data, so the figures the label omits are one hover away. The label
SHALL be rendered so that every character it contains has the same advance
width, so the item's rendered width follows its own shape and nothing else. The
glyph SHALL occupy two characters, padded on the left, and no separator or
padding of the system's own SHALL sit between the tag and that field, so the
item reads as the subscription's state rather than as two fields.

#### Scenario: healthy label

- **WHEN** the aggregate verdict is `ok`
- **THEN** the label reads `zai ✓`, naming the subscription and nothing but its
  state

#### Scenario: urgent label

- **WHEN** the aggregate verdict is `short`
- **THEN** the label reads `mmx!!`, so a subscription needing attention is
  legible without opening the menu

#### Scenario: single-window subscription

- **WHEN** a subscription reports only one window
- **THEN** its label is the same as for a subscription reporting several, since
  the label does not vary with the number of windows

#### Scenario: explanation

- **WHEN** an item's explanation is requested
- **THEN** it names each window with its own percent, states what the verdict
  means in words, and reports how long ago the data was fetched

#### Scenario: unknown or unmeasured label

- **WHEN** the aggregate verdict is `unknown`
- **THEN** the label ends in `?` rather than presenting a figure as if it were
  trustworthy

#### Scenario: the verdict is stated once

- **WHEN** a subscription's item is shown
- **THEN** the verdict appears once, as the trailing glyph of the text, and no
  leading image carries it a second time

#### Scenario: the recovery item keeps a symbol

- **WHEN** no subscription is selected and the item reads `QuotaBar`
- **THEN** the item still shows its symbol, because that label carries no verdict
  glyph to take the item's place

#### Scenario: figures from before this launch

- **WHEN** the app starts and a subscription has figures restored from a
  previous run that no refresh this launch has confirmed yet
- **THEN** its item shows the subscription and withholds the verdict, ending in
  `?` until the first live answer arrives, and the tooltip carries the figures

#### Scenario: the item does not resize as figures change

- **WHEN** a subscription's figures change from two digits to three, or from one
  percent to a different one entirely
- **THEN** the item's rendered width is unchanged, because the label carries no
  figure that could change it

#### Scenario: the item does not resize as the verdict changes

- **WHEN** the aggregate verdict changes between a one-character glyph and a
  two-character one
- **THEN** the item's rendered width is unchanged, because the glyph occupies a
  reserved field of two characters whether or not it fills it

#### Scenario: the tag and the glyph are one word

- **WHEN** a live label is rendered
- **THEN** no separator sits between the provider tag and the glyph, and the
  space a one-character verdict appears to leave there is the glyph's own
  padding

#### Scenario: the figures are not in the label

- **WHEN** a live label is rendered
- **THEN** it carries no percent and no separator between windows, so there is
  nothing in it that a reader could confuse with the verdict

#### Scenario: the figures are always reachable

- **WHEN** the user asks for an item's explanation
- **THEN** it names every window the subscription reports with its percent,
  even though the label shows none
