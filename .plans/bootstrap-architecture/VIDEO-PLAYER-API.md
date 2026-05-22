# First-Pass `VideoPlayer` Singleton API

## Purpose

A reusable video playback service for replay, environments/workout packages, and coaching video flows, with vendor-specific playback hidden behind a stable tool-layer contract.

## State machine

Standardize these top-level states now:
- `idle`
- `loading`
- `ready`
- `playing`
- `paused`
- `stopping`
- `error`

## Core methods

- `load(source: Dictionary) -> void`
- `play() -> void`
- `pause() -> void`
- `stop() -> void`
- `seek(seconds: float) -> void`
- `set_loop(enabled: bool) -> void`
- `set_rate(rate: float) -> void`
- `get_state() -> Dictionary`
- `get_duration() -> float`
- `get_position() -> float`
- `get_media_info() -> Dictionary`
- `attach_surface(node: Node) -> void`
- `detach_surface() -> void`
- `get_last_error() -> Dictionary`

## Signals

- `state_changed(state: String, detail: Dictionary)`
- `position_changed(seconds: float, normalized: float)`
- `media_loaded(info: Dictionary)`
- `playback_finished()`
- `error_raised(error_info: Dictionary)`

## Source/config assumptions

```gdscript
{
  "path": "res://videos/example.ogv",
  "kind": "file",
  "loop": false,
  "autoplay": false,
  "start_time": 0.0,
  "rate": 1.0
}
```

Potential later expansion:
- remote URL
- stream source
- packaged workout media descriptor

## Media info contract assumptions

```gdscript
{
  "path": "res://videos/example.ogv",
  "duration": 120.0,
  "has_audio": true,
  "width": 1920,
  "height": 1080,
  "vendor": "godot_video"
}
```

## Vendor abstraction assumptions

The initial vendor will likely just be Godot-native playback, but the tool layer should still own the stable contract.

Possible backend interface shape:
- `VideoPlayerBackend.load(source)`
- `VideoPlayerBackend.play()`
- `VideoPlayerBackend.pause()`
- `VideoPlayerBackend.stop()`
- `VideoPlayerBackend.seek(seconds)`
- `VideoPlayerBackend.set_loop(enabled)`
- `VideoPlayerBackend.set_rate(rate)`
- `VideoPlayerBackend.get_state()`
- `VideoPlayerBackend.get_position()`
- `VideoPlayerBackend.get_duration()`
- `VideoPlayerBackend.attach_surface(node)`

## Relationship to camera tracking

Assumed model:
- `tool-video-player` owns generic playback lifecycle and presentation.
- `tool-camera-tracking` can consume `tool-video-player` as a replay source rather than re-implementing video controls.
- Tracking repos should not become generic video-player owners.

## Open questions

1. Should `tool-video-player` support frame-step and scrub callbacks in the first version, or only basic seek/play/pause?
2. Should environment/workout packages point directly at `tool-video-player`, or through an environment-level media abstraction later?
3. Do we want output-surface attach/detach symmetry to match `CameraTracking` exactly for consistency?
4. Is `.ogv` the only explicitly supported first target, with other formats labeled unverified, or should the contract stay format-agnostic from day one?
