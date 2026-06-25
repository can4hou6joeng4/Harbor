# Changelog

All notable changes to Harbor are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **OPML import** — bring your subscriptions from any RSS reader (or a closing service) in one step: parses nested OPML, skips duplicates, and syncs the new feeds' latest articles. Available in **Manage Subscriptions → Import from OPML**.
- **Read-later import** — migrate saved articles from **Pocket** (HTML), **Instapaper** (CSV), or a plain URL list. Items import as summary-only and can fetch full text on demand. Available in **Add Content → Other → Import from Pocket / Instapaper**.

## [0.1.1] - 2026-06-25

### Changed
- Renamed the app to **Harbor** (display name, packaged DMG, Sparkle feed).
- English-first README with a Chinese companion (`README_CN.md`).

### Added
- Open-source baseline: `LICENSE` (GPL-3.0), `CONTRIBUTING`, code of conduct, security policy, issue/PR templates.
- Product promo video (README hero GIF + full MP4).

### Fixed
- Sparkle auto-update signing (regenerated EdDSA keypair; appcast points at the correct release asset).

## [0.1.0] - 2026-06-17

### Added
- First internal build: local-first capture (URL / RSS / PDF), three-column reading with highlights, bilingual mode, tags & folders, SQLite FTS5 search, and bring-your-own-key AI (summary / translate / chat / remix).
