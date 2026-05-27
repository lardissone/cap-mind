# CapMind

> Working title — likely rebranded before the first public release. The name lives behind constants in `Sources/CapMind/AppConstants.swift`, so a global rename is a find-and-replace.

A macOS menu-bar app that sends content to [MyMind](https://mymind.com) with zero friction — no browser, no organizing step. Three ways in:

- **Text note** — a global hotkey opens a small floating editor; type, `⌘↩`, done.
- **Region screenshot** — a global hotkey gives you a crosshair; drag a region and it uploads as a native-resolution PNG.
- **Drag-and-drop** — drop files, a URL, selected text, or an image onto the menu-bar icon.

CapMind is write-only: it never lists, searches, or shows your existing MyMind objects. It's the sibling of [CapNote](https://github.com/lardissone/cap-note) (same idea, for Capacities) and reuses its architecture, UI patterns, and build pipeline.

## Requirements

- macOS 15.0 (Sequoia) or later.
- A paid MyMind account and an **access key** (Key ID + secret) from [access.mymind.com/extensions](https://access.mymind.com/extensions).

## Install

Download the latest signed, notarized build from [Releases](https://github.com/lardissone/cap-mind/releases), unzip, and move `CapMind.app` to `/Applications`. CapMind auto-updates via [Sparkle](https://sparkle-project.org/).

On first launch there's no window and no Dock icon — look for the tray icon in the menu bar (it starts red, meaning "not configured yet").

## Setup

1. Click the menu-bar icon → **Open Settings…**
2. In **Account**, click **Generate access key** to open MyMind, create a key, and copy the **Key ID** and **secret** (the secret is shown only once).
3. Paste both into CapMind and click **Test connection**. Green "Connected" means you're set — the icon turns normal and the actions enable. The secret is stored in your macOS Keychain; the Key ID lives in `UserDefaults`.

## Usage

| Action | Default shortcut | Notes |
| --- | --- | --- |
| New note | `⌘⇧⌥M` | Floating editor. `⌘↩` send · `Esc` discard. |
| Capture region | `⌘⇧⌥S` | Drag a rectangle; `Esc` cancels. Uploads PNG at native resolution. |
| Drag-and-drop | — | Drop onto the menu-bar icon. Multiple items upload serially with a progress toast. |

Both shortcuts are configurable in **Settings → Shortcuts**.

> **Shortcut conflicts:** the `⌘⇧⌥M`/`⌘⇧⌥S` defaults can clash with launchers/capture tools (Raycast, Alfred, CleanShot's `⌘⇧⌥`-space family). If a hotkey doesn't fire, rebind it in Settings.

> **Screen Recording permission:** the first region capture triggers macOS's Screen Recording prompt. If you decline, CapMind shows an alert linking straight to **System Settings → Privacy & Security → Screen Recording** — enable CapMind there and try again.

Supported drop formats (per [MyMind](https://access.mymind.com/api/supported-formats), 64 MB cap): jpg, jpeg, png, gif, webp, avif, heif/heic, jxl, bmp, tiff, psd, svg, txt, md, pdf. A dragged web link is sent as a URL; selected text is sent as Markdown; oversized or unsupported files are rejected before any upload with a clear toast.

## Build from source

```bash
git clone https://github.com/lardissone/cap-mind
cd cap-mind
xed .            # opens the SwiftPM package in Xcode
# or, from the CLI:
swift build
swift test
```

To assemble a runnable `.app` locally (ad-hoc signed):

```bash
bin/make-app.sh        # builds dist/CapMind.app for the host arch
```

Releases are produced by `.github/workflows/release.yml` on a `v*` tag: build → Developer-ID sign (hardened runtime) → notarize → staple → GitHub Release → Sparkle appcast on `gh-pages`.

### Required release configuration

Before cutting a release, set these GitHub repo **secrets**: `MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_P12_PASSWORD`, `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID`, `SPARKLE_ED_PRIVATE_KEY`. Generate a Sparkle EdDSA key pair once (`generate_keys` from the Sparkle tools) and paste the **public** key into `SU_PUBLIC_ED_KEY` in `bin/make-app.sh`.

## Architecture

A custom `NSStatusItem` (menu + drag destination) drives three `@MainActor` coordinators — `NotePanelController`, `RegionCaptureController`, `DropController` — that all call one stateless `MyMindClient` (URLSession + HS256 JWT signer + hand-built multipart + single-retry rate-limit backoff). No local database; settings in `UserDefaults`, the API secret in Keychain. See `docs/PRD.md` for the full specification and `docs/superpowers/plans/` for the implementation plan.

Dependencies: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (global hotkeys) and [Sparkle](https://github.com/sparkle-project/Sparkle) (updates). JWT signing uses CryptoKit; no other third-party libraries.

## License

TBD.
