# Why

`Requirement: Quit` trips the validator's advisory that requirement text runs
past 500 characters.

The first instinct was to split it: `Quit` covers what the app leaves behind,
and a new `Startup and recovery` would cover what the login agent does. That
turns out not to be expressible as an OpenSpec delta, and the refusal is
correct rather than an obstacle to route around:

```
✗ MODIFIED "Quit" omits scenario(s) the current spec still has: "a graceful
  quit stays off", "an abnormal exit is recovered", "the app is present at
  login".
✗ Requirement present in both ADDED and REMOVED: "Quit"
```

A delta has exactly four operations. `MODIFIED` replaces a block wholesale and
refuses to let a scenario disappear. `REMOVED` plus an `ADDED` of the same
name is rejected as a conflict. `RENAMED` carries a `FROM:`/`TO:` pair and no
content at all. There is no "move these scenarios to that requirement"
operation, so the split cannot be written down, only faked — by duplicating
the scenarios, which the validator flags and which drifts.

Two changes in sequence would get the archive past the guard, but the first
would ship a spec in which quitting loses its persistence guarantee. Trading
a correct spec for a clean validation pass is the wrong trade.

So the advisory stands and the split is off the table until OpenSpec grows a
move operation.

# What Changes

`Requirement: Quit` keeps all four scenarios and gets a shorter statement of
intent. The advisory counts the requirement's own text, not its scenarios —
its own hint is to move detail into scenarios, which is where the detail
already is. The prose was carrying a clause-by-clause restatement of every
scenario; deleting that restatement loses no guarantee, because each guarantee
is stated once in the scenario that demonstrates it.

Coverage is unchanged and no scenario is touched. No code, no plist, no
behaviour.

# Non-goals

- Not splitting the requirement. See above; the tool forbids it and a duplicated
  copy would be worse than a long paragraph.
- Not trimming scenarios to shorten the requirement. They are the contract.
- Not silencing the advisory by relaxing the validator's threshold.