#!/bin/zsh
# Offline checks: Spotify link/metadata parsing, profile protocol decoding, storage roundtrips.
# No earbuds, Spotify or audio changes needed.
#   scripts/test.sh             offline checks only
#   scripts/test.sh --hardware  also run the audio smoke test (briefly changes and restores Mac volume)
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pinned=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
sdk="${POD_SDK:-$([[ -d $pinned ]] && echo $pinned || xcrun --sdk macosx --show-sdk-path)}"

echo "== music"
swiftc -sdk "$sdk" -o "$tmp/music" "$root/Sources/music/PodMusicData.swift" "$root/tests/MusicChecks.swift"
"$tmp/music"

echo "== profiles"
swiftc -sdk "$sdk" -o "$tmp/profiles" "$root/Sources/profiles/PodProfileData.swift" "$root/Sources/domain/enums/Commands.swift" \
  "$root/Sources/framework/utils/CRC16.swift" "$root/tests/ProfileChecks.swift"
"$tmp/profiles"

if [[ "${1:-}" == "--hardware" ]]; then
  echo "== audio (hardware)"
  swiftc -sdk "$sdk" -swift-version 5 -o "$tmp/audio" "$root/Sources/presentation/window/PodAudio.swift" "$root/tests/AudioSmoke.swift"
  "$tmp/audio"
fi
