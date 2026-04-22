# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

```
quill/
├── macos/          # macOS menu bar app (Swift)
├── android/        # Android home screen widget (Kotlin)
├── README.md
└── CLAUDE.md
```

---

## macOS (`macos/`)

### Stack
- Swift 5.9, SwiftUI + AppKit
- Minimum macOS: 14.0 (Sonoma)
- LSUIElement accessory app (no Dock icon)
- No external Swift package dependencies — pure native Cocoa

### Build & Install

```bash
cd macos

# Debug build
swift build

# Release build
swift build -c release

# Bundle as .app and install to ~/Applications/
bash install.sh
```

No test suite, no linting toolchain.

### Source Files

```
macos/Sources/Quill/
├── main.swift                  # NSApplication bootstrap
├── AppDelegate.swift           # Activation policy, Edit menu setup
├── StatusBarController.swift   # Menu bar icon, popover lifecycle, event monitor
├── JournalEntryView.swift      # Primary SwiftUI UI with state machine
├── SettingsView.swift          # AI provider/model/API key + journal path config UI
├── JournalManager.swift        # Markdown file I/O to Obsidian vault
├── ConfigManager.swift         # JSON config persistence, @Observable singleton
└── AIManager.swift             # Async abstraction over Claude/OpenAI/Gemini/Ollama
```

### Data Flow

1. User left-clicks menu bar icon → `StatusBarController` opens popover with `JournalEntryView`
2. User presses **Return** to save (or **Shift+Return** for newline)
3. If AI polish enabled: `AIManager.polish()` → async API call → `EntryState` machine transitions `writing → polishing → preview → saved/error`
4. User accepts text → `JournalManager.appendEntry()` writes to disk
5. Right-click opens context menu (Settings, Quit)

### Key Patterns

- **Singletons:** `ConfigManager.shared`, `AIManager.shared`
- **State machine UI:** `JournalEntryView` driven by `EntryState` enum, all branches in a single `switch`
- **Async/await:** API calls and file I/O use Swift concurrency; UI updates dispatched to `MainActor`
- **Config:** `~/.config/Quill/config.json` — read at launch, written on settings save. API keys stored in plain JSON (no keychain)

### Journal Storage

- **Vault root:** Configurable in Settings (stored in config.json as `journalPath`)
- **File path:** `{journalPath}/{YEAR}/{MMM-YYYY}.md`
- **Entry format:** Day-level `##` header + time-stamped `###` entry block

### AI Providers

| Provider | Auth | Endpoint |
|----------|------|----------|
| Claude | `x-api-key` header | `api.anthropic.com/v1/messages` |
| OpenAI | Bearer token | `api.openai.com/v1/chat/completions` |
| Gemini | API key in URL | `generativelanguage.googleapis.com/v1beta` |
| Ollama | None (local) | `localhost:11434/api/chat` |

### Claude Model IDs (current)
- Opus 4.7: `claude-opus-4-7`
- Sonnet 4.6: `claude-sonnet-4-6`
- Haiku 4.5: `claude-haiku-4-5-20251001`

---

## Android (`android/`)

### Stack
- Kotlin + Jetpack Compose
- Jetpack Glance for home screen widget
- Minimum API: 26 (Android 8.0)
- OkHttp for AI API calls; `org.json` (bundled) for JSON parsing
- No Room, no Retrofit — plain file I/O and bare HTTP

### Build

Open `android/` in Android Studio. To build via CLI:

```bash
cd android
./gradlew assembleDebug          # debug APK
./gradlew installDebug           # build + install to connected device
./gradlew assembleRelease        # release APK
```

### Source Files

```
android/app/src/main/java/com/hemanth/quill/
├── data/
│   ├── AppConfig.kt            # AIProvider, PolishMode enums + system prompts
│   ├── ConfigManager.kt        # SharedPreferences wrapper
│   ├── JournalManager.kt       # File I/O → same markdown format as macOS
│   └── AIManager.kt            # OkHttp calls to Claude/OpenAI/Gemini/Ollama
├── widget/
│   ├── QuillWidgetReceiver.kt  # GlanceAppWidgetReceiver
│   └── QuillWidget.kt          # Glance Compose widget UI (tap → QuickEntryActivity)
└── ui/
    ├── QuickEntryActivity.kt   # Dialog-themed entry screen (all EntryState branches)
    ├── QuickEntryViewModel.kt  # EntryState machine + coroutines
    ├── MainActivity.kt         # Launcher activity — hosts SettingsScreen
    ├── SettingsScreen.kt       # Compose settings UI
    └── theme/Theme.kt          # Material You dynamic color theme
```

### Widget UX

Android widgets cannot contain text input. The widget (`4×1` cells) shows date + a tap target. Tapping launches `QuickEntryActivity` as a dialog over the home screen (`windowIsFloating=true`, `excludeFromRecents=true`).

### EntryState machine (mirrors macOS)

```
Writing → Polishing → Preview → Saved (auto-dismiss 1.5s)
                              ↘ Error → Save Original / Retry
```

Defined in `QuickEntryViewModel.kt` as `sealed interface EntryState`.

### File Storage

`context.getExternalFilesDir(null)` — app-private external storage, no runtime permissions needed.

Path: `Android/data/com.hemanth.quill/files/Journal/{YEAR}/{MMM-yyyy}.md`

Markdown format is identical to macOS — same `##` day headers, `###` time headers.

### Config Storage

`SharedPreferences` (`quill_config`). Keys: `provider`, `mode`, `ai_enabled`, `api_key_{provider}`, `model_{provider}`, `ollama_host`.

### Verify output after a save

```bash
adb shell run-as com.hemanth.quill \
  cat /sdcard/Android/data/com.hemanth.quill/files/Journal/2026/Apr-2026.md
```
