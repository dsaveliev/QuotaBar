# Why

An audit of all three specs against the code found eleven places where the
specs are wrong. Most are stale text from the pre-v4 surface; two are places
where the spec is right and the code was broken (fixed in this change's code
commit), and one requirement describes a control that no longer exists at all.

The stale parts share a cause. The surface moved from one menu bar item per
subscription to a single item with a provider picker, and `Item visibility` -
the requirement describing the old checklist - was never retired. It now
contradicts two other requirements in the same file.

# What Changes

## menubar-quota-surface

- **Purpose** claims "one compact status item per subscription" while
  `Menu bar presence` says "exactly one menu bar item". The Purpose is wrong.
- **`Item visibility`** is removed. Every one of its four scenarios is about
  unchecking a subscription in a checklist; the picker is single-selection and
  nothing in the app can uncheck anything. Its one surviving idea - a recovery
  item so the user is never stranded - is already stated by `Menu bar presence`
  and `Provider picker`, so nothing is lost.
- **`Label states`** promises a distinct label for four states, one of them a
  missing credential. `SubscriptionSnapshot.State` has three, and a missing
  credential is an error code inside the error state that renders the same
  `tag ?` as a timeout. Reworded to what the surface does: the tag stays
  visible in all three states, and the dropdown names the credential problem.
- **`Dropdown content`** restated in prose the fields its own scenarios already
  enumerate, pushing the requirement to 531 characters. Trimmed to structure.
- **`Menu bar item diagnostics`** has a scenario that fires only when both
  subscriptions are shown at once, and another that fires when a subscription is
  hidden. Neither is reachable with one item; rewritten around the selection
  changing.

## runway-projection

- **"single moving window"** asserts that one sample reports no burn. The code
  and a test both report insufficient data, which is right: with one sample
  there is no burn *rate*. The scenario now states the code's behaviour.
- **"reported as safe"** names a verdict that does not exist; the ladder has
  `ok`.
- **"a distinct marker for each of those four cases"** — `RunwayState.markerText`
  maps no-limit and no-reset to the same glyph, and the property is referenced
  nowhere; the view spells the four cases out itself. Stated as the four
  distinct strings the row actually shows.

## quota-subscription-polling

- **`Freshness and staleness`** opens with "the gap between the last refresh
  attempt and now", but its own scenarios say "last successful refresh", and
  the engine ages from `updatedAt`, which is cleared on failure while an active
  error suppresses staleness outright. The opening sentence was wrong.
- **`Endpoint selection and region detection`** falls back to the regional host
  when a payload "carries no usable plan entry". It does not, and should not:
  the engine commits to a host once the envelope says success, so an empty plan
  reports "no data" rather than probing elsewhere. The provider's own doc
  comment and the README both say so. Only a genuine envelope failure falls
  through.

# Non-goals

- No behaviour change. Where code and spec disagreed on substance, the code was
  wrong and was fixed alongside these edits; every edit here is wording.
- The `Quit` requirement keeps its four scenarios and its awkward name. Splitting
  it is not expressible as a delta; see `tighten-quit-requirement`.