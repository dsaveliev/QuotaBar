# Design

## Context

See `proposal.md` — Why.

Two decisions here are reversals of things this project already decided, so both
are argued rather than assumed.

## Goals / Non-Goals

**Goals:**

- One scheme a user can predict from the provider's name.
- The panel names the situation it is in.

**Non-Goals:**

- No settings UI. The environment is still the only place these live.
- No credential storage. The app still never writes a token.
- No change to how a token is *sent*. Same file, same order, same bearer auth.

## Decisions

### `<PROVIDER>_TOKEN`, aliases dropped

`ZAI_TOKEN`, `MINIMAX_TOKEN`.

Chosen over keeping `MINIMAX_API_KEY` and `Z_AI_TOKEN` as aliases. Aliases are
how this inconsistency happened: two providers, two schemes, one alias on one
side only, and a message that had to explain all of it. Keeping them preserves
the thing being fixed.

The cost is real and stated: an existing export breaks silently. That is the
trade the user picked.

The one thing that would blunt it — naming the retired variable in the error
message — was left out on purpose. A migration note belongs in the README and the
release notes, not in a message every user sees forever. Say the word if you
would rather have it in the message.

### An absent file is named; a malformed one is not

The existing spec says an absent file "falls through without surfacing an error
of its own". Reversing it splits one outcome into two:

| on disk | env | outcome |
| --- | --- | --- |
| file has an entry | any | token from the file |
| no file | `*_TOKEN` set | token from the environment |
| file present, no entry | `*_TOKEN` set | token from the environment |
| **no file** | **not set** | **`noCredentialFile`** — "there is no OpenCode credentials file" |
| **file present, no entry** | **not set** | **`noToken`** — "set ZAI_TOKEN, or sign in" |

The last two are what the user cannot currently tell apart, and they need
different actions.

Malformed stays merged with "no entry" because the app cannot tell a malformed
file from a file written for other tools, and both resolve the same way.

### One shape, built once

The two providers each write their own string today, which is how they drifted.
The shape is now stated once in the requirement — *the variable, then the
alternative* — and each provider fills in its own variable. There is no shared
formatter, because the only variable part is the variable.

### The old `noCredentialFile` text is not reused

It reads "no OpenCode credentials for MiniMax", which points at the file but not
at what to do. The new text names the file and the way to create it, identically
for both providers.

## Risks / Trade-offs

- **A broken export is silent.** Accepted, and recorded here so it is not a
  surprise later.
- **Splitting one error into two** means two strings per provider instead of
  one, and the split is only worth it because the actions differ. If a third
  case appears later, this belongs in one place rather than per provider.
- **`isAuthFileUnreadable` re-reads the file** on the failure path, after
  `resolve` has already read it once and failed. Once per failing refresh, on a
  local file. Not worth carrying state to avoid.

## Migration Plan

- README: the environment variables section, with the retired names called out.
- The commit message names both retired variables.
- Nothing on disk changes; no user data is touched.

## Open Questions

None.