# AGENTS.md — build, install and change Pod Studio

Runbook for AI coding agents (Claude Code, OpenCode, Codex). Tell the user one short line per step.

## Rules
- **Never edit or delete `~/Library/Application Support/Pod Studio/`.** It holds the user's profiles and music shelf.
- Keep the bundle ID `local.pruthvi.PodStudio`. Changing it resets the Bluetooth/Automation permissions and preferences.
- Never bypass Touch ID or permission prompts, and never enter credentials for the user.
- Never claim a hardware behaviour works unless you saw it on the real device. Offline tests are not live verification; record live results in `docs/VERIFICATION.md`.
- Ask before playing audio, ringing the buds (Find My Buds is loud) or changing the Mac's audio routes.
- Keep GPL-3.0 headers and upstream attribution (NOTICE, docs/UPSTREAM.md).

## Step 1 — Toolchain
```sh
xcode-select -p && ls /Library/Developer/CommandLineTools/SDKs/
```
**Expect:** `MacOSX26.5.sdk` is listed. **If not:** the macOS 27 SDK in Command Line Tools lacks the SwiftUI macro plugins; install 26.5 or set `POD_SDK=/path/to/sdk`.

## Step 2 — Tests
```sh
scripts/test.sh
```
**Expect:** 8 `PASS` lines. Only run `--hardware` with the user's OK.

## Step 3 — Build and install
```sh
python3 build.py --install
```
**Expect:** `Installed: ~/Applications/Pod Studio.app` and the app opens. It quits the running copy first.

## Step 4 — Permissions (user does this)
Bluetooth prompt → Allow. Music → Connect Spotify → Automation prompt → Allow. If it's blocked: System Settings → Privacy & Security → Automation.

## Where things are
See README → Repository layout, and `docs/ARCHITECTURE.md`. Open bugs: `docs/KNOWN-ISSUES.md`.
