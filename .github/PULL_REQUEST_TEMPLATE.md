## What this changes

<!-- One or two sentences. If it fixes an issue, link it: Closes #123 -->

## Why

<!-- The problem, or the observation that prompted it. -->

## How it was verified

<!-- Not "tests pass". What did you actually observe? -->

- [ ] `swift run QuotaBarKitTests` passes
- [ ] I ran the built app and looked at the result, or it changes nothing visible
- [ ] `openspec validate --specs --strict` reports no advisory

## This project's shape

- [ ] Behaviour changed → there is a change directory under `openspec/changes/`
      with a proposal, deltas, design and tasks, and it is archived
- [ ] No behaviour changed → the change is a refactor or docs, and no spec moved
- [ ] The deltas were written against a spec I had read in full, not from memory

## Notes for the reviewer

<!--
What you think is wrong or debatable, and what you would accept instead.
The change directory's design.md is the place for reasoning that does not fit
here; this is for the parts you want argued about in review.
-->