# AeroBeat Tool Video Player

This repo owns the reusable **video playback contract** for the current AeroBeat tool architecture.

It should be read against the locked product direction from `aerobeat-docs`:

- **Primary release target:** PC community first
- **Official v1 gameplay features:** Boxing and Flow
- **Official v1 gameplay input:** camera only
- **Tool stance:** this repo owns generic playback lifecycle, time, surface binding, and backend abstraction rather than camera-tracking-specific replay logic
- **Replay ownership split:** replay consumers such as camera tracking should consume this tool's stable playback contract instead of re-implementing generic play/pause/seek/surface ownership

## Current first-slice scope

The current implementation is intentionally a **contract shell**, not a real vendor playback integration yet.

The sharable package surface currently centers on `src/AeroToolManager.gd`, which exposes:

- the frozen top-level playback states (`idle`, `loading`, `ready`, `playing`, `paused`, `stopping`, `error`)
- the first-pass playback signals (`state_changed`, `position_changed`, `media_loaded`, `playback_finished`, `error_raised`)
- source normalization helpers for the current dictionary contract (`path`, `kind`, `loop`, `autoplay`, `start_time`, `rate`)
- a backend interface boundary so vendor-specific playback can land later without breaking callers
- a deterministic fake backend used by repo-local tests in the hidden `.testbed/` project
- the output-surface attach/detach contract needed by replay and presentation consumers

## 📋 Repository Details

- **Type:** Video playback tool package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Current vendor status:** fake/test backend only in this first slice
- **Future vendor direction:** Godot-native and other playback vendors should slot in behind the repo-owned backend interface rather than redefining the public contract

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

Use this `.testbed/` project as the canonical direct-development and bugfinding surface for contract and backend work.

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
- The current manifest remains intentionally narrow: `aerobeat-tool-core` plus `gut`.
- The fake backend is the official deterministic proving surface for this first slice; real vendor integration is a follow-up.
- Repo-local unit tests should prove the stable contract shell first, then expand as concrete vendor backends are added.
