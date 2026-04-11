# Third-Party Inventory

Updated: 2026-04-11

## Active Dependencies In This Repository

| Component | Version | License | Source | Notes |
|---|---:|---|---|---|
| Godot Engine | 4.6.x stable target | MIT | https://godotengine.org/license/ | External runtime/editor for `apps/gesture_tool_godot` |
| miniaudio | vendored from current `master` on 2026-04-11 | MIT-0 / Public Domain | https://github.com/mackron/miniaudio | Vendored single-header decoder/encoder for audio asset I/O |
| Steam Audio SDK | 4.8.1 | Apache-2.0 | https://github.com/ValveSoftware/steam-audio/releases/tag/v4.8.1 | Vendored headers plus Linux/Windows x64 runtime libraries for binaural preview |

## Optional Future Dependencies

These are approved by the architecture plan but are not yet vendored into this repository.

| Component | Target Version | License | Source | Planned Use |
|---|---:|---|---|---|
| nlohmann/json | optional | MIT | https://github.com/nlohmann/json | Optional JSON handling |
| standalone Asio | optional | BSL-1.0 | https://github.com/chriskohlhoff/asio | Optional live-link transport |

## Notes

- No GPL/LGPL/AGPL dependencies have been added.
- Vendored license texts are stored in `LICENSES/APACHE-2.0.txt` and `LICENSES/MINIAUDIO.txt`.
- Steam Audio's SDK-side third-party inventory is included at `third_party/steam_audio/steamaudio/THIRDPARTY.md`.
