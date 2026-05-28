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

The current implementation exposes a slot-aware playback surface while preserving the original no-argument `primary` slot behavior.

The current implementation exposes:

- the frozen top-level playback states (`idle`, `loading`, `ready`, `playing`, `paused`, `stopping`, `error`)
- dedicated shared lifecycle APIs for `reset()` (soft recovery/reuse) and `unload()` (hard teardown)
- legacy playback signals for the active slot (`state_changed`, `position_changed`, `media_loaded`, `playback_finished`, `error_raised`)
- slot-aware signals for independent multi-video control (`slot_state_changed`, `slot_position_changed`, `slot_media_loaded`, `slot_playback_finished`, `slot_error_raised`)
- source normalization helpers for the current dictionary contract (`path`, `kind`, `slot`, `loop`, `autoplay`, `start_time`, `rate`)
- loop enable/disable support before or after load through the tool abstraction
- multi-slot helpers such as `set_active_slot()`, `get_slot_names()`, `attach_slot_surface()`, `detach_slot_surface()`, and slot-targeted `load` / `play` / `pause` / `stop` / `seek` / `set_loop` / `set_rate`
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
- `.testbed/scenes/video_player_testbed.tscn` now provides a repo-local two-slot manual smoke scene with independent load / play / pause / stop / seek / unload / loop controls for `left` and `right` video slots.
- `.testbed/scripts/video_player_testbed.gd` wires the stable public facade into that scene through direct injection of the real `aerobeat-vendor-godot-video` backend, so manual proving follows the real backend path instead of the default fake backend.
- Each slot now exposes manual source input plus quick presets for package-relative paths inside the Godot project, copied absolute device paths outside the project, and URL entry, along with a duration-hint input so arbitrary sources can still drive the timeline honestly.
- The proving HUD displays per-slot backend, state, position, duration, resolved playback path, and loop state so humans can exercise multi-video control through the tool abstraction rather than talking to the vendor layer directly.
- The seek sliders are the clickable timelines for both slots, and the shipped sample preset uses the truthful `28.693313s` duration hint so humans can verify seek behavior against the real clip.

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
- The manifest intentionally stays narrow: `aerobeat-tool-core`, `aerobeat-vendor-godot-video`, and `gut`.
- The fake backend remains the deterministic automated unit-test default for the public facade.
- The hidden manual proving scene now injects the real Godot vendor backend so load / play / pause / stop / seek / loop verification does not silently fall back to the fake backend.
- Loop and multi-slot behavior are covered in repo-local automated tests as well as the hidden two-slot proving scene.
- The hidden testbed also carries a real `.ogv` manual smoke asset so the repo proves the verified first media target without inventing a new fixture.
