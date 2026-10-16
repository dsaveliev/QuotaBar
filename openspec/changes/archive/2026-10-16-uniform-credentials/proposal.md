# Proposal

## Why

With no credential file at all, both subscriptions say:

```
no token (zai login or ZAI_TOKEN)
no token (minimax login or MINIMAX_API_KEY)
```

Three problems in two lines.

**The advice is about the wrong cause.** The credential file was absent, and the
app says "set an environment variable" — advice for the case where you have a
file and it holds nothing for that provider. Two different problems, one message.
The spec asked for exactly this: "the file is treated as contributing no entries
and resolution falls through to the environment variables without surfacing an
error of its own". That was a deliberate decision, and it is the wrong one — it
costs the user the ability to tell them apart.

**The names are inconsistent.** `ZAI_TOKEN` says TOKEN, `MINIMAX_API_KEY` says
API_KEY, and Z.ai carries a second spelling while MiniMax has one. The scheme
was inherited verbatim from the sibling OpenCode plugin, inconsistency included.

**The messages are not parallel.** One names a login command, the other names an
env var, in a different order, with different punctuation.

## What Changes

- **One naming scheme: `<PROVIDER>_TOKEN`.** Z.ai is `ZAI_TOKEN`, MiniMax is
  `MINIMAX_TOKEN`. `Z_AI_TOKEN` and `MINIMAX_API_KEY` stop being read.

  **This breaks an existing setup.** Someone with `MINIMAX_API_KEY` exported will
  silently get `no token` again, with no hint that the name used to work. Chosen
  deliberately over keeping the old names as aliases: two accepted spellings is
  how the inconsistency started. The migration is one line in the README and the
  commit message.

- **A missing credential file gets its own outcome**, so the panel can say so
  rather than pointing at an environment variable. This reverses the existing
  scenario named above. `isAuthFileUnreadable()` and the `noCredentialFile` code
  have existed for this and been unreachable.

  A file that is *present but malformed* stays silent, as before. A file that
  cannot be read at all is a different problem from one that reads and holds
  nothing relevant, and only the former is worth naming.

- **Both messages take the same shape**: the variable to set, then the
  alternative. `no token — set ZAI_TOKEN, or sign in with OpenCode` /
  `no token — set MINIMAX_TOKEN, or sign in with OpenCode`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `quota-subscription-polling`: one environment variable per provider, and an
  absent credential file distinguished from an absent entry.
- `menubar-quota-surface`: the panel states which of the two missing-credential
  situations it is.

## Impact

- `Sources/QuotaBarKit/Providers/ZaiProvider.swift`,
  `MiniMaxProvider.swift` — `tokenEnvNames` and the error text.
- `Sources/QuotaBarKit/Engine/QuotaEngine.swift` — consults
  `isAuthFileUnreadable` on the resolution-failure path, which nothing calls
  today.
- Tests naming the old variables need updating; they assert the current names.
- `README.md`, which documents the current ones.