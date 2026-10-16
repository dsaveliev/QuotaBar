# Contributing

Thanks for looking. This project is specified before it is built, and that
shapes how changes arrive here.

## How work happens

Every behaviour in this app is a **requirement** in `openspec/specs/`, written
as WHAT the system does, never how. Changes are directories under
`openspec/changes/` carrying a proposal, spec deltas, a design note and a task
list. When a change is finished it is archived and its deltas are merged into
the specs.

So the order is:

1. **Propose.** `openspec new change <name>`, then write the artifacts. The
   proposal says why; the deltas say what must be true afterwards.
2. **Implement** the tasks.
3. **Verify** against real behaviour, not only tests.
4. **Archive**, which folds the deltas into `openspec/specs/`.

The point is that a change to this codebase is reviewable twice: once as
behaviour, once as code.

## Getting set up

Requires macOS 13+ and a Swift 6 toolchain. Command Line Tools are enough — no
Xcode needed.

```sh
swift build                 # compile everything
swift run QuotaBarKitTests  # run the suite
./scripts/install.sh        # install to /Applications and register at login
./scripts/uninstall.sh      # remove it again
```

### `swift test` will not work, and that is not a mistake

This toolchain ships neither XCTest nor the swift-testing module, so
`swift test` cannot run here at all. The suite is an ordinary executable target,
`Sources/QuotaBarKitTests`, with a small lock-based harness, and it exits
non-zero on failure. `swift test` would report success without running
anything, which is why CI uses `swift run QuotaBarKitTests`.

Do not add an XCTest target without checking that your toolchain has the
module; if yours does, say so in the pull request and it is worth adding.

## Working on a change

- **Read the requirement before you touch the code.** If the spec and the code
  disagree, that is the finding — do not quietly make the code match your
  reading. Report the disagreement and decide which side is wrong explicitly.
- **A bug fix with no behaviour change still needs a reason.** Put it in the
  commit message. That is what makes the history useful later.
- **Verify the way a user would.** Install it and use it. A test that proves a
  label is six characters does not prove the item stops moving on screen; both
  are worth having, and only one of them is a unit test.

## Style

The house style is visible in the existing code rather than documented, and it
is worth naming because a few things are deliberate:

- **Comments explain why, not what.** A comment restating the line below it is
  noise; a comment recording why the obvious approach is wrong is the point of
  the file.
- **Types are named for the domain,** not for the layer they sit in. `Verdict`
  and `RunwayResult` say what a reader needs; `ModelV2` does not.
- **Optional means optional, and nil is load-bearing.** Several places here
  distinguish "no preference" from "the user chose none", and collapsing those
  two has already cost a bug.
- **The suite describes behaviour in its case names,** because the names are
  what you read when one fails.

## Privacy

This app reads an API token and displays quota figures. If you contribute:

- Never commit a token, and never paste one into an issue or a pull request.
- If you re-capture a provider payload into `Fixtures/`, **replace the values
  before committing.** These files are published with the source. See
  `Fixtures/README.md`.
- Logs are the most useful thing to attach to a bug report, and the app writes
  them to `~/Library/Logs/QuotaBar/`. Read yours before you paste it.

## Pull requests

Fill in the template. The two boxes that matter are "how it was verified" and
"This project's shape" — the second is how a reviewer knows whether a missing
spec is an oversight or a judgement call.

## License

MIT, as in `LICENSE`.