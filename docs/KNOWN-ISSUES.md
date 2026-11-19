# Known issues

Found in the 2026-11-19 audit. Most important first.

1. **One Spotify error disconnects the player.** Any error that isn't a permission problem (a timeout, or Spotify still starting up) sets `enabled = false`, so you have to click Connect again.
   `Sources/music/PodSpotify.swift` → `handleError`. Fix: retry a few times before disconnecting.

2. **Music buttons switch off every 2 seconds.** The 2 s poll runs `osascript` and sets `busy`. Play/next/seek/shuffle are `.disabled(spotify.busy)`, so clicks during a poll do nothing and a seek drag can be cut off.
   `Sources/music/PodMusicScreen.swift`, `PodSpotify.execute`. Fix: let your commands go ahead of the background poll (queue them instead of dropping them).

3. **Music Guard blocks the earbuds' mic on calls.** While it's on and the buds are the output, it switches the system default mic back to the built-in one every 3 s. Apps that use the default mic (Meet, WhatsApp) can't use the buds' mic until Guard is off.
   `Sources/presentation/window/PodAudio.swift` → `refresh`. Fix: pause Guard while a call is detected, or add a quick toggle in the menu bar.

4. **Buds are detected by name.** `isPodsOutput` and Music mode look for "cmf"/"nothing" in the device name. Rename the buds and those features stop working. Fix: match on the Bluetooth address in the output UID, as profiles already do.

5. **Audio is polled, not observed.** CoreAudio state is re-read every 3 s instead of using property listeners, which republishes the device list even when nothing changed.

## Not yet verified on hardware
Spotify play/pause/skip with a check that it actually happened · shelf playlist playback · custom EQ gains · switching between different presets · physical reconnect · sleep/wake · case battery (not reported by B172 fw 1.0.1.74).
