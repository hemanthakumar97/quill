# Quill

A lightweight journaling tool for capturing quick thoughts with optional AI polish. Available for macOS (menu bar) and Android (home screen widget).

---

## Platforms

### macOS — Menu Bar App
Lives in the menu bar. Click the icon, type, press Return — entry saved to your Obsidian vault.

**Requires macOS 14 (Sonoma) or later.**

#### Prerequisites

```bash
xcode-select --install
```

#### Install

```bash
git clone https://github.com/hemanthakumar97/quill.git
cd quill/macos
bash install.sh
```

The script builds a release binary, bundles it as `Quill.app`, installs to `~/Applications/`, and adds it to Login Items.

#### Updating

Pull the latest changes and re-run `bash macos/install.sh`.

---

### Android — Home Screen Widget
A `4×1` widget on your home screen. Tap it → type your entry → save. Entries are stored locally on the device.

**Requires Android 8.0 (API 26) or later.**

#### Build & Install

Open the `android/` folder in Android Studio. It will auto-download Gradle and dependencies. Connect your phone via USB with USB Debugging enabled, then click **Run**.

To build an APK for side-loading:

```bash
cd android
./gradlew assembleDebug
# APK at: app/build/outputs/apk/debug/app-debug.apk
```

---

## Journal Storage

### macOS
Entries are saved to your Obsidian vault (configurable in Settings):

```
/Your/Vault/Journal/
└── 2026/
    └── Apr-2026.md
```

### Android
Entries are saved locally on the device:

```
Android/data/com.hemanth.quill/files/Journal/
└── 2026/
    └── Apr-2026.md
```

Both platforms use the same markdown format — day-level `##` headers and time-stamped `###` entry blocks — so files are readable in Obsidian without any plugin.

> **Note (macOS):** The vault path is configurable in Settings. Default path is hardcoded for first launch.

---

## Usage

### macOS
**Left-click** the menu bar icon to open the journal popover.

| Action | Shortcut |
|--------|----------|
| Save entry | **Return** |
| Insert a newline | **Shift + Return** |
| Save polished version | **Cmd + Return** |

**Right-click** the menu bar icon for Settings and Quit.

### Android
Tap the **Quill widget** on your home screen → a dialog opens with the keyboard ready. Type your entry and tap **Save** (or **Polish & Save** if AI is enabled).

Access Settings via the gear icon in the entry dialog, or by opening the Quill app from the app drawer.

---

## AI Polishing (optional)

Supports Claude, OpenAI, Gemini, and Ollama. Configure in Settings on each platform.

| Provider | Where to get a key |
|----------|--------------------|
| **Claude** | [console.anthropic.com](https://console.anthropic.com) → API Keys |
| **OpenAI** | [platform.openai.com](https://platform.openai.com) → API Keys |
| **Gemini** | [aistudio.google.com](https://aistudio.google.com) → Get API Key |
| **Ollama** | Run locally — `ollama serve` (macOS only) |

### Polish Modes

| Mode | What it does |
|------|-------------|
| **Light** | Fixes grammar and spelling, keeps your voice intact |
| **Full** | Rewrites the entry as flowing prose |
| **Structured** | Organises the entry into three markdown sections |

---

## Configuration

### macOS
`~/.config/Quill/config.json` — read at launch, written on Settings save.

### Android
`SharedPreferences` (app-private) — updated via the Settings screen.
