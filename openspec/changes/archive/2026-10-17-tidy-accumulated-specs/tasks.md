# Tasks

## 1. Remove the superseded label requirements

- [ ] 1.1 Remove `Compact status label`, which prescribes a percent-then-tag
  label the app stopped producing. Verify: the label format appears once in the
  spec, and it matches `SubscriptionSnapshot.menuBarLabel()`
- [ ] 1.2 Remove `Status label contents`, whose scenarios duplicate
  `Status label shape` and include a reverted "the item may move on a verdict
  change". Verify: no scenario title is duplicated inside one requirement

## 2. Retitle the runway comparison

- [ ] 2.1 Give the two halves of the runway comparison distinct titles, so the
  one describing a projection that falls before the reset is not called
  "outlasts the reset". Verify: no scenario title repeats inside a requirement,
  and each title agrees with its own WHEN

## 3. Verify

- [ ] 3.1 `openspec validate --specs --strict` reports no advisory. Verify: no
  duplicate scenario titles remain anywhere in the specs
- [ ] 3.2 The surviving label requirement still matches the code. Verify: read it
  against `menuBarLabel()` — tag plus a two-character glyph field, no percent
- [ ] 3.3 `swift run QuotaBarKitTests`. Verify: unchanged and passing, since
  nothing here touches code