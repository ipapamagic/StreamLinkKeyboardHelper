# Steam Link Keyboard Helper

Small macOS menu bar app for Steam Link sessions.

It watches the frontmost app. When Steam Link becomes the foreground app, it disables Spotlight shortcuts and remaps the F4 Search key to no event, then switches the current input source to `ABC`. When Steam Link leaves the foreground or quits, it restores the saved Spotlight shortcut settings and removes the F4 remap.

Current build target:

- Apple Silicon / `arm64`
- macOS 26 or newer

Build:

```bash
./scripts/build-app.sh
```

Install and open:

```bash
./scripts/install-app.sh
```

The menu bar item is named `F4`. Use `Install launch at login` from the menu if the helper should start automatically.

Notes:

- The build script creates an ad-hoc signed local `.app` under `build/`.
- Developer ID signing, notarization, and stapling are intentionally kept out of this repository because they use local Apple credentials.
- Telegram-downloaded app bundles may be blocked by macOS with `File created by an AppSandbox, exec/open not allowed`; install from a clean local build or a trusted non-sandboxed distribution path.
