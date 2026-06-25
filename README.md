<h4 align="right"><strong>English</strong> | <a href="README_CN.md">简体中文</a></h4>

<div align="center">
  <img src="docs/reader-icon.png" alt="Harbor" width="138" />
  <h1>Harbor</h1>
  <div align="center">
    <a href="https://github.com/can4hou6joeng4/Harbor/releases/latest">
      <img alt="GitHub Release" src="https://img.shields.io/github/v/release/can4hou6joeng4/Harbor?style=flat-square&color=D2973F"></a>
    <a href="https://github.com/can4hou6joeng4/Harbor/releases">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/can4hou6joeng4/Harbor/total.svg?style=flat-square"></a>
    <a href="https://github.com/can4hou6joeng4/Harbor/stargazers">
      <img alt="GitHub Stars" src="https://img.shields.io/github/stars/can4hou6joeng4/Harbor?style=flat-square"></a>
    <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&logo=apple">
    <a href="https://github.com/can4hou6joeng4/Harbor/actions/workflows/release.yml">
      <img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/can4hou6joeng4/Harbor/release.yml?style=flat-square&label=build"></a>
  </div>
  <p align="center">Local-first reading and curation for macOS — capture, read, organize, and chat with your knowledge, all on your Mac.</p>
</div>

<p align="center">
  <img src="docs/reader-promo.gif" alt="Harbor Demo: Immersive Reading, Highlights, Bilingual, AI Summary & Chat" width="760" />
</p>
<p align="center"><sub>▶ <a href="docs/reader-promo.mp4">Watch full video (MP4 · 55s)</a></sub></p>

---

## Features

- 🌊 **Capture**: Extract article text from URLs, subscribe to RSS/Atom/JSON feeds (dedup, conditional requests, parallel sync), import local PDFs and images
- 📖 **Read**: Three-column layout, text selection with highlights & notes, bilingual reading, serif fonts with typography controls, reading progress tracking
- 📂 **Organize**: Tags, tree folders, favorites, SQLite FTS5 full-text search (CJK + Latin), keyboard navigation
- 🤖 **AI (Bring Your Own Key)**: Summarize, translate, chat and remix with AI — results saved locally for offline access
- 🏠 **Local-First**: All data (library, highlights, notes, reading positions) stored locally; AI is opt-in, explicit, and never auto-sends

## Installation

### Download

1. Download `Harbor.dmg` from [**Releases**](https://github.com/can4hou6joeng4/Harbor/releases/latest)
2. Open the DMG and drag **Harbor** to **Applications**
3. **First launch**: This version is not notarized by Apple. Right-click **Harbor** in Applications → **Open**, or run in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Harbor.app
   ```

### Homebrew

```bash
brew install --cask can4hou6joeng4/tap/harbor
```

## Auto-Update

Check for updates via **Harbor → Check for Updates...** in the menu bar. Updates are distributed through [Sparkle](https://sparkle-project.org) with EdDSA signature verification.

## AI Setup (Bring Your Own Key)

Go to **Settings** in Harbor, choose a provider, and enter your API key (stored in Keychain only):

- **Anthropic**: Default endpoint `api.anthropic.com`
- **OpenAI**: Official or compatible endpoints (Azure, Groq, Together, etc.)
- **Custom**: Any OpenAI-compatible service with custom base URL

AI features:
- **Summarize**: Structured summary of the article
- **Translate**: Paragraph-by-paragraph translation with preserved IDs
- **Chat & Remix**: Streaming AI responses, saved to library

All AI results are stored locally and remain accessible offline.

## Tech Stack

- **Swift 6** + **SwiftUI** for native macOS experience
- **GRDB** for local SQLite persistence with FTS5 search
- **Sparkle** for automatic updates
- **SSE streaming** for real-time AI responses

## Development

### Requirements

- macOS 13.0+
- Xcode 16.0+
- Swift 6.0+

### Build

```bash
# Clone the repository
git clone https://github.com/can4hou6joeng4/Harbor.git
cd Harbor

# Build and run
swift build
swift run

# Or open in Xcode
open Package.swift
```

### Test

```bash
swift test
```

### Package

```bash
./script/package_app.sh
```

This generates a DMG with code signing and notarization (requires Apple Developer credentials).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first (if you have contribution guidelines).

## License

GPL v3 — see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with inspiration from:
- [Sparkle](https://sparkle-project.org) — Auto-update framework
- [GRDB](https://github.com/groue/GRDB.swift) — SQLite toolkit
- Local-first principles from [Ink & Switch](https://www.inkandswitch.com/)

---

<p align="center">Made with ❤️ for knowledge workers who value privacy and local control</p>
