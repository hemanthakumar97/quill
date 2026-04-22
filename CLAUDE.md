# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quill is a macOS menu bar (status bar) journaling app written in Swift. It lives in the menu bar, accepts quick journal entries, and optionally polishes them with AI before saving to an Obsidian vault.

- **Language:** Swift 5.9, SwiftUI + AppKit
- **Minimum macOS:** 14.0 (Sonoma)
- **App type:** LSUIElement accessory app (no Dock icon)
- **No external Swift package dependencies** — pure native Cocoa

## Build & Install

```bash
# Debug build
swift build

# Release build
swift build -c release

# Bundle as .app and install to ~/Applications/
bash install.sh
```

There is no test suite and no linting toolchain configured.

## Architecture

```
Sources/Quill/
├── main.swift                  # NSApplication bootstrap
├── AppDelegate.swift           # Activation policy, Edit menu setup
├── StatusBarController.swift   # Menu bar icon, popover lifecycle, event monitor
├── JournalEntryView.swift      # Primary SwiftUI UI with state machine
├── SettingsView.swift          # AI provider/model/API key configuration UI
├── JournalManager.swift        # Markdown file I/O to Obsidian vault
├── ConfigManager.swift         # JSON config persistence, @Observable singleton
└── AIManager.swift             # Async abstraction over Claude/OpenAI/Gemini/Ollama
```

### Data Flow

1. User left-clicks the menu bar icon → `StatusBarController` opens a popover containing `JournalEntryView`.
2. User types and presses **Return** to save (or **Shift+Return** for a newline).
3. If AI polish is enabled: `AIManager.polish()` makes an async API call; the view transitions through an `EntryState` enum (`writing → polishing → preview → saved/error`).
4. User accepts polished or original text → `JournalManager.appendEntry()` writes to disk.
5. Right-click on the menu bar icon opens a context menu (Settings, Quit).

### Key Patterns

- **Singletons:** `ConfigManager.shared`, `AIManager.shared`, `JournalManager.shared`
- **State machine UI:** `JournalEntryView` is driven entirely by the `EntryState` enum; all view branches live inside a single `switch` on that state.
- **Async/await throughout:** API calls and file I/O use Swift concurrency; UI updates are dispatched back to `MainActor`.
- **Config persistence:** `~/.config/Quill/config.json` — read at launch, written on settings save. No keychain; API keys are stored in plain JSON.

### Journal Storage

Entries are appended to markdown files in the Obsidian vault:

- **Vault root (hardcoded in `JournalManager.swift`):** `/Volumes/Hemanth/Obsidian Vault/Journal`
- **File path pattern:** `{YEAR}/{MMM-YYYY}.md` (e.g. `2026/Apr-2026.md`)
- **Entry format:** Day-level `##` header + time-stamped `###` entry block

### AI Providers

`AIManager` supports four providers, selected via `ConfigManager.selectedProvider`:

| Provider | Auth | Endpoint |
|----------|------|----------|
| Claude | `x-api-key` header | `api.anthropic.com/v1/messages` |
| OpenAI | Bearer token | `api.openai.com/v1/chat/completions` |
| Gemini | API key in URL | `generativelanguage.googleapis.com/v1beta` |
| Ollama | None (local) | `localhost:11434/api/chat` |

Polish modes map to system prompts: **Light** (grammar only), **Full** (rewrite as prose), **Structured** (3-section markdown).

### Claude Model IDs

When updating Claude models in `AIManager.swift`, use the current canonical IDs:
- Opus 4.7: `claude-opus-4-7`
- Sonnet 4.6: `claude-sonnet-4-6`
- Haiku 4.5: `claude-haiku-4-5-20251001`
