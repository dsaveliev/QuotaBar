# Fixtures

Payload shapes for the two providers' quota endpoints, used by
`ProviderTests` to check the parsers against a realistic response rather than
one written to fit the code under test.

They were **captured from the live endpoints**, so the shape is the server's
own — including the fields the parser deliberately ignores — but **every value
inside them has been replaced with a round number**. No real consumption
figures, plan tier or capture timestamp is in this repository.

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