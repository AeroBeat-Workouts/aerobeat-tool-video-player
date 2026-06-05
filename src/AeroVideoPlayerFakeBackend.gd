extends "AeroVideoPlayerBackend.gd"

const AeroVideoPlaybackContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")
const FIT_MODE_STRETCH := "stretch"
const FIT_MODE_CONTAIN := "contain"
const FIT_MODE_COVER := "cover"
const FIT_MODES := [FIT_MODE_STRETCH, FIT_MODE_CONTAIN, FIT_MODE_COVER]
const DEFAULT_FIT_MODE := FIT_MODE_COVER
const DEFAULT_NOMINAL_FPS := 30.0

var _state: String = AeroVideoPlaybackContract.STATE_IDLE
var _source: Dictionary = {}
var _media_info: Dictionary = {}
var _position_seconds: float = 0.0
var _duration_seconds: float = 0.0
var _loop_enabled: bool = false
var _rate: float = 1.0
var _fit_mode: String = DEFAULT_FIT_MODE
var _audio_level: float = 1.0
var _surface: Node = null
var _last_error: Dictionary = {}
var _nominal_fps: float = DEFAULT_NOMINAL_FPS
var _frame_duration_sec: float = 1.0 / DEFAULT_NOMINAL_FPS
var _frame_count: int = 0
var _frame_index: int = 0

func load(source: Dictionary) -> Dictionary:
	_state = AeroVideoPlaybackContract.STATE_LOADING
	_source = AeroVideoPlaybackContract.normalize_source(source)
	_fit_mode = _normalize_fit_mode(_source.get("fit_mode", _source.get("cover_mode", DEFAULT_FIT_MODE)))
	_audio_level = _normalize_audio_level(_source.get("audio_level", 1.0))
	_source["fit_mode"] = _fit_mode
	_source["cover_mode"] = _fit_mode
	_source["audio_level"] = _audio_level
	_loop_enabled = bool(_source.get("loop", false))
	_rate = float(_source.get("rate", 1.0))
	_duration_seconds = maxf(0.0, float(_source.get("duration_hint", 60.0)))
	_nominal_fps = maxf(0.001, float(_source.get("nominal_fps", _source.get("fps_hint", DEFAULT_NOMINAL_FPS))))
	_frame_duration_sec = 1.0 / _nominal_fps
	_frame_count = max(0, int(ceili(_duration_seconds * _nominal_fps)))
	_position_seconds = clampf(float(_source.get("start_time", 0.0)), 0.0, _duration_seconds)
	_frame_index = _position_to_frame_index(_position_seconds)
	_media_info = {
		"path": String(_source.get("path", "")),
		"duration": _duration_seconds,
		"has_audio": bool(_source.get("has_audio", true)),
		"width": int(_source.get("width", 1920)),
		"height": int(_source.get("height", 1080)),
		"vendor": String(_source.get("vendor", "fake_backend")),
		"fit_mode": _fit_mode,
		"cover_mode": _fit_mode,
		"audio": get_audio_state(),
		"nominal_fps": _nominal_fps,
		"frame_duration_sec": _frame_duration_sec,
		"frame_count": _frame_count,
	}
	_state = AeroVideoPlaybackContract.STATE_READY
	_last_error = {}
	return AeroVideoPlaybackContract.ok({"state": _state, "media_info": _media_info.duplicate(true)})

func play() -> Dictionary:
	if _source.is_empty():
		return _fail("backend_not_ready", "Cannot play before media has been loaded.")
	_state = AeroVideoPlaybackContract.STATE_PLAYING
	return AeroVideoPlaybackContract.ok({"state": _state})

func pause() -> Dictionary:
	if _state != AeroVideoPlaybackContract.STATE_PLAYING:
		return _fail("backend_not_playing", "Cannot pause when playback is not active.")
	_state = AeroVideoPlaybackContract.STATE_PAUSED
	return AeroVideoPlaybackContract.ok({"state": _state})

func stop() -> Dictionary:
	if _source.is_empty():
		_state = AeroVideoPlaybackContract.STATE_IDLE
		_position_seconds = 0.0
		_frame_index = 0
		return AeroVideoPlaybackContract.ok({"state": _state})
	_state = AeroVideoPlaybackContract.STATE_READY
	_position_seconds = 0.0
	_frame_index = 0
	return AeroVideoPlaybackContract.ok({"state": _state})

func unload() -> Dictionary:
	_source = {}
	_media_info = {}
	_position_seconds = 0.0
	_duration_seconds = 0.0
	_loop_enabled = false
	_rate = 1.0
	_state = AeroVideoPlaybackContract.STATE_IDLE
	_last_error = {}
	_nominal_fps = DEFAULT_NOMINAL_FPS
	_frame_duration_sec = 1.0 / DEFAULT_NOMINAL_FPS
	_frame_count = 0
	_frame_index = 0
	return AeroVideoPlaybackContract.ok({
		"state": _state,
		"surface_attached": _surface != null,
		"media_loaded": false,
	})

func seek(seconds: float) -> Dictionary:
	if _source.is_empty():
		return _fail("backend_not_ready", "Cannot seek before media has been loaded.")
	_position_seconds = clampf(seconds, 0.0, _duration_seconds)
	_frame_index = _position_to_frame_index(_position_seconds)
	return AeroVideoPlaybackContract.ok({"state": _state, "position": _position_seconds, "frame_index": _frame_index})

func set_loop(enabled: bool) -> Dictionary:
	_loop_enabled = enabled
	return AeroVideoPlaybackContract.ok({"loop": _loop_enabled})

func set_rate(rate: float) -> Dictionary:
	if rate <= 0.0:
		return _fail("backend_invalid_rate", "Playback rate must be greater than zero.", {"rate": rate})
	_rate = rate
	return AeroVideoPlaybackContract.ok({"rate": _rate})

func set_fit_mode(fit_mode: String) -> Dictionary:
	_fit_mode = _normalize_fit_mode(fit_mode)
	if not _source.is_empty():
		_source["fit_mode"] = _fit_mode
		_source["cover_mode"] = _fit_mode
	return AeroVideoPlaybackContract.ok({"fit_mode": _fit_mode, "cover_mode": _fit_mode})

func set_cover_mode(cover_mode: String) -> Dictionary:
	return set_fit_mode(cover_mode)

func set_audio_level(audio_level: float) -> Dictionary:
	_audio_level = _normalize_audio_level(audio_level)
	if not _source.is_empty():
		_source["audio_level"] = _audio_level
	return AeroVideoPlaybackContract.ok({"audio": get_audio_state()})

func get_audio_state() -> Dictionary:
	return {
		"muted": is_zero_approx(_audio_level),
		"audio_level": _audio_level,
		"effective_audio_level": _audio_level,
		"player_present": _surface != null,
		"volume": _audio_level,
		"volume_db": _fake_volume_db(_audio_level),
	}

func get_state() -> Dictionary:
	return AeroVideoPlaybackContract.build_state_snapshot({
		"state": _state,
		"position": _position_seconds,
		"duration": _duration_seconds,
		"loop": _loop_enabled,
		"rate": _rate,
		"fit_mode": _fit_mode,
		"cover_mode": _fit_mode,
		"audio_level": _audio_level,
		"audio": get_audio_state(),
		"surface_attached": _surface != null,
		"surface_path": _surface.get_path() if _surface != null and _surface.is_inside_tree() else NodePath(),
		"media_loaded": not _source.is_empty(),
		"source": _source.duplicate(true),
	})

func get_position() -> float:
	return _position_seconds

func get_duration() -> float:
	return _duration_seconds

func get_media_info() -> Dictionary:
	var info := _media_info.duplicate(true)
	info["fit_mode"] = _fit_mode
	info["cover_mode"] = _fit_mode
	info["audio"] = get_audio_state()
	info["nominal_fps"] = _nominal_fps
	info["frame_duration_sec"] = _frame_duration_sec
	info["frame_count"] = _frame_count
	return info

func get_transport_capabilities() -> Dictionary:
	return {
		"transport_mode": TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"can_step_forward": not _source.is_empty(),
		"can_step_backward": not _source.is_empty(),
		"can_seek_frame": not _source.is_empty(),
		"nominal_fps": _nominal_fps,
		"frame_duration_sec": _frame_duration_sec,
		"exactness_note": "Fake backend owns a synthetic frame index timeline and can step it exactly.",
		"limitation_code": "",
	}

func get_transport_status() -> Dictionary:
	var state := get_state()
	var capabilities := get_transport_capabilities()
	return {
		"transport_mode": capabilities.get("transport_mode", TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX),
		"can_step_forward": bool(capabilities.get("can_step_forward", false)),
		"can_step_backward": bool(capabilities.get("can_step_backward", false)),
		"can_seek_frame": bool(capabilities.get("can_seek_frame", false)),
		"frame_index": _frame_index if not _source.is_empty() else null,
		"frame_count": _frame_count if not _source.is_empty() else null,
		"nominal_fps": _nominal_fps if not _source.is_empty() else null,
		"frame_duration_sec": _frame_duration_sec if not _source.is_empty() else null,
		"paused": str(state.get("state", "")) == AeroVideoPlaybackContract.STATE_PAUSED,
		"position_sec": _position_seconds,
		"duration_sec": _duration_seconds,
		"exactness_note": capabilities.get("exactness_note", ""),
		"limitation_code": capabilities.get("limitation_code", ""),
	}

func step_frames(delta_frames: int) -> Dictionary:
	if _source.is_empty():
		return _fail("backend_not_ready", "Cannot step frames before media has been loaded.")
	var target_index := _frame_index + delta_frames
	if _frame_count > 0:
		target_index = clampi(target_index, 0, _frame_count - 1)
	else:
		target_index = max(0, target_index)
	return seek_to_frame(target_index)

func seek_to_frame(frame_index: int) -> Dictionary:
	if _source.is_empty():
		return _fail("backend_not_ready", "Cannot seek to a frame before media has been loaded.")
	if frame_index < 0:
		return _fail("backend_invalid_frame_index", "Frame index must be zero or greater.", {"frame_index": frame_index})
	var max_index := max(0, _frame_count - 1)
	_frame_index = clampi(frame_index, 0, max_index)
	_position_seconds = _frame_index_to_position(_frame_index)
	return AeroVideoPlaybackContract.ok({
		"frame_index": _frame_index,
		"frame_count": _frame_count,
		"position": _position_seconds,
		"state": _state,
		"transport_mode": TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
	})

func attach_surface(node: Node) -> Dictionary:
	if node == null:
		return _fail("backend_invalid_surface", "Cannot attach a null output surface.")
	_surface = node
	return AeroVideoPlaybackContract.ok({"surface_attached": true})

func detach_surface() -> Dictionary:
	_surface = null
	return AeroVideoPlaybackContract.ok({"surface_attached": false})

func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)

func _normalize_fit_mode(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	return normalized if FIT_MODES.has(normalized) else DEFAULT_FIT_MODE

func _normalize_audio_level(value: Variant) -> float:
	return clampf(float(value), 0.0, 1.0)

func _position_to_frame_index(position_sec: float) -> int:
	if _frame_count <= 0:
		return 0
	return clampi(int(round(position_sec * _nominal_fps)), 0, _frame_count - 1)

func _frame_index_to_position(frame_index: int) -> float:
	if frame_index <= 0:
		return 0.0
	var position := float(frame_index) * _frame_duration_sec
	if _duration_seconds > 0.0:
		position = minf(position, _duration_seconds)
	return position

func _fake_volume_db(level: float) -> float:
	if level <= 0.0:
		return -80.0
	return lerpf(-24.0, 0.0, level)

func _fail(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	_state = AeroVideoPlaybackContract.STATE_ERROR
	_last_error = {
		"code": code,
		"message": message,
		"detail": detail.duplicate(true),
	}
	return AeroVideoPlaybackContract.fail(code, message, detail)
