## REMOVED Requirements

Status label contents

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

## ADDED Requirements

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