# Context

The audit that produced this change compared every requirement in all three
specs against the code that implements it. Findings were split by whose
mistake they were:

| # | Subject | Who was wrong | Action |
| --- | --- | --- | --- |
| 1 | `isMeasuring` covered no-limit and no-reset windows | code (regression from `runway-trust-threshold`) | code fixed, test added |
| 2 | `Show none` never produced the recovery item | code | code fixed, model rewritten |
| 3 | Purpose / diagnostics describe several items | spec | spec |
| 4 | `Item visibility` describes a checklist | spec | spec |
| 5 | `Label states` promises four states | spec | spec |
| 6 | `Dropdown content` too long | spec | spec |
| 7 | "single moving window" | spec | spec |
| 8 | verdict named `safe` | spec | spec |
| 9 | four distinct markers | spec | spec |
| 10 | staleness aged from the last attempt | spec | spec |
| 11 | region fallback on an empty plan | spec | spec |

# Decisions

## `Item visibility` is removed rather than rewritten

A rewrite would have to describe per-subscription visibility, which is exactly
the ambiguity the single item was built to remove. `Menu bar items` cannot
express "two shown, one displayed", and the picker cannot express "one of two
shown". There is no honest version of this requirement left to write.

What survives - never stranding the user behind an empty menu bar - is already
a scenario of both `Menu bar presence` and `Provider picker`. Removing the
requirement therefore removes a duplicate, not a guarantee.

## Empty payload is not a region problem

This one needed judgement rather than transcription, because both sides looked
defensible. The spec said an empty MiniMax plan should fall through to the
regional host. The engine commits to the first host whose envelope succeeds and
only then discovers the body is empty.

The code is right. `base_resp.status_code` means "this host cannot serve you";
an empty `model_remains` means "this host can, and your plan has no windows
listed". Probing `api.minimax.cn` because the international host answered
correctly with nothing would double the request count on every refresh of every
idle account to fix a problem that is not region-shaped.

## Staleness is about data, not about attempts

The requirement opened by defining freshness over the last attempt, then had
three scenarios all describing the last success. The code follows the
scenarios: `updatedAt` moves only on success, is cleared on failure, and an
active error suppresses staleness because a failing endpoint is an error, not
old data. The opening sentence was the outlier.

# Risks

- Removing a requirement is the one edit here that deletes a guarantee from
  face value. Mitigated by checking, requirement by requirement, that each
  scenario's intent is stated elsewhere; the cross-reference is in the
  proposal.
- "Reported as `ok`" ties the spec to an enum case name. The glyph table in the
  README and the ladder scenarios already do this, so it is not a new coupling.

# Verification

Every claim re-checked against the file and line named in the proposal.
`openspec validate --specs --strict` must report no advisory. The suite must
pass unchanged: nothing in this change alters behaviour.