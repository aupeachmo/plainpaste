# To Do

## Will do
- Signed and attested releases (like with aigogo)
- Homebrew tap (same as aigogo, use the same release bot to push to the brew formula repo)
  - Rename `aigogo-homebrew-updater` to `aupeach-homebrew-updater` (will this break any config or signatures?)

## Possible Features
1. Clear clipboard after paste, prevent inadvertent leaks (make it configurable option, where to persist the config)?

| Option | How it works | Permissions | Catches all pastes? |
|---|---|---|---|
| Timer-based clear | Clear clipboard N seconds after stripping | None | N/A — doesn't detect paste, just assumes it happened |
| CGEvent tap for ⌘V | Global keyboard hook detects the shortcut | Accessibility | No — misses menu and right-click paste |
| NSEvent global monitor | Slightly simpler keyboard hook | Accessibility | No — same limitation |
| Accessibility API menu watch | Observe the Paste menu item in any app | Accessibility | Yes — but fragile, scraping other apps' UI |
| Clipboard read count | Watch for read patterns | N/A | Dead end — macOS doesn't expose reads |

The timer is the only option that stays permission-free. Everything else requires Accessibility access, which fundamentally changes the trust model of the app.
