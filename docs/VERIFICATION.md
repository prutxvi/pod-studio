# Live verification — 2026-11-15

Device: CMF Buds Pro 2, firmware 1.0.1.74. Local macOS build 0.3.1.

## Observed

- macOS Bluetooth access enabled after the user completed Touch ID.
- Saved `My music` from new hardware read requests, not cached view-model state.
- Profile on disk: ANC reported as High, device EQ preset code 1, volume 75%, MacBook Air Microphone, Music Guard on.
- Applied the saved profile through the actual app UI. It displayed: `Confirmed “My music” · ANC and EQ read back from the earbuds; microphone and volume checked on your Mac.`
- Live trace contained the ANC and CMF listening-mode writes, acknowledgements, and token-matched read responses with the target values. Acknowledgements alone were not used as confirmation.
- This was save/reapply of an existing setup. Switching between different EQ presets, custom gain writes, physical reconnect, sleep/wake and audible quality are not independently verified by this check.

## Protocol corrections supported by this device

- CMF listening-mode read/write: 0xC050 / 0xF01D; fresh read response 0x4050.
- Custom-EQ read: 0xC044. Unsupported advanced-EQ reads return empty payloads; emptiness is not accepted as a setting.
- This B172 firmware's observed read replies carry the Modbus CRC16 of the payload. The model-specific decoder accepts this alongside full-frame checksums, still requiring an exact length, expected response, matching operation token and valid values. It does not treat an unsupported empty reply as a confirmation.
- Tests include recorded ANC/EQ replies and deliberately damaged/stale variants. Synthetic test results are in PROFILE-TESTS.txt.

## Sources consulted for protocol facts

- https://github.com/Zyrecx/noctalia-plugins/blob/main/nothing-ear/PROTOCOL.md
- https://github.com/maniacx/BudsLink/blob/main/src/lib/devices/nothingBuds/nothingBudsConfig.js
- https://github.com/radiance-project/ear-web

These references did not replace live verification. No reference implementation was copied for these profile additions.
