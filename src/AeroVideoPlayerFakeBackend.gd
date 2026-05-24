extends "AeroVideoPlayerBackend.gd"

const AeroVideoPlaybackContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")

var _state: String = AeroVideoPlaybackContract.STATE_IDLE
var _source: Dictionary = {}
var _media_info: Dictionary = {}
var _position_seconds: float = 0.0
var _duration_seconds: float = 0.0
var _loop_enabled: bool = false
var _rate: float = 1.0
var _surface: Node = null
var _last_error: Dictionary = {}

func load(source: Dictionary) -> Dictionary:
	_state = AeroVideoPlaybackContract.STATE_LOADING
	_source = AeroVideoPlaybackContract.normalize_source(source)
	_loop_enabled = bool(_source.get("loop", false))
	_rate = float(_source.get("rate", 1.0))
	_duration_seconds = maxf(0.0, float(_source.get("duration_hint", 60.0)))
	_position_seconds = clampf(float(_source.get("start_time", 0.0)), 0.0, _duration_seconds)
	_media_info = {
		"path": String(_source.get("path", "")),
		"duration": _duration_seconds,
		"has_audio": bool(_source.get("has_audio", true)),
		"width": int(_source.get("width", 1920)),
		"height": int(_source.get("height", 1080)),
		"vendor": String(_source.get("vendor", "fake_backend")),
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
		return AeroVideoPlaybackContract.ok({"state": _state})
	_state = AeroVideoPlaybackContract.STATE_READY
	_position_seconds = 0.0
	return AeroVideoPlaybackContract.ok({"state": _state})

func seek(seconds: float) -> Dictionary:
	if _source.is_empty():
		return _fail("backend_not_ready", "Cannot seek before media has been loaded.")
	_position_seconds = clampf(seconds, 0.0, _duration_seconds)
	return AeroVideoPlaybackContract.ok({"state": _state, "position": _position_seconds})

func set_loop(enabled: bool) -> Dictionary:
	_loop_enabled = enabled
	return AeroVideoPlaybackContract.ok({"loop": _loop_enabled})

func set_rate(rate: float) -> Dictionary:
	if rate <= 0.0:
		return _fail("backend_invalid_rate", "Playback rate must be greater than zero.", {"rate": rate})
	_rate = rate
	return AeroVideoPlaybackContract.ok({"rate": _rate})

func get_state() -> Dictionary:
	return AeroVideoPlaybackContract.build_state_snapshot({
		"state": _state,
		"position": _position_seconds,
		"duration": _duration_seconds,
		"loop": _loop_enabled,
		"rate": _rate,
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
	return _media_info.duplicate(true)

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

func _fail(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	_state = AeroVideoPlaybackContract.STATE_ERROR
	_last_error = {
		"code": code,
		"message": message,
		"detail": detail.duplicate(true),
	}
	return AeroVideoPlaybackContract.fail(code, message, detail)
