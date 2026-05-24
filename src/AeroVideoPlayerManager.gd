## Public runtime entrypoint for the AeroBeat tool-video-player package.
##
## The stable tool-facing playback facade lives here as AeroVideoPlayerManager.
## Shared playback vocabulary comes from aerobeat-tool-core while concrete
## vendor playback remains behind an injectable backend boundary.
class_name AeroVideoPlayerManager
extends Node

const AeroVideoPlaybackContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")
const BackendInterfaceScript := preload("AeroVideoPlayerBackend.gd")
const FakeBackendScript := preload("AeroVideoPlayerFakeBackend.gd")

#region SIGNALS
signal initialized
signal state_changed(state: String, detail: Dictionary)
signal position_changed(seconds: float, normalized: float)
signal media_loaded(info: Dictionary)
signal playback_finished
signal error_raised(error_info: Dictionary)
#endregion

#region ENUMS & CONSTANTS
enum PlaybackState {
	IDLE,
	LOADING,
	READY,
	PLAYING,
	PAUSED,
	STOPPING,
	ERROR,
}

const VERSION: String = "0.2.0"
const STATE_IDLE := AeroVideoPlaybackContract.STATE_IDLE
const STATE_LOADING := AeroVideoPlaybackContract.STATE_LOADING
const STATE_READY := AeroVideoPlaybackContract.STATE_READY
const STATE_PLAYING := AeroVideoPlaybackContract.STATE_PLAYING
const STATE_PAUSED := AeroVideoPlaybackContract.STATE_PAUSED
const STATE_STOPPING := AeroVideoPlaybackContract.STATE_STOPPING
const STATE_ERROR := AeroVideoPlaybackContract.STATE_ERROR
const STATE_NAMES := {
	PlaybackState.IDLE: STATE_IDLE,
	PlaybackState.LOADING: STATE_LOADING,
	PlaybackState.READY: STATE_READY,
	PlaybackState.PLAYING: STATE_PLAYING,
	PlaybackState.PAUSED: STATE_PAUSED,
	PlaybackState.STOPPING: STATE_STOPPING,
	PlaybackState.ERROR: STATE_ERROR,
}

const SOURCE_KIND_FILE := AeroVideoPlaybackContract.SOURCE_KIND_FILE
const SOURCE_KIND_URL := AeroVideoPlaybackContract.SOURCE_KIND_URL
const SOURCE_KIND_STREAM := AeroVideoPlaybackContract.SOURCE_KIND_STREAM
const SOURCE_KIND_PACKAGE := AeroVideoPlaybackContract.SOURCE_KIND_PACKAGE
const SOURCE_KINDS := AeroVideoPlaybackContract.SOURCE_KINDS

const ERROR_INVALID_SOURCE := AeroVideoPlaybackContract.ERROR_INVALID_SOURCE
const ERROR_INVALID_SURFACE := AeroVideoPlaybackContract.ERROR_INVALID_SURFACE
const ERROR_BACKEND_REJECTED := AeroVideoPlaybackContract.ERROR_BACKEND_REJECTED
const ERROR_NOT_READY := AeroVideoPlaybackContract.ERROR_NOT_READY
#endregion

#region EXPORTS
@export var is_active: bool = true
#endregion

#region PRIVATE VARIABLES
var _is_initialized: bool = false
var _backend: AeroVideoPlayerBackend
var _backend_name: String = ""
var _state_name: String = STATE_IDLE
var _state_code: int = PlaybackState.IDLE
var _loaded_source: Dictionary = {}
var _media_info: Dictionary = {}
var _last_error: Dictionary = {}
var _surface: Node = null
#endregion

#region LIFECYCLE
func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized:
		return
	if _backend == null:
		set_backend(FakeBackendScript.new())
	_is_initialized = true
	initialized.emit()
#endregion

#region PUBLIC API
func set_backend(backend: AeroVideoPlayerBackend) -> void:
	if backend == null:
		backend = FakeBackendScript.new()
	_backend = backend
	_backend_name = backend.get_script().resource_path.get_file().trim_suffix(".gd") if backend.get_script() != null else "custom_backend"
	if _surface != null and _backend.has_method("attach_surface"):
		_backend.attach_surface(_surface)

func get_backend() -> AeroVideoPlayerBackend:
	_initialize()
	return _backend

func create_default_backend() -> AeroVideoPlayerBackend:
	return FakeBackendScript.new()

func get_default_source_config() -> Dictionary:
	return AeroVideoPlaybackContract.get_default_source_config()

func normalize_source(source: Dictionary) -> Dictionary:
	return AeroVideoPlaybackContract.normalize_source(source)

func can_load_source(source: Dictionary) -> bool:
	return _validate_source(normalize_source(source)).is_empty()

func load(source: Dictionary) -> void:
	_initialize()
	if not is_active:
		_raise_error(ERROR_NOT_READY, "AeroVideoPlayerManager is inactive.", {"source": source.duplicate(true)}, true)
		return
	var normalized := normalize_source(source)
	var validation_error := _validate_source(normalized)
	if not validation_error.is_empty():
		_raise_error(ERROR_INVALID_SOURCE, validation_error.get("message", "Invalid video source."), validation_error, true)
		return
	_transition_state(PlaybackState.LOADING, {"source": normalized.duplicate(true)})
	_apply_result(_backend.load(normalized), ERROR_BACKEND_REJECTED, "Backend failed to load media.")
	if _state_name == STATE_ERROR:
		return
	_loaded_source = normalized.duplicate(true)
	_media_info = _backend.get_media_info()
	_apply_result(_backend.set_loop(bool(_loaded_source.get("loop", false))), ERROR_BACKEND_REJECTED, "Backend rejected loop config.")
	if _state_name == STATE_ERROR:
		return
	_apply_result(_backend.set_rate(float(_loaded_source.get("rate", 1.0))), ERROR_BACKEND_REJECTED, "Backend rejected playback rate.")
	if _state_name == STATE_ERROR:
		return
	if _surface != null:
		_apply_result(_backend.attach_surface(_surface), ERROR_INVALID_SURFACE, "Backend rejected the output surface.")
		if _state_name == STATE_ERROR:
			return
	_transition_state(PlaybackState.READY, {
		"source": _loaded_source.duplicate(true),
		"media_info": _media_info.duplicate(true),
	})
	media_loaded.emit(_media_info.duplicate(true))
	if float(_loaded_source.get("start_time", 0.0)) > 0.0:
		seek(float(_loaded_source.get("start_time", 0.0)))
	if bool(_loaded_source.get("autoplay", false)):
		play()
	else:
		_emit_position_changed(_backend.get_position(), _backend.get_duration())

func play() -> void:
	_initialize()
	if not _ensure_loaded("Cannot play before media has been loaded."):
		return
	if _state_name == STATE_PLAYING:
		return
	_apply_result(_backend.play(), ERROR_BACKEND_REJECTED, "Backend failed to start playback.")
	if _state_name == STATE_ERROR:
		return
	_transition_state(PlaybackState.PLAYING, {"source": _loaded_source.duplicate(true)})

func pause() -> void:
	_initialize()
	if not _ensure_loaded("Cannot pause before media has been loaded."):
		return
	_apply_result(_backend.pause(), ERROR_BACKEND_REJECTED, "Backend failed to pause playback.")
	if _state_name == STATE_ERROR:
		return
	_transition_state(PlaybackState.PAUSED, {"source": _loaded_source.duplicate(true)})

func stop() -> void:
	_initialize()
	if not _ensure_loaded("Cannot stop before media has been loaded."):
		return
	_transition_state(PlaybackState.STOPPING, {"source": _loaded_source.duplicate(true)})
	_apply_result(_backend.stop(), ERROR_BACKEND_REJECTED, "Backend failed to stop playback.")
	if _state_name == STATE_ERROR:
		return
	_transition_state(PlaybackState.READY, {"source": _loaded_source.duplicate(true)})
	_emit_position_changed(_backend.get_position(), _backend.get_duration())

func seek(seconds: float) -> void:
	_initialize()
	if not _ensure_loaded("Cannot seek before media has been loaded."):
		return
	_apply_result(_backend.seek(seconds), ERROR_BACKEND_REJECTED, "Backend failed to seek playback.")
	if _state_name == STATE_ERROR:
		return
	_emit_position_changed(_backend.get_position(), _backend.get_duration())
	if _backend.get_duration() > 0.0 and _backend.get_position() >= _backend.get_duration() and not bool(_loaded_source.get("loop", false)):
		playback_finished.emit()

func set_loop(enabled: bool) -> void:
	_initialize()
	if _loaded_source.is_empty():
		_loaded_source = get_default_source_config()
	_loaded_source["loop"] = enabled
	_apply_result(_backend.set_loop(enabled), ERROR_BACKEND_REJECTED, "Backend failed to update loop mode.")

func set_rate(rate: float) -> void:
	_initialize()
	if _loaded_source.is_empty():
		_loaded_source = get_default_source_config()
	_loaded_source["rate"] = rate
	_apply_result(_backend.set_rate(rate), ERROR_BACKEND_REJECTED, "Backend failed to update playback rate.")

func get_state() -> Dictionary:
	_initialize()
	var backend_state: Dictionary = _backend.get_state() if _backend != null else {}
	return AeroVideoPlaybackContract.build_state_snapshot({
		"state": _state_name,
		"state_code": _state_code,
		"source": _loaded_source.duplicate(true),
		"media_info": _media_info.duplicate(true),
		"position": float(backend_state.get("position", 0.0)),
		"duration": float(backend_state.get("duration", 0.0)),
		"loop": bool(backend_state.get("loop", _loaded_source.get("loop", false))),
		"rate": float(backend_state.get("rate", _loaded_source.get("rate", 1.0))),
		"surface_attached": bool(backend_state.get("surface_attached", _surface != null)),
		"backend": _backend_name,
		"last_error": _last_error.duplicate(true),
	})

func get_duration() -> float:
	_initialize()
	return _backend.get_duration() if _backend != null else 0.0

func get_position() -> float:
	_initialize()
	return _backend.get_position() if _backend != null else 0.0

func get_media_info() -> Dictionary:
	_initialize()
	return _media_info.duplicate(true)

func attach_surface(node: Node) -> void:
	_initialize()
	if node == null:
		_raise_error(ERROR_INVALID_SURFACE, "Cannot attach a null output surface.", {}, true)
		return
	_surface = node
	_apply_result(_backend.attach_surface(node), ERROR_INVALID_SURFACE, "Backend rejected the output surface.")
	if _state_name == STATE_ERROR:
		return
	var detail := get_state()
	detail["surface_path"] = str(node.get_path()) if node.is_inside_tree() else node.name
	state_changed.emit(_state_name, detail)

func detach_surface() -> void:
	_initialize()
	_surface = null
	_apply_result(_backend.detach_surface(), ERROR_INVALID_SURFACE, "Backend failed to detach the output surface.")
	if _state_name == STATE_ERROR:
		return
	var detail := get_state()
	detail["surface_path"] = ""
	state_changed.emit(_state_name, detail)

func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)
#endregion

#region PRIVATE HELPERS
func _validate_source(source: Dictionary) -> Dictionary:
	return AeroVideoPlaybackContract.validate_source(source)

func _ensure_loaded(message: String) -> bool:
	if _loaded_source.is_empty():
		_raise_error(ERROR_NOT_READY, message, {}, true)
		return false
	return true

func _transition_state(state_code: int, detail: Dictionary = {}) -> void:
	_state_code = state_code
	_state_name = STATE_NAMES.get(state_code, STATE_IDLE)
	var payload := detail.duplicate(true)
	payload["state"] = _state_name
	state_changed.emit(_state_name, payload)

func _emit_position_changed(seconds: float, duration: float) -> void:
	var normalized := 0.0
	if duration > 0.0:
		normalized = clampf(seconds / duration, 0.0, 1.0)
	position_changed.emit(seconds, normalized)

func _apply_result(result: Dictionary, fallback_code: String, fallback_message: String) -> void:
	if bool(result.get(AeroVideoPlaybackContract.RESULT_SUCCESS, false)):
		_last_error = {}
		return
	_raise_error(
		String(result.get(AeroVideoPlaybackContract.RESULT_CODE, fallback_code)),
		String(result.get(AeroVideoPlaybackContract.RESULT_MESSAGE, fallback_message)),
		result.get(AeroVideoPlaybackContract.RESULT_DETAIL, {}),
		true
	)

func _raise_error(code: String, message: String, detail: Variant = {}, transition_to_error: bool = true) -> void:
	var safe_detail: Dictionary = detail if typeof(detail) == TYPE_DICTIONARY else {"value": detail}
	_last_error = {
		"code": code,
		"message": message,
		"detail": safe_detail.duplicate(true),
		"state": _state_name,
	}
	if transition_to_error:
		_transition_state(PlaybackState.ERROR, _last_error.duplicate(true))
	error_raised.emit(_last_error.duplicate(true))
#endregion
