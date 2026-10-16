# Tasks

## 1. Spec

- [x] 1.1 Rewrite the text of `Requirement: Quit` to under 500 characters, stating each guarantee once and leaving the detail to the scenarios
- [x] 1.2 Carry all four scenarios through verbatim; assert none was reworded, reordered away, or dropped
- [x] 1.3 Record in the proposal why the requirement is not split into two, quoting the two validator refusals

## 2. Verify

- [x] 2.1 Validate the change with `openspec validate tighten-quit-requirement --strict`
- [x] 2.2 Archive, then validate the merged specs and confirm no advisory remains
- [x] 2.3 Confirm the four scenarios survive the archive by reading them back out of the merged spec
- [x] 2.4 Confirm nothing outside `openspec/` changed
- [x] 2.5 Commit