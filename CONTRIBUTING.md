# Contributing to Harbor

Thanks for your interest in improving Harbor — a local-first reading app for macOS. Contributions of all kinds are welcome: bug reports, feature ideas, docs, and code.

## Ways to contribute

- **Report a bug** — open an [issue](https://github.com/can4hou6joeng4/Harbor/issues) with steps to reproduce, your macOS version, and a screenshot/log if relevant.
- **Suggest a feature** — open an issue describing the problem you're trying to solve (not just the solution).
- **Send a pull request** — for small fixes, go ahead; for larger changes, open an issue first so we can align on direction.

## Development setup

```bash
git clone https://github.com/can4hou6joeng4/Harbor.git
cd Harbor

swift build          # build
swift test           # run the test suite (94 tests)
swift run            # run from source

./script/build_and_run.sh --verify   # build a packaged .app and launch it
```

Requirements: macOS 13+, Xcode 16+, Swift 6.

## Architecture (quick map)

- `Sources/ReaderCore/` — pure, UI-agnostic core: models, `ReaderStore`, persistence (GRDB/SQLite + FTS5), capture (URL/RSS/PDF), and AI services. **Fully unit-tested.**
- `Sources/ReaderMacApp/` — SwiftUI views and macOS app shell.
- `Tests/ReaderCoreTests/` — tests for the core. New logic should land in `ReaderCore` with tests.

Local-first is a hard rule: the library, highlights, notes, and reading positions live on-device. AI is **opt-in** and never auto-sends.

## Pull request guidelines

- Keep PRs focused; one logical change per PR.
- Add or update tests for behavior changes (`swift test` must pass).
- Match the existing code style; no force-pushes to shared branches.
- Commit messages follow `type: 简短描述` (e.g. `fix: 修复 RSS 去重`, `feat: add OPML import`).

## Code of conduct

Be respectful and constructive. We follow the spirit of the [Contributor Covenant](https://www.contributor-covenant.org/).

## License

By contributing, you agree that your contributions will be licensed under the [GPL-3.0 License](LICENSE).
