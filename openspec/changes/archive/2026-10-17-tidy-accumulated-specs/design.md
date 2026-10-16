# Design

## Context

See `proposal.md` — Why.

## Goals / Non-Goals

**Goals:**

- One requirement per capability area, saying what the code does.
- No scenario whose title contradicts its own body.

**Non-Goals:**

- No renaming of requirements for taste. `Status label shape` keeps its name,
  awkward as it is, because renaming it is the operation that produced the
  problem.
- No consolidation of scenario titles repeated *across* requirements, such as
  `the verdict is stated once` appearing in two of them. Repetition is noise;
  contradiction is a defect, and only the second was worth a change.

## Decisions

### Keep `Status label shape`, drop its two predecessors

It is the accurate one, it has one scenario fewer, and it is the newest — which
in this schema is also the most likely to match the code. `Compact status
label` is not merely redundant but wrong: it prescribes a label format the app
stopped producing when the figures moved into the tooltip.

Rejected: merging the two survivors into one. They are already one; merging
would mean rewriting thirteen scenarios to satisfy a title the validator will
not let me keep.

### The runway scenarios are retired and re-added, not edited

Renaming one of two same-titled scenarios is exactly what the validator
forbids: a MODIFIED block that drops a title is a deletion, and one that adds
one is an addition. Retirement is the only route, and it has been used before
for the same reason.

The alternative — leaving a scenario titled "projection outlasts the reset"
whose body says the projection falls before it — is worse than an awkward
retirement. A title that contradicts its body is worse than no title.

### Nothing is added

This change only removes. The kept requirements are untouched, so the audit's
finding that `Status label shape` matches the code stands as evidence rather
than as a claim.

## Risks / Trade-offs

- **Deleting a requirement is a deletion from the record.** Mitigated by
  copying both in full into the change's delta, so the removal is reviewable
  and recoverable from the archive.
- **The same accumulation can recur.** Every future rename-shaped change has the
  same trap. Worth knowing: it is a property of the schema, not of this repo,
  and the fix belongs in the validator rather than in discipline here.

## Migration Plan

None. Specification files only.

## Open Questions

None.