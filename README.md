# Quill

A lightweight macOS menu bar journaling app. Click the icon, write a thought, press Return — and it's saved to your Obsidian vault. Optionally, let an AI model polish the entry before it hits disk.

**Requires macOS 14 (Sonoma) or later.**

---

## Installation

### Prerequisites

You need Xcode Command Line Tools. If you haven't installed them:

```bash
xcode-select --install
```

### Install

Clone the repo, then run the installer:

```bash
git clone https://github.com/hemanthakumar97/quill.git
cd quill
bash install.sh
```

The script will:
1. Build a release binary with Swift
2. Bundle it into `Quill.app`
3. Install it to `~/Applications/Quill.app`
4. Launch the app immediately
5. Attempt to add it to Login Items so it auto-starts on reboot

Once launched, you'll see a book icon (📄) in your menu bar.

### Updating

Pull the latest changes and re-run `bash install.sh`. It stops any running instance, rebuilds, and reinstalls automatically.

---

## Journal Storage

Entries are saved as markdown files inside your Obsidian vault:

```
/Volumes/Hemanth/Obsidian Vault/Journal/
└── 2026/
    └── Apr-2026.md
```

Each file uses day-level `##` headers and time-stamped `###` entry blocks, so everything stays readable in Obsidian without any plugin.

> **Note:** The vault path is currently hardcoded. If your vault lives elsewhere, update the path in `Sources/Quill/JournalManager.swift`.

---

## Usage

**Left-click** the menu bar icon to open the journal popover.

| Action | Shortcut |
|--------|----------|
| Save entry | **Return** |
| Insert a newline | **Shift + Return** |
| Save polished version (AI preview) | **Cmd + Return** |

**Right-click** the menu bar icon for Settings and Quit.

### AI Polishing (optional)

Open Settings (gear icon or right-click → Settings), toggle **Enable AI polishing**, and pick a provider:

| Provider | What you need |
|----------|--------------|
| **Claude** | API key from [console.anthropic.com](https://console.anthropic.com) → API Keys |
| **OpenAI** | API key from [platform.openai.com](https://platform.openai.com) → API Keys |
| **Gemini** | API key from [aistudio.google.com](https://aistudio.google.com) → Get API Key |
| **Ollama** | Ollama running locally (`ollama serve`) with at least one model pulled |

When AI is enabled, pressing Return sends your draft to the selected model. You'll see a preview of the polished text and can choose to **Save Polished** or **Save Original**.

#### Polish Modes

| Mode | What it does |
|------|-------------|
| **Light** | Fixes grammar and spelling, keeps your voice intact |
| **Full** | Rewrites the entry as flowing prose |
| **Structured** | Organises the entry into three markdown sections |

---

## Configuration

Settings are stored at `~/.config/Quill/config.json`. You can edit this file directly or use the in-app Settings panel. It holds your selected provider, model, polish mode, and API keys.
