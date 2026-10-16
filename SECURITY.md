# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for a vulnerability.

Report it privately through GitHub's security advisory form:
<https://github.com/dsaveliev/QuotaBar/security/advisories/new>

Include the version or commit, your macOS version, and what an attacker could
do. I aim to acknowledge within a few days and to say whether a fix is coming.

## What this app touches, and why it matters

QuotaBar reads an API token and displays a subscription's usage. That makes two
things worth stating plainly rather than leaving to be inferred:

- **It reads a token and sends it only to that subscription's own quota
  endpoints**, over https, as a bearer token. It is never logged and never
  rendered, including in error text, which names *where* to put a credential
  rather than echoing one.

  Note the plural, because it is the one thing here worth being precise about.
  Each subscription declares two hosts and probes them in order, so a failure
  on the first sends the same token to the second:

  | Subscription | Hosts, in order |
  | --- | --- |
  | Z.ai | `api.z.ai`, then `open.bigmodel.cn` |
  | MiniMax | `api.minimax.io`, then `api.minimax.cn` |

  The second host is the provider's own regional fallback, but it is not the
  same organisation's domain — `bigmodel.cn` belongs to Zhipu, not Z.ai. A
  token can therefore reach a host its issuer would name differently. If that
  is not acceptable for your threat model, restrict `endpoints` in the provider
  to the host you intend; the list is a plain declaration and the app will
  never contact a host absent from it.
- **A token, once supplied, lives in the login agent's plist.**
  `~/Library/LaunchAgents/dev.dmitrii.quotabar.plist` carries `ZAI_TOKEN` and
  `MINIMAX_TOKEN` in plain text, readable by the user who owns it. That is
  launchd's own mechanism for handing variables to an agent, and it is the only
  place the token is persisted: the app itself keeps it in its process
  environment and writes nothing. `uninstall.sh` removes the plist.

The token was previously never written anywhere. It is now written by the
installer, which is a deliberate trade for working after a login without
remembering a command.

The full inventory is in the README's Privacy section.

## What is in scope

- A token reaching a log, a rendered surface, or a crash report.
- The app writing outside `~/Library/Application Support/QuotaBar` and
  `~/Library/Logs/QuotaBar`.
- A request going anywhere other than the subscription's own endpoint.
- Anything the install script does beyond installing and registering the agent.

## What is not a vulnerability

- **Your own quota figures.** The app displays your subscription's usage. That
  is the product.
- **The installer writing the token into the plist**, which is the documented
  mechanism, mode 600, and the only reason a login agent can read a variable at
  all.
- **The app writing its own sample history** into the directories named above.
- **The installer writing a token into the plist.** That is the documented
  mechanism, mode 600, and the reason a login agent can read a variable at all.

## Supported versions

Only the latest `main`. This is a small app with no release cadence; there are
no older versions to patch.