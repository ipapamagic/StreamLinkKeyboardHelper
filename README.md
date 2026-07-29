# Steam Link Keyboard Helper

Small macOS menu bar app for Steam Link sessions.

It watches the frontmost app. When Steam Link becomes the foreground app, it disables Spotlight shortcuts and remaps the F4 Search key to no event, then switches the current input source to `ABC`. When Steam Link leaves the foreground or quits, it restores the saved Spotlight shortcut settings and removes the F4 remap.

Current build target:

- Apple Silicon / `arm64`
- macOS 26 or newer

## Build & run

Open `SteamLinkKeyboardHelper.xcodeproj` in Xcode and press **Run** (`Cmd+R`). This is a regular Xcode App target — Xcode builds a proper `.app` bundle (with `Info.plist`, `LSUIElement`, and code signing), so there's no separate build script to run.

The first launch will trigger the macOS **Accessibility** permission prompt (needed to intercept the physical F4 key). Approve it in `System Settings > Privacy & Security > Accessibility`, then relaunch the app — the permission check only runs once at startup, so a fresh launch is required after granting it.

To install a persistent copy that survives Xcode/reboots:

1. In Xcode: `Product > Archive`, then **Distribute App > Copy App** (or **Custom > Copy App**) to export the signed `.app`.
2. Copy the exported `.app` to `/Applications`.

The menu bar item is named `F4`.

Localized in English, Traditional Chinese, and Japanese (`Localizable.xcstrings`). Follows the system language automatically.

Notes:

- Signing uses Xcode's automatic signing (your Apple ID / personal team). Because the bundle identifier and signing identity stay stable across rebuilds, the granted Accessibility permission persists across rebuilds too.
- Developer ID signing, notarization, and stapling are intentionally kept out of this repository because they use local Apple credentials.
- If you copy the built `.app` through Telegram, AirDrop, or similar, macOS may attach a quarantine flag that blocks it entirely (`File created by an AppSandbox, exec/open not allowed`). Always install from a clean local build (Xcode Archive/export) rather than a transferred copy.
