# Wouldyou

Spatial composition workspace with:

- a Godot 4 companion app for gesture/path authoring
- a C++20 CLI for loading trajectory projects, evaluating transforms, and rendering preview audio

Current scope:

- Phase 0 scaffold
- Phase 1 JSON authoring pipeline
- usable Phase 2 subset in the Godot tool:
  - orbit macro generation
  - direct scene selection and dragging
  - mouse-driven gesture recording with baked keys
- Phase 3 offline preview rendering:
  - miniaudio-backed asset I/O
  - Steam Audio binaural rendering when SDK files are present
  - stereo fallback renderer remains available as a build fallback
- minimal Phase 4 live-preview workflow:
  - file watch + rerender CLI loop
  - TCP snapshot sync between Godot and the CLI renderer
- mobile-ready recording hook:
  - optional accelerometer/gyroscope motion input in the Godot app

## Repository Layout

```text
apps/
  gesture_tool_godot/
  spatial_preview_cli/
docs/
  ADR/
  THIRD_PARTY.md
shared/
  examples/
  schemas/
LICENSES/
```

## Apps

### `apps/gesture_tool_godot`

Standalone Godot companion app for:

- listener and source placement
- manual keyframe editing
- project import/export
- path preview
- direct dragging in the 3D scene
- mouse gesture recording
- optional mobile sensor-driven recording
- orbit macro baking

Open the folder with Godot 4.6.x and run `scenes/Main.tscn`.

### `apps/spatial_preview_cli`

C++20 command line tool for:

- loading project JSON
- validating core structure
- evaluating listener/source transforms at any time
- sampling a project across its duration
- rendering offline preview WAV files
- rerendering on file changes with watch mode
- accepting TCP live-sync snapshots for immediate rerender

## Build

```bash
cmake -S . -B build
cmake --build build
```

Or with presets:

```bash
cmake --preset default
cmake --build --preset default
```

Example:

```bash
./build/apps/spatial_preview_cli/spatial_preview_cli summary shared/examples/simple_orbit/project.json
./build/apps/spatial_preview_cli/spatial_preview_cli eval shared/examples/simple_orbit/project.json 2.0
./build/apps/spatial_preview_cli/spatial_preview_cli sample shared/examples/simple_orbit/project.json 2.0
./build/apps/spatial_preview_cli/spatial_preview_cli render shared/examples/simple_orbit/project.json build/simple_orbit_preview.wav
./build/apps/spatial_preview_cli/spatial_preview_cli render shared/examples/listener_flythrough/project.json build/listener_flythrough_preview.wav
```

Live reload workflow:

```bash
./build/apps/spatial_preview_cli/spatial_preview_cli watch-render shared/examples/simple_orbit/project.json build/simple_orbit_preview.wav
```

TCP live sync workflow:

```bash
./build/apps/spatial_preview_cli/spatial_preview_cli tcp-render build/live_preview.wav 49090
```

The Godot app's `Enable TCP Snapshot Sync` toggle is configured to send snapshots to `127.0.0.1:49090` by default.
For Windows Godot talking to a renderer inside WSL2, `127.0.0.1` may not be the right destination. In that setup, point the Godot host field at the WSL IP instead, or run the renderer on Windows too.

## Windows

### Godot App

1. Install Godot 4.6.x on Windows.
2. Open `apps/gesture_tool_godot/project.godot`.
3. Run `scenes/Main.tscn` from the editor.
4. Export with the normal Godot Windows desktop export flow when you are ready to package.

On mobile exports, the Godot app can also use device sensors while recording if `Use Device Sensors When Available` is enabled.

### C++ CLI

With Visual Studio 2022:

```powershell
cmake --preset windows-msvc
cmake --build --preset windows-msvc
.\build\windows-msvc\apps\spatial_preview_cli\Release\spatial_preview_cli.exe summary .\shared\examples\simple_orbit\project.json
.\build\windows-msvc\apps\spatial_preview_cli\Release\spatial_preview_cli.exe render .\shared\examples\simple_orbit\project.json .\build\windows-msvc\simple_orbit_preview.wav
.\build\windows-msvc\apps\spatial_preview_cli\Release\spatial_preview_cli.exe tcp-render .\build\windows-msvc\live_preview.wav 49090
```

With newer Visual Studio installs, the simplest option is to open Developer PowerShell for Visual Studio and use the version-agnostic Ninja preset:

```powershell
cmake --preset windows-ninja
cmake --build --preset windows-ninja
.\build\windows-ninja\apps\spatial_preview_cli\spatial_preview_cli.exe summary .\shared\examples\simple_orbit\project.json
.\build\windows-ninja\apps\spatial_preview_cli\spatial_preview_cli.exe render .\shared\examples\simple_orbit\project.json .\build\windows-ninja\simple_orbit_preview.wav
.\build\windows-ninja\apps\spatial_preview_cli\spatial_preview_cli.exe tcp-render .\build\windows-ninja\live_preview.wav 49090
```

If your CMake version supports the Visual Studio 2026 generator, `windows-vs2026` is also available.

The repository now includes a Windows GitHub Actions workflow in [windows-build.yml](/home/alinfty/coding/Wouldyou/.github/workflows/windows-build.yml:1) that builds the CLI with MSVC and runs smoke checks on both offline rendering and TCP live-sync rendering.

## Vendored Native Dependencies

- `third_party/miniaudio/include/miniaudio.h`
- `third_party/steam_audio/steamaudio/include/phonon.h`
- `third_party/steam_audio/steamaudio/lib/linux-x64/libphonon.so`
- `third_party/steam_audio/steamaudio/lib/windows-x64/phonon.lib`
- `third_party/steam_audio/steamaudio/lib/windows-x64/phonon.dll`
