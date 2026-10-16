# Tasks

## 1. menubar-quota-surface

- [x] 1.1 Remove `Item visibility`; confirm its recovery-item guarantee is stated by `Menu bar presence` and `Provider picker`
- [x] 1.2 Reword `Label states` to three states, with a missing credential as an error the dropdown explains
- [x] 1.3 Shorten `Dropdown content` to structure, leaving the field lists to its scenarios
- [x] 1.4 Rewrite the `Menu bar item diagnostics` scenarios around the selection changing, and add the recovery item
- [x] 1.5 Fix the Purpose line, which says "one compact status item per subscription" and contradicts `Menu bar presence`. This is not a Requirement, so no delta can carry it: edit `openspec/specs/menubar-quota-surface/spec.md` directly in the same commit and say so in the commit message

## 2. runway-projection

- [x] 2.1 Restate "single moving window" as "a single sample is not a rate", reporting insufficient data
- [x] 2.2 Replace the verdict name `safe` with `ok`
- [x] 2.3 Give the two identically-titled "projection outlasts the reset" scenarios distinct titles
- [x] 2.4 Replace "a distinct marker for each of those four cases" with the four distinct statements the row makes, since no-limit and no-reset share a glyph and `RunwayState.markerText` is referenced nowhere

## 3. quota-subscription-polling

- [x] 3.1 Open `Freshness and staleness` with the last successful refresh, matching its own scenarios and the engine
- [x] 3.2 Drop the "no usable plan entry" clause from the region fallback, and add a scenario stating an empty plan does not probe another host

## 4. Verify

- [x] 4.1 Validate with `openspec validate specs-match-reality --strict`
- [x] 4.2 Archive, then `openspec validate --specs --strict` with no advisory left
- [x] 4.3 Re-run the suite: nothing here changes behaviour, so the count must not move
- [x] 4.4 Grep the merged specs for the retired vocabulary — two items, uncheck, safe, `HTTP 4xx`, `no data` as an error code — and confirm no survivors