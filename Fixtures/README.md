# Fixtures

Payload shapes for the two providers' quota endpoints, used by
`ZaiProviderTests` and `MiniMaxProviderTests` to check the parsers against a
realistic response rather than one written to fit the code under test.

They were **captured from the live endpoints**, so the shape is the server's own
— including the fields the parser deliberately ignores.

What was replaced, and what was not:

- **Replaced with round numbers:** every consumption figure, the limit, the
  percent, and the plan tier. No real quota figures are in this repository.
- **Kept as captured:** the absolute reset timestamps. They are load-bearing —
  the parser carries them through unchanged and a test pins the exact values —
  and rounding them to a tidy number would make the fixture less faithful
  without making it safer. They disclose a window boundary, nothing more.

If you re-capture a live payload, replace the consumption figures before
committing them. These files are published with the source.

What each fixture keeps, because a test depends on it:

| Property | Why it is here |
| --- | --- |
| Z.ai: two limits with `unit` 3 and 6 | one parses as the 5h window, one as the 7d |
| Z.ai: `usage` differs from `currentValue` | proves the window's value wins over the plan total |
| Z.ai: explicit `percentage` disagrees with what the counts derive | proves the server's own figure wins |
| Z.ai: `currentValue + remaining` is the limit | the rule the parser applies |
| MiniMax: percent-space remaining, not counts | MiniMax reports percentages, not quantities |
| MiniMax: `base_resp.status_code` 0 | the envelope-success rule the region fallback turns on |

If you re-capture a live payload, replace the values before committing them —
these files are published with the source.