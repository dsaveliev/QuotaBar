## MODIFIED Requirements

### Requirement: Compact status label

The system SHALL render each item's label as the subscription tag, the consumed
percent of every window the subscription reports, separated so they stay
distinguishable, and a verdict glyph for the aggregate verdict. That trailing
glyph is the item's only verdict indicator: no second symbol is placed beside
it. It SHALL attach to the item an unabbreviated explanation naming each window
with its percent, the verdict in words, and the age of the data. The label
SHALL be rendered so that every character it contains has the same advance
width, so the item's rendered width follows the number of windows and does not
change as figures or verdicts change.

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

#### Scenario: figures from before this launch

- **WHEN** the app starts and a subscription has figures restored from a
  previous run that no refresh this launch has confirmed yet
- **THEN** its label shows those figures immediately and withholds the verdict,
  reading `?` until the first live answer arrives

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
- **THEN** the provider tag occupies three characters, each percent four, and
  the verdict glyph two, so the widest possible figures define the item's width

#### Scenario: padding is never trailing

- **WHEN** a live label is rendered
- **THEN** the space reserved for a shorter figure precedes it rather than
  following it, so the label ends on the verdict glyph

#### Scenario: equal characters are required, not merely equal padding

- **WHEN** the label's fixed fields are reserved by padding
- **THEN** the padding is only equivalent in width if every character shares one
  advance width; a font that spaces digits evenly but renders the percent sign
  or the verdict glyph wider leaves the item still resizing, and SHALL NOT be
  used for the label