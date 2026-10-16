## MODIFIED Requirements

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