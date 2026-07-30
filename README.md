# Steam Link Keyboard Helper

Small macOS menu bar app for Steam Link sessions.

It watches the frontmost app. When Steam Link becomes the foreground app, it disables Spotlight shortcuts and remaps the F4 Search key to no event, then switches the current input source to `ABC`. When Steam Link leaves the foreground or quits, it restores the saved Spotlight shortcut settings and removes the F4 remap.

Current build target:

- Apple Silicon / `arm64`
- macOS 26 or newer

## Project structure

This is a regular Xcode App project (`SteamLinkKeyboardHelper.xcodeproj`), not a SwiftPM command-line tool. Source files, one type per file:

```
SteamLinkKeyboardHelper/
    AppDelegate.swift        — app lifecycle, menu bar UI, menu actions
    AppConstants.swift       — shared constants
    Notifier.swift           — local notifications
    SteamLinkDetector.swift  — detects whether Steam Link is the foreground app
    F4EventInterceptor.swift — global keyboard event tap that blocks the physical F4 key
    KeyboardManager.swift    — Spotlight hotkey toggling / input source switching
    Shell.swift               — small helper to run child processes (hidutil, killall)
    Localizable.xcstrings    — en / zh-Hant / ja localization
    Assets.xcassets          — app icon
    Info.plist
```

## Signing (required before Accessibility permission will stick)

Add your Apple ID to Xcode first: **Xcode > Settings > Accounts > +**. Then in the project's **Signing & Capabilities** tab, make sure a **Team** is selected (a free Personal Team is enough — no paid Apple Developer Program needed).

This matters because F4 interception needs the **Accessibility** permission (`AXIsProcessTrustedWithOptions`), and macOS ties that grant to the app's code signature. Without a Team, Xcode falls back to ad-hoc signing (`Signature=adhoc`, no Team ID), and the signature hash changes on every rebuild — so macOS treats each build as a brand-new, never-approved app and asks for permission again every single time. With a Team selected, the signature stays tied to the same Team ID + Bundle ID across rebuilds, so the permission grant persists.

## Build & run

**Quick test (Debug run):** Open `SteamLinkKeyboardHelper.xcodeproj` in Xcode and press **Run** (`Cmd+R`). Fine for iterating, but the built `.app` lives in Xcode's DerivedData folder, not somewhere convenient for daily use.

**Real installable copy (recommended for daily use):**

1. In Xcode: `Product > Archive`.
2. In the Organizer window that opens, select the archive and click **Distribute App**.
3. Choose **Custom > Copy App** (not App Store Connect) and pick an export folder.
4. Copy the exported `Steam Link Keyboard Helper.app` into `/Applications`, then launch it from there.

The first launch will trigger the macOS **Accessibility** permission prompt (needed to intercept the physical F4 key). Approve it in `System Settings > Privacy & Security > Accessibility`, then relaunch the app — the permission check only runs once at startup, so a fresh launch is required after granting it. As long as the Team stays the same, this only needs to happen once, even across rebuilds.

The menu bar item is named `F4`. Clicking it shows the current Steam Link / F4 Spotlight status and a Quit item — no manual toggle buttons, since disabling/restoring F4 and switching input source already happen automatically based on Steam Link's foreground state.

Localized in English, Traditional Chinese, and Japanese (`Localizable.xcstrings`). Follows the system language automatically.

Notes:

- Developer ID signing, notarization, and stapling are intentionally kept out of this repository because they use local Apple credentials.
- If you copy the built `.app` through Telegram, AirDrop, or similar, macOS may attach a quarantine flag that blocks it entirely (`File created by an AppSandbox, exec/open not allowed`). Always install from a clean local build (Xcode Archive/export) rather than a transferred copy.
