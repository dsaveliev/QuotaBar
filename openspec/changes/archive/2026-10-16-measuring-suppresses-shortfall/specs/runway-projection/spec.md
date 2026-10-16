## MODIFIED Requirements

### Requirement: Measuring state

The system SHALL distinguish a window that is still collecting evidence from a
window that has evidence and found nothing to project, and SHALL report the first
as measuring rather than as an absence of data. When both would apply, the
measurement SHALL take precedence over anything the projection would otherwise
have to say.

#### Scenario: window below its threshold

- **WHEN** a window is below its evidence threshold but has samples
- **THEN** it reports itself as measuring, and its share of the way to the
  threshold is available for display

#### Scenario: window with no samples

- **WHEN** a window has fewer than the samples needed to project at all
- **THEN** it reports an absence of data rather than a measurement in progress

#### Scenario: measuring window shows no runway figure

- **WHEN** a window is measuring
- **THEN** the panel does not present a runway figure for it, since no figure
      drawn from so little evidence should be acted on

#### Scenario: trust threshold is one shared rule

- **WHEN** the evidence threshold is consulted
- **THEN** it is the same rule for every subscription, defined once rather than
  per provider or per window label

#### Scenario: measuring outranks the projection

- **WHEN** a window is below its evidence threshold and its projection, if taken
  at face value, would fall before its reset
- **THEN** it is reported as measuring, and the projection is not asserted

#### Scenario: the measurement outlasts the threshold

- **WHEN** a window that was measuring crosses its evidence threshold
- **THEN** it stops reporting a measurement in progress, and any shortfall its
  now-trusted projection shows is stated instead