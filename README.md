# AeroBeat Tool Video Player

This repo owns the reusable **video playback contract** for the current AeroBeat tool architecture.

It should be read against the locked product direction from `aerobeat-docs`:

- **Primary release target:** PC community first
- **Official v1 gameplay features:** Boxing and Flow
- **Official v1 gameplay input:** camera only
- **Tool stance:** this repo owns generic playback lifecycle, time, surface binding, and backend abstraction rather than camera-tracking-specific replay logic
- **Replay ownership split:** replay consumers such as camera tracking should consume this tool's stable playback contract instead of re-implementing generic play/pause/seek/surface ownership

## Current facade scope

The sharable package surface now centers on `src/AeroVideoPlayerManager.gd`.

`AeroVideoPlayerManager` is the stable public facade for downstream tool consumers. It keeps the higher-level playback lifecycle signals and state transitions in this repo while consuming the shared vocabulary from `aerobeat-tool-core`.

The current implementation exposes:

- the frozen top-level playback states (`idle`, `loading`, `ready`, `playing`, `paused`, `stopping`, `error`)
- the playback signals (`state_changed`, `position_changed`, `media_loaded`, `playback_finished`, `error_raised`)
- source normalization helpers for the current dictionary contract (`path`, `kind`, `loop`, `autoplay`, `start_time`, `rate`)
- a backend injection boundary via `src/AeroVideoPlayerBackend.gd`
- a deterministic fake backend used by repo-local tests and the hidden `.testbed/` workbench
- the output-surface attach/detach contract needed by replay and presentation consumers

## Shared contract ownership split

- `aerobeat-tool-core` owns the shared playback vocabulary and backend interface slice (`AeroVideoPlaybackContract`, `AeroVideoPlaybackBackend`).
- `aerobeat-tool-video-player` owns the tool-facing orchestration facade (`AeroVideoPlayerManager`), lifecycle signals, normalized state transitions, and backend injection policy.
- Vendor repos such as Godot-native playback should adapt their runtime-specific behavior behind this facade rather than redefining the public tool contract.

## Repo-local proving surface

The hidden `.testbed/` workbench now includes a real `.ogv` proving surface.

- `.testbed/assets/videos/calm_blue_sea_1.ogv` reuses the proven environment-lane sample.
- `.testbed/scenes/video_player_testbed.tscn` provides a repo-local manual smoke scene.
- `.testbed/scripts/video_player_testbed.gd` wires the public facade into that scene using the real sample path.

This keeps the repo honest about the primary first verified media target while still letting the facade stay backend-injection-friendly.

## 📋 Repository Details

- **Type:** Video playback tool package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Current vendor status:** deterministic fake backend by default; concrete vendors should be injected behind the shared core contract
- **Future vendor direction:** Godot-native and other playback vendors should slot in behind the repo-owned facade rather than redefining the public contract

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

The repo root remains the package/published boundary for downstream consumers. Day-to-day development, debugging, and validation happen from the hidden `.testbed/` workbench using the pinned OpenClaw toolchain: Godot `4.6.2 stable standard`.

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

If addon state gets noisy during AeroBeat polyrepo work, use the canonical helper instead of editing mirrored addon payloads directly:

```bash
/workspace/scripts/godotenv-sync --repo /workspace/projects/aerobeat/aerobeat-tool-video-player
```

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

Use this `.testbed/` project as the canonical direct-development and bugfinding surface for facade and backend work.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

### Validation notes

- `.testbed/addons.jsonc` is the committed dev/test dependency contract.
- The manifest intentionally stays narrow: `aerobeat-tool-core` plus `gut`.
- The fake backend remains the deterministic automated proving surface.
- The hidden testbed also carries a real `.ogv` manual smoke asset so the repo proves the verified first media target without inventing a new fixture.
