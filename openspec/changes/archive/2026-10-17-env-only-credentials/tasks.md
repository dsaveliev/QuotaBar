# Tasks

## 1. Remove the credential file

- [x] 1.1 Delete `CredentialStore.defaultAuthFileURL`, its file reading, and
  `isAuthFileUnreadable`; leave the store resolving the environment alone.
  Verify: no `readFile` remains in `CredentialStore`
- [x] 1.2 Delete `authKeys` from the provider protocol and from both providers.
  Verify: `grep` finds no `authKeys` in `Sources/`
- [x] 1.3 Delete the `noCredentialFile` code and both providers' messages for it,
  and remove the unreadable-file consult from the engine. Verify: `grep` finds no
  `noCredentialFile`

## 2. Say how to make the variable visible

- [x] 2.1 Rewrite the missing-token message so it names the variable and then
  the installer, identically for both providers. Verify: the two strings differ
  only in the variable
- [x] 2.2 Replace the panel's `Credentials:` line, which prints the credential
  file's absolute path, with the variable and the step to take. Verify: no
  absolute path reaches the panel

## 3. Deliver the token to the agent

- [x] 3.1 Have `install.sh` read `ZAI_TOKEN` and `MINIMAX_TOKEN` from the
  environment and write them as `EnvironmentVariables` in the plist. Verify: the
  written plist carries them
- [x] 3.2 Create the plist with owner-only permissions and set them explicitly
  rather than trusting `umask`. Verify: the file's mode is 600
- [x] 3.3 Say plainly in the installer's output when a variable was not found in
  the environment, rather than writing a plist with no value and leaving the
  failure to surface later in the panel. Verify: the message appears

## 4. Tests

- [x] 4.1 Replace the cases that assert the file is read with cases that assert
  it is not. Verify: a file that holds a token resolves nothing
- [x] 4.2 Assert a whitespace-only variable resolves nothing
- [x] 4.3 Assert the missing-token messages are parallel and name the installer

## 5. Documentation, which currently promises the opposite

- [x] 5.1 README: remove the credential-file section, state that the app reads
  the environment only, and record that the installer writes the variable into
  the plist, where it lives in plain text
- [x] 5.2 SECURITY.md: say the token is persisted by the installer in the plist,
  and what that does and does not imply
- [x] 5.3 Note the breaking change for anyone relying on the file

## 6. Verify and ship

- [x] 6.1 `swift run QuotaBarKitTests`. Verify: all cases pass
- [x] 6.2 Run `install.sh` and confirm both subscriptions come up live with no
  credential file present. Verify: the menu bar shows figures for both
- [x] 6.3 Confirm the plist is mode 600 and that `uninstall.sh` removes it
- [x] 6.4 Validate and archive. Verify: `openspec validate --specs --strict`
  reports no advisory