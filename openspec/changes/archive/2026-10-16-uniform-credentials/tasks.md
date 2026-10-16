# Tasks

## 1. One scheme

- [x] 1.1 Set Z.ai's environment variable to `ZAI_TOKEN` and MiniMax's to
  `MINIMAX_TOKEN`, removing `Z_AI_TOKEN` and `MINIMAX_API_KEY`. Verify: `grep`
  finds neither retired name anywhere in `Sources/`
- [x] 1.2 Make both messages take one shape — variable first, signing in with
  OpenCode second. Verify: the two strings differ only in the variable

## 2. Name the missing file

- [x] 2.1 On the resolution-failure path, consult
  `credentials.isAuthFileUnreadable(home:)` and emit `noCredentialFile` when the
  file could not be read, keeping `noToken` when it could. This is the function's
  first caller outside its tests. Verify: `swift build` is clean
- [x] 2.2 Give `noCredentialFile` a message that names the file and where it
  belongs, and does not suggest an environment variable. Verify: it differs from
  the `noToken` message for the same provider

## 3. Tests

- [x] 3.1 Update every case naming `Z_AI_TOKEN` or `MINIMAX_API_KEY` to the
  current variable. Verify: `grep` finds neither retired name in the suite
- [x] 3.2 Assert an absent file yields `noCredentialFile` and a readable file
  without an entry yields `noToken`. Verify: both, and they differ
- [x] 3.3 Assert the retired names are not consulted — an environment holding
  only `MINIMAX_API_KEY` still reports a missing token. This is the breaking
  change; it should be pinned rather than assumed
- [x] 3.4 Assert the two providers' messages are parallel: same wording, only
  the variable differs

## 4. Documentation

- [x] 4.1 Update the README's environment list, and say plainly that
  `Z_AI_TOKEN` and `MINIMAX_API_KEY` are no longer read. Verify: the retired
  names appear only in that sentence

## 5. Verify and ship

- [x] 5.1 `swift run QuotaBarKitTests`. Verify: all cases pass
- [x] 5.2 Install with the credential file absent — which is the current state on
  this machine — and confirm the panel names the file rather than the variable.
  PARTIAL. Installed, and the log confirms both subscriptions now sit in the
  error state (`zai ?`, `mmx ?`) with the file gone. The panel text itself was
  not photographed: the status item had moved to the second display, where a
  synthetic click does not register. One click on the menu bar item confirms it
  visually. The codes and both sentences are covered by the suite in 3.2-3.4.
- [x] 5.3 Validate and archive. Verify: `openspec validate --specs --strict`
  reports no advisory