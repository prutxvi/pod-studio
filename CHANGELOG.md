# Changelog

## 0.4.0 — 2026-11-16 · Spotify player
- Music section: now playing + artwork, play/pause, previous/next, seek, shuffle, Mac volume, menu-bar controls.
- Local shelf of Spotify track/album/playlist links and up to 40 recent tracks. Links are validated (base62 IDs only) before they reach AppleScript.
- Uses the installed Spotify app's scripting dictionary through macOS Automation. No API key, password or token.
- Fix: removed the unsupported `exists current track` check (Spotify error -1708).

## 0.3.1 — 2026-11-15 · Live CMF verification
- Saved and reapplied a profile on real CMF Buds Pro 2 (B172, fw 1.0.1.74) and got a confirmed readback.
- Fixed CMF listening-mode commands (0xC050 / 0xF01D, reply 0x4050) and custom/advanced EQ reads (0xC044 / 0xC04C).
- B172 replies carry a payload CRC16; accepted only on that model's path.

## 0.3.0 — 2026-11-15 · Listening profiles
- Save/rename/apply profiles (ANC, EQ preset or custom gains, output/mic UIDs, volume, Music Guard, earbud identity).
- "Confirmed" only after token-matched, CRC-checked reads plus a check of the Mac routes and volume.
- Atomic JSON storage in Application Support; corrupt files are kept and saving is blocked.

## 0.2.0 — 2026-11-15 · Appearance
- Dot-matrix headings, graphite cards, dotted device art, pill controls, PS icon. CMF orange / Nothing red theme switch.

## 0.1.0 — 2026-11-15 · Mac Audio
- Output/mic selection, hardware volume, live channels/sample rate, one-click Music mode, optional Music Guard.
- Fork of nikiomori/nothing-x-macos; storage moved from generic Documents paths to Application Support.
