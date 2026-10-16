# Context

The advisory is about prose length, and it is right that the prose was too
long. It is wrong that the fix has to be a structural one.

# Decisions

## Treat the validator's refusal as design input

Two rules blocked the split, and both protect something real: a `MODIFIED`
block may not quietly drop a scenario, and a requirement cannot be both
removed and added under one name. Together they mean a requirement's scenario
set is a contract that only grows, unless the whole requirement is retired.

That is a defensible rule. Silently dissolving scenarios is exactly how a spec
stops matching the code. Working around it with a duplicated requirement would
have bought tidiness at the price of two copies to keep in sync.

So the requirement stays whole, and the advisory is answered directly.

## Delete the restatement, keep every guarantee

The old text walked through all four guarantees in prose and then let the
scenarios say them again. The new text states the intent once and trusts the
scenarios for the detail:

- terminating cleanly and persisting state
- a normal exit is final
- an abnormal exit is recovered
- the app runs whenever the user is logged in

Each of those was already demonstrated by a scenario. The requirement text now
points at them rather than competing with them.

## The scenarios are not the thing being shortened

It would have been easy to get under the limit by deleting scenarios. That
would have made the advisory disappear and the spec worse. The four scenarios
come through verbatim, including their wording.

# Risks

- The requirement is still named `Quit` while covering startup and recovery.
  That is a naming debt, not a correctness problem: the alternative was
  duplicating scenarios, which is worse. It should be revisited if OpenSpec
  gains an operation that can move scenarios between requirements.
- A reader skimming only the requirement text now gets the guarantees in one
  sentence each instead of a narrative. Acceptable; the text was never the
  place to learn the behaviour.

# Verification

`openspec validate --specs --strict` must report no advisory for this
requirement. All four scenarios must be present, unchanged, in the merged
spec. The suite must be untouched.