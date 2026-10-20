# Design

## Context

See `proposal.md` — Why.

The MiniMax token-plan payload carries two independent windows. The five-hour
window and the weekly window each have their own start, their own end, and
their own remaining-time countdown, and the weekly window routinely began days
before the current five-hour window did.

The pre-scrub fixture, still in git history at `abf15e2`, shows that shape as
the endpoint sends it:

```
5h window     2026-10-16 05:43  ->  12:43   (5.0 h)
7d window     2026-10-13 08:14  ->  2026-10-20 08:14   (7.0 days)
weekly started 69.5 h before the 5h window
weekly_remains_time == weekly_end_time - capture instant
```

The scrubbing commit `4e32e57` replaced the figures with round numbers. Its
intent was privacy: real consumption figures and the plan tier are the user's
data, and the repository was about to be published. The timestamps went with
them, correctly in spirit — a window boundary needs no more precision than a
round number, and the boundary discloses nothing about how much was used.

But rounding each timestamp *independently* changed what the payload says. The
scrubbed fixture now has `weekly_start_time == start_time`, a weekly span of
6.97 days rather than 7, and a `weekly_remains_time` equal to the window's
full length rather than a countdown to its end. Each of those is a statement
the endpoint never makes.

Three properties follow from the endpoint's own arithmetic, and the scrubbed
fixture breaks all three:

| Property | Endpoint | Scrubbed fixture |
| --- | --- | --- |
| `weekly_end - weekly_start` is exactly seven days | yes | 6.97 days |
| `weekly_start` is independent of `start_time` | yes, 69.5 h apart | equal |
| `weekly_remains_time == weekly_end - now` | yes | equals the full span |

The `weekly_remains_time` identity is the load-bearing one. It is what proves
`weekly_end_time` is the true weekly boundary: the endpoint counts down to the
same instant the app reads as the reset. Both the archived capture and the live
endpoint satisfy it exactly — the live payload's `weekly_end - now` matched
`weekly_remains_time` within 3 ms across fourteen consecutive polls.

`Fixtures/README.md` compounds this by asserting the opposite of what happened:
it says the absolute reset timestamps were "kept as captured", and that "a test
pins the exact values". Every timestamp in both fixtures was replaced, and the
one test that pins values pins the *scrubbed* ones.

## Goals / Non-Goals

**Goals:**

- The MiniMax fixture's relationships match the endpoint's, so it is a valid
  specimen for a parser to be checked against.
- Every value stays a round number, keeping the scrubbing's privacy intent.
- The shape is pinned by a test, so the next person who rounds a value learns
  which relationships must survive the rounding.
- The README describes what the fixtures actually contain.

**Non-Goals:**

- Changing how the app reads the payload. The parser already takes each row's
  reset from its own window's end.
- Deriving a window's duration from the payload rather than from the plan's
  declared durations.
- The Z.ai fixture, whose payload carries no window starts and therefore has no
  relationship to flatten.

## Decisions

### Round numbers, faithful relationships

The new timestamps are round numbers that satisfy the endpoint's arithmetic:

```
start_time         1791916400000    (unchanged)
end_time           1791934400000    (unchanged)
remains_time          1800000       (unchanged)
weekly_start_time 1791657200000    three days before start_time
weekly_end_time   1792262000000    exactly seven days after weekly_start_time
weekly_remains_time  329400000      weekly_end_time - (end_time - remains_time)
```

Every value ends in `000`, as before. The capture instant is implied by
`end_time - remains_time`, exactly as the endpoint implies it, and
`weekly_remains_time` is derived from that same instant — so the fixture is
self-consistent rather than merely plausible.

The implied weekly position is 45% elapsed, against 44% in the original
capture. Close enough that the fixture reads like a payload taken partway
through a weekly window rather than at its first instant.

Rejected: restoring the archived timestamps verbatim. They are already in git
history, but they would put the original capture's exact window boundaries back
into a published file, undoing the scrubbing's purpose for no gain — the
relationships are what the parser is checked against, not the absolute values.

Rejected: keeping the scrubbed timestamps and only fixing the README. The
README would then be true, but the fixture would still teach a shape the
endpoint never sends, and the trap this change closes would stay open.

### The test pins relationships, not values

The new case reads the fixture and asserts the three properties in the table
above, plus that the two windows' ends differ. It deliberately does not pin
absolute timestamps: a future scrub that rounds them differently must still
pass, because the relationships are what matter.

The same case also asserts that the parser gives the `5h` row one reset and
the `7d` row another — which is only observable because the fixture's windows
now have different ends. With the scrubbed fixture both rows' reset timestamps
would be identical, and the case could not distinguish a parser that reads the
right field from one that does not.

Rejected: pinning the exact timestamp values, the way the Z.ai test does. That
would make every future re-capture a test failure, and it would pin the
constants rather than the property.

### The README states what is true

The "what was replaced and what was not" section is corrected: every value,
timestamps included, is a round number, and what survives the rounding is the
*shape* — the relationships between the values. The table gains the MiniMax
rows the test now depends on, so the next person who captures a payload knows
what must be preserved.

The privacy instruction stays and gets sharper: re-capturing means replacing the
figures, and the shape has to keep holding.

## Risks / Trade-offs

- **A reviewer may read the new timestamps as invented.** → The design states
  where each one comes from, and the test asserts the properties rather than
  the numbers, so the fixture's validity does not rest on trusting the
  arithmetic.
- **The weekly span is now exactly seven days, matching the app's hardcoded
  `window7dMs`.** That agreement is a coincidence of this plan tier, and the
  fixture stops being able to reveal a plan whose weekly window differs. → The
  README records the assumption; changing the app to derive the duration from
  the payload is a separate change.
- **The fixture and the live endpoint can drift again**, as they did between
  `abf15e2` and `4e32e57`. → The test fails if the relationships break, so the
  drift is caught at the next capture rather than discovered by a parser
  behaving oddly months later.
- **Restoring independence means `weekly_start_time` no longer equals
  `start_time`,** which is a visible change in a published file. → The archived
  capture shows this is the endpoint's actual shape, so the change moves the
  fixture toward the truth rather than away from it.

## Migration Plan

None. No application code changes, so nothing to deploy and nothing to roll
back. The fixture and its test are replaced in one commit; the README changes
with them.

## Open Questions

None that change the specs, the approach, or the tasks.
