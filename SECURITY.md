# Security Policy

## Reporting a Vulnerability

Harbor is local-first: your library, highlights, and reading data live on your own Mac, and AI calls only go to the provider you configure with your own key. Still, if you discover a security or privacy issue, we want to fix it quickly.

- **Please do not open a public issue for security problems.**
- Instead, use GitHub's [private vulnerability reporting](https://github.com/can4hou6joeng4/Harbor/security/advisories/new), or contact the maintainer directly.
- Include steps to reproduce, the affected version, and the potential impact.

We aim to acknowledge reports within a few days and to ship a fix as soon as practical.

## Scope

- API keys are stored in the macOS **Keychain**, never in plaintext config.
- AI is opt-in and never auto-sends content.
- Reports about these guarantees being violated are especially welcome.
