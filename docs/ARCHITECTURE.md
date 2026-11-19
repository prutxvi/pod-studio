# Architecture

Single SwiftUI app target, built with `swiftc` (no Xcode project, no packages).

```
 Menu bar panel ─┐                       ┌─ PodAudio      CoreAudio: devices, default routes, volume, format, Music Guard
 Main window ────┼─ SwiftUI screens ─────┼─ PodProfiles   save/apply profiles, readback state machine
                 │                       ├─ PodSpotify    osascript → Spotify scripting dictionary (2 s poll)
                 │                       └─ NothingServiceImpl ── BluetoothManager (IOBluetooth RFCOMM) ── earbuds
                 └─ Store / view models (upstream)
 Storage: ~/Library/Application Support/Pod Studio/*.json (atomic writes), UserDefaults local.pruthvi.PodStudio
```

## Earbud protocol
Commands are framed packets over RFCOMM with a CRC16 trailer (`framework/utils/CRC16.swift`, `domain/enums/Commands.swift`).
Profiles send their read requests with an **operation token**. `PodProfileReadback` accepts only replies that have the matching token, an exact length, a valid checksum and values in range. CMF B172 firmware puts the CRC16 over the payload rather than the whole frame; that variant is accepted only on the CMF path. An empty reply to an unsupported read is never treated as a setting.

## Spotify
`PodSpotify` runs `/usr/bin/osascript` with a fixed script. Only validated `spotify:{track|album|playlist}:<22 base62>` URIs are interpolated into commands, so user text never runs as AppleScript. Fields come back separated by the ASCII unit separator (0x1F) and are parsed by `PodSpotifySnapshot`.

## Safety rules kept throughout
- Never report hardware state as confirmed from cached UI state or acknowledgements.
- Never overwrite a storage file that couldn't be read; block saves instead.
- Never touch Spotify's downloaded files.
