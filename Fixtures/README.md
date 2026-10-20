# Fixtures

Payload shapes for the two providers' quota endpoints, used by
`ZaiProviderTests` and `MiniMaxProviderTests` to check the parsers against a
realistic response rather than one written to fit the code under test.

The field set, and the relationships between the fields, were **captured from
the live endpoints**, so the shape is the server's own — including the fields
the parser deliberately ignores. The values were not.

What was replaced, and what was not:

- **Replaced with round numbers:** every value — the consumption figures, the
  limit, the percent, the plan tier, and the reset timestamps alike. No real
  quota figures and no real window boundaries are in this repository.
- **Kept as captured:** the *shape*, which is to say the relationships between
  the values. The weekly window starts before the five-hour window does, spans
  seven days of its own, and counts down to its own end; the Z.ai limit is the
  sum of its consumed and remaining counts. Rounding the numbers keeps those
  relationships. Flattening them would teach a parser something the endpoint
  never says — a weekly window that is really a copy of the five-hour one, a
  remaining time that is really the window's full length — and the next person
  to check a parser against this fixture would be checking it against a
  fiction.

If you re-capture a live payload, replace the values before committing them —
these files are published with the source — and keep the shape holding. The
properties below are the ones a test depends on; a capture that breaks one of
them fails the suite, which is where the shape would otherwise drift again
unnoticed.

What each fixture keeps, because a test depends on it:

| Property | Why it is here |
| --- | --- |
| Z.ai: two limits with `unit` 3 and 6 | one parses as the 5h window, one as the 7d |
| Z.ai: `usage` differs from `currentValue` | proves the window's value wins over the plan total |
| Z.ai: explicit `percentage` disagrees with what the counts derive | proves the server's own figure wins |
| Z.ai: `currentValue + remaining` is the limit | the rule the parser applies |
| MiniMax: percent-space remaining, not counts | MiniMax reports percentages, not quantities |
| MiniMax: `base_resp.status_code` 0 | the envelope-success rule the region fallback turns on |
| MiniMax: the weekly window starts before the five-hour window | the two windows are independent, so the `7d` row's reset is not the `5h` row's |
| MiniMax: the weekly window spans seven days | its own length, not a copy of the five-hour window's |
| MiniMax: the weekly remaining time is the distance from the capture instant to the weekly window's end | a countdown, not the window's full length — and the check that proves `weekly_end_time` is the true weekly boundary |
