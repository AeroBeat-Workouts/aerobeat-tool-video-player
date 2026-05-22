# AeroBeat Tool Video Player — Contract Shell Slice

**Date:** 2026-05-21  
**Status:** In Progress  
**Agent:** Cookie 🍪

---

## Goal

Create the first execution-ready repo-local plan for the `aerobeat-tool-video-player` contract-shell slice, then stage the repo-local Beads required for separate coder → QA → auditor lanes.

---

## Overview

This repo is still in fresh template shape. The sharable package surface currently contains only `src/AeroToolManager.gd`, `plugin.cfg`, and template-safe GUT tests under `.testbed/tests/`. The repo already carried a first-pass singleton contract note in `.plans/bootstrap-architecture/VIDEO-PLAYER-API.md`, but it did not yet have a repo-local implementation plan or executable Beads for the first contract-shell slice.

The first slice should stabilize the tool-owned contract without pretending to deliver real vendor playback yet. That means the coder lane should land the singleton shell, state/error/signal vocabulary, config normalization helpers, backend interface boundary, a fake backend for deterministic tests, and an output-surface binding contract. The proving surface remains `.testbed/`; sharable code stays at repo root; `/addons/` is never an editing surface. If dependency hydration becomes necessary during execution, use `/home/derrick/.openclaw/workspace/scripts/godotenv-sync` or the repo’s normal `.testbed` GodotEnv install flow instead of patching mirrored addon payloads.

This plan also records the cross-repo coordination point with `tool-camera-tracking`: replay remains a camera-tracking source mode, but playback lifecycle/time/surface ownership stays here. Later implementation must preserve that separation so `tool-camera-tracking` can consume `tool-video-player` for replay without duplicating generic playback ownership.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Repo bootstrap + `.testbed`/GodotEnv conventions | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/README.md` |
| `REF-02` | First-pass `VideoPlayer` singleton API assumptions | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/.plans/bootstrap-architecture/VIDEO-PLAYER-API.md` |
| `REF-03` | Cross-repo ownership boundaries for camera tracking vs video player | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/.plans/bootstrap-architecture/BOUNDARIES-AND-ASSUMPTIONS.md` |
| `REF-04` | Camera-tracking contract assumptions that depend on replay/video coordination | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/bootstrap-architecture/CAMERA-TRACKING-API.md` |
| `REF-05` | Current template singleton stub to replace/evolve | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/src/AeroToolManager.gd` |
| `REF-06` | Current repo-local tests proving only template behavior | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/.testbed/tests/test_AeroToolManager.gd` |

Use these reference IDs in implementation notes, QA evidence, and audit findings.

---

## Tasks

### Task 1: Implement the `VideoPlayer` contract shell slice

**Bead ID:** `aerobeat-tool-video-player-8m2`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Serve the `coder` workflow role on the `primary` lane for `aerobeat-tool-video-player-8m2`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player`, run `bd update aerobeat-tool-video-player-8m2 --status in_progress --json` when you start. Implement the first `VideoPlayer` contract-shell slice only: singleton class shell, state enum/constants, signals, config/load helpers, backend interface class, fake backend for tests, output surface binding contract, and basic playback state/error contract. Keep sharable code/assets at repo root. Use `.testbed/` as the proving Godot project. Never treat `/addons/` as an editing surface. If dependency sync is needed, note `/home/derrick/.openclaw/workspace/scripts/godotenv-sync`. Preserve the contract split where replay consumers like camera tracking depend on this tool for playback lifecycle/time/surface ownership rather than re-implementing it. Run relevant repo-local validation, capture evidence, add useful bead notes, and hand off for QA without closing downstream beads. Close `aerobeat-tool-video-player-8m2` yourself only if the orchestrator specifically wants coder-owned closure; otherwise leave the bead ready for the planned QA/auditor flow.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/src/AeroToolManager.gd` or renamed/replaced repo-root singleton file(s)
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/src/*.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/.testbed/tests/*.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/plugin.cfg` if naming/entry-point metadata must align with the contract shell

**Status:** ⏳ Pending

**Results:** Planning complete; implementation not started in this lane.

---

### Task 2: QA the `VideoPlayer` contract shell slice

**Bead ID:** `aerobeat-tool-video-player-whx`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-06`  
**Prompt:** Serve the `qa` workflow role on the `primary` lane for `aerobeat-tool-video-player-whx`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player`, run `bd update aerobeat-tool-video-player-whx --status in_progress --json` when you start. This bead is blocked on `aerobeat-tool-video-player-8m2`; once unblocked, independently verify the implemented `VideoPlayer` contract-shell slice against the repo plan and references. Validate that the singleton shell, state/error/signal vocabulary, config/load helpers, backend interface, fake backend, and output surface binding contract all exist and behave as intended for this first slice. Use the highest-fidelity repo-local checks available, centered on `.testbed/`; confirm no edits were made under `/addons/`; confirm sharable code stayed at repo root; note whether dependency sync was needed and how it was handled. Add evidence to the bead and leave explicit pass/fail notes for audit.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player/src/`

**Files Created/Deleted/Modified:**
- Whatever Task 1 changed; QA should cite exact touched files in its evidence.

**Status:** ⏳ Pending

**Results:** Blocked on coder completion.

---

### Task 3: Audit the `VideoPlayer` contract shell slice

**Bead ID:** `aerobeat-tool-video-player-o78`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-06`  
**Prompt:** Serve the `auditor` workflow role on the `primary` lane for `aerobeat-tool-video-player-o78`. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-video-player`, run `bd update aerobeat-tool-video-player-o78 --status in_progress --json` when you start. This bead is blocked on `aerobeat-tool-video-player-whx`; once unblocked, independently truth-check the completed `VideoPlayer` contract-shell slice against this plan, the referenced contract docs, changed files, and coder/QA validation evidence. Confirm the repo conventions were respected: sharable code at repo root, `.testbed/` as proving surface, no `/addons/` editing, and any dependency refresh handled through normal sync paths. Specifically check the camera-tracking coordination boundary: replay-facing hooks may exist, but generic playback lifecycle/time/surface ownership must remain in `tool-video-player`. If the bead passes, close `aerobeat-tool-video-player-o78` yourself with an explicit reason; if not, leave it open with gap notes.

**Folders Created/Deleted/Modified:**
- No new folders expected; auditor verifies final touched paths.

**Files Created/Deleted/Modified:**
- No new files expected unless audit notes/docs are needed.

**Status:** ⏳ Pending

**Results:** Blocked on QA completion.

---

## Dependency Shape

- `aerobeat-tool-video-player-8m2` → first executable bead; unblocked starter for implementation.
- `aerobeat-tool-video-player-whx` depends on `aerobeat-tool-video-player-8m2`.
- `aerobeat-tool-video-player-o78` depends on `aerobeat-tool-video-player-whx`.

This creates a strict repo-local `coder → QA → auditor` chain.

---

## Camera-Tracking Coordination Notes / Blockers

1. **Replay ownership is split, not duplicated.** Per `REF-03` and `REF-04`, replay remains a `tool-camera-tracking` source mode, but playback lifecycle/time/surface ownership belongs to `tool-video-player`. Later execution must not let camera-tracking reintroduce generic play/pause/seek/surface logic.
2. **Surface attachment naming should stay deliberately parallel.** `VideoPlayer.attach_surface(node)` / `detach_surface()` should remain conceptually aligned with `CameraTracking.attach_preview_surface(node)` / `detach_preview_surface()` without collapsing the two contracts into one class or one responsibility domain.
3. **State/error vocabulary should be easy to coordinate later.** The first slice can keep repo-local enums/constants, but the naming and detail payload structure should stay close enough to the camera-tracking plan that later shared conventions remain possible.
4. **Not a hard blocker for this slice:** camera-tracking’s upstream planning lane can proceed in parallel. The current blocker is only conceptual drift: if camera-tracking starts assuming video-specific state names, preview payloads, or direct vendor playback ownership, the two plans will need reconciliation before replay integration.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:**
- Inspected the fresh `aerobeat-tool-video-player` repo state.
- Confirmed the repo is still template-shaped with only the template tool manager and template-safe tests.
- Initialized the repo-local Beads database for executable work.
- Created the first repo-local implementation plan for the `VideoPlayer` contract-shell slice.
- Created the execution beads for coder → QA → auditor with explicit dependencies.

**Reference Check:**
- `REF-01` confirmed repo and `.testbed` conventions.
- `REF-02` supplied the first-pass `VideoPlayer` API contract.
- `REF-03` and `REF-04` supplied the cross-repo ownership boundary with camera tracking.
- `REF-05` and `REF-06` confirmed the current implementation/test starting point.

**Commits:**
- None in this planning lane.

**Lessons Learned:**
- The owning repo had `.beads/` scaffolding but no initialized database yet, so `bd init --quiet` was required before creating repo-local work items.
- The first implementation slice should focus on contract stabilization and deterministic tests, not premature vendor playback integration.

---

*Updated on 2026-05-21*
