# Tasks

## 1. The model decides

- [ ] 1.1 Add `WindowSnapshot.annotation`: the measuring text when the window is
  measuring, otherwise the shortfall text when the projection warrants one,
  otherwise nil — in that order. Verify: `swift build` is clean
- [ ] 1.2 Keep both strings word for word as they were, so no rendered text
  changes except by disappearing. Verify: `"measuring 68% of the evidence it
  needs"` and `"ends 4d 3h before the reset"` are unchanged

## 2. The view obeys

- [ ] 2.1 Render `window.annotation` and delete the two computed strings and the
  branch between them. Verify: `grep` finds no `shortfallText` or `measuringText`
  left in `WindowRowView`

## 3. Tests

- [ ] 3.1 A window that is measuring and whose runway state is `warn` states the
  measurement, not the shortfall. This is the regression: it is the state the
  panel actually showed. Verify: it fails against the old ordering
- [ ] 3.2 A window past its threshold whose projection falls before its reset
  states the shortfall. Verify: it fails if the precedence is inverted
- [ ] 3.3 A window on pace past its threshold states neither. Verify: `annotation`
  is nil
- [ ] 3.4 A window with no fraction available still says it is measuring rather
  than saying nothing. Verify: `measuredFraction == nil` gives `"measuring…"`

## 4. Verify and ship

- [ ] 4.1 `swift run QuotaBarKitTests`. Verify: 149 plus the new cases, passing
- [ ] 4.2 `./scripts/install.sh`, then look at a weekly window in its first
  hours of measurement. Verify: the panel shows `runway measuring…` and a
  progress line, and no shortfall line
- [ ] 4.3 Validate and archive. Verify: `openspec validate --specs --strict`
  reports no advisory