<div align="center">

# Pod Studio

**A native macOS control centre for CMF and Nothing earbuds, with Mac audio routing, saved listening profiles and a Spotify player built in.**<br>
Menu-bar app. No Electron, no accounts, no API keys.

![GPL-3.0](https://img.shields.io/badge/licence-GPL--3.0-ff2a2a?style=flat-square&labelColor=000)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-ffffff?style=flat-square&labelColor=000)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-ffffff?style=flat-square&labelColor=000)
![CMF Buds Pro 2](https://img.shields.io/badge/tested%20on-CMF%20Buds%20Pro%202-ff2a2a?style=flat-square&labelColor=000)
![No dependencies](https://img.shields.io/badge/dependencies-none-ffffff?style=flat-square&labelColor=000)

[Verification](docs/VERIFICATION.md) &nbsp;·&nbsp; [Known issues](docs/KNOWN-ISSUES.md) &nbsp;·&nbsp; [Architecture](docs/ARCHITECTURE.md) &nbsp;·&nbsp; [Changelog](CHANGELOG.md)

</div>

> Built by **[prutxvi](https://github.com/prutxvi)** with **Claude** (Anthropic's AI). My CMF Buds Pro 2 sounded muddy on the Mac and there's no official CMF app for macOS. I set the direction and made the calls; Claude did the diagnosis, protocol work, code and docs. Forked from [nikiomori/nothing-x-macos](https://github.com/nikiomori/nothing-x-macos) (GPL-3.0).

## Why it exists

When CMF/Nothing buds are both the Mac's output **and** its microphone, macOS drops them into the headset profile: **mono, 16 kHz**. Music sounds like a phone call. Switching the microphone to the MacBook's built-in mic brings it back to **stereo, 44.1 kHz**. Pod Studio makes that one click, can keep it that way, and also controls the buds themselves.

## Features

| | What you get |
|---|---|
| **Mac Audio** | Pick output and microphone, hardware volume, live channel count and sample rate. One-click **Music mode** selects the buds for output and the built-in mic for input. |
| **Music Guard** *(optional)* | While the app runs, checks every 3 s and switches the system mic back to the built-in one whenever the buds are the output. |
| **Earbud controls** | Noise control (ANC / transparency / off), EQ presets, bass, gestures, Find My Buds, ear-tip test, per-bud battery and firmware, from the upstream app. |
| **Listening profiles** | Save ANC + EQ + Mac output/mic + volume + Music Guard as a named profile. **Apply & check** only says *Confirmed* after fresh checksum-verified reads from the buds and a check of the Mac routes. Acknowledgements alone never count. |
| **Spotify player** | Now playing with artwork, play/pause, previous/next, seek, shuffle, a local shelf of saved tracks/playlists, recent history and menu-bar controls. Talks to the installed Spotify app through macOS Automation, so no password or developer key is needed. |
| **Look** | Dot-matrix headings, graphite cards, dotted device art. **CMF** (orange) or **Nothing** (red) theme. |

## Quick start

You need macOS 26+ and Apple's Command Line Tools (`xcode-select --install`) with the macOS 26.5 SDK. Xcode is not needed.

```sh
git clone https://github.com/prutxvi/pod-studio
cd pod-studio
python3 build.py --install      # builds build/Pod Studio.app, copies it to ~/Applications, opens it
```

The first time it runs:
1. Allow **Bluetooth** when macOS asks. Without it the buds can't connect.
2. Open **Music → Connect Spotify** and allow **Automation** access for Spotify.
3. Close Nothing X / Ear (web) / other companion apps. Only one app can control the buds at a time.

Other build options: `python3 build.py` (build only) and `python3 build.py --release` (optimised).

## Tests

```sh
scripts/test.sh              # offline: Spotify link/metadata parsing, profile protocol decoding, storage roundtrips
scripts/test.sh --hardware   # also an audio smoke test (briefly changes and restores Mac volume)
```

Offline checks use recorded CMF reply frames, plus deliberately damaged and stale ones. Live hardware results are logged separately in [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Status

| Area | State |
|---|---|
| Mac output/mic switching, volume, stereo 44.1 kHz restore | ✅ verified live |
| Buds connection, per-bud battery, firmware read (B172, fw 1.0.1.74) | ✅ verified live |
| Save + reapply a listening profile (ANC High, preset 1) | ✅ verified live |
| Spotify now-playing metadata + recent history | ✅ observed live |
| Spotify play/pause/skip, shelf playback | ⏳ not yet confirmed |
| Custom EQ gains, switching between different presets, reconnect, sleep/wake | ⏳ unverified |
| Case battery | ❌ not reported by this firmware |

## Repository layout

```
Sources/             app source (SwiftUI)
  music/             Spotify player + shelf          (Pod Studio)
  profiles/          listening profiles + readback    (Pod Studio)
  presentation/      screens; window/PodAudio*.swift = Mac Audio (Pod Studio)
  framework/         Bluetooth RFCOMM + Nothing protocol (upstream, patched for CMF)
  data/, domain/     storage, models, use cases (upstream)
tests/               offline checks + audio smoke test
scripts/test.sh      test runner
build.py             build / install script
design/              app icon generator
resources/           app icon
docs/                verification log, known issues, architecture, upstream README
```

## Where your data lives

`~/Library/Application Support/Pod Studio/`: `listening-profiles.json`, `music-library.json`, `configurations.json`. Theme and Music Guard are stored in `defaults read local.pruthvi.PodStudio`. Everything stays on the Mac and nothing syncs to the cloud. If a file is corrupt it is kept as-is and saving is blocked, never overwritten.

## Limits

- It **cannot** enable LDAC on macOS, raise the AAC bitrate the Mac negotiates, or guarantee phone-level sound.
- Spotify stays the playback engine. Pod Studio does not copy, decrypt or list your downloaded songs. Shelf items are links, not downloads.
- Profiles are not applied automatically when the buds reconnect, and the app doesn't start at login.
- The build is ad-hoc signed and not notarized. It's meant for your own Mac.

## Credits and licence

GPL-3.0, inherited from upstream; see [LICENSE](LICENSE) and [NOTICE](NOTICE). Based on [nikiomori/nothing-x-macos](https://github.com/nikiomori/nothing-x-macos) and [Arunavo Ray's original](https://github.com/arunavo4/nothing-x-macos), with protocol references from [Ear (web)](https://github.com/radiance-project/ear-web) and [BudsLink](https://github.com/maniacx/BudsLink). Unofficial: not affiliated with or endorsed by Nothing Technology. Nothing/CMF names and product imagery belong to their owners.
