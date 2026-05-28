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
signal slot_state_changed(slot_name: String, state: String, detail: Dictionary)
signal slot_position_changed(slot_name: String, seconds: float, normalized: float)
signal slot_media_loaded(slot_name: String, info: Dictionary)
signal slot_playback_finished(slot_name: String)
signal slot_error_raised(slot_name: String, error_info: Dictionary)
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

const VERSION: String = "0.5.0"
const DEFAULT_SLOT := "primary"
const COVER_MODE_STRETCH := "stretch"
const COVER_MODE_CONTAIN := "contain"
const COVER_MODE_COVER := "cover"
const COVER_MODES := [COVER_MODE_STRETCH, COVER_MODE_CONTAIN, COVER_MODE_COVER]
const DEFAULT_COVER_MODE := COVER_MODE_CONTAIN
const DEFAULT_AUDIO_LEVEL := 1.0
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
var _backend_factory: Callable = Callable()
var _active_slot: String = DEFAULT_SLOT
var _slots: Dictionary = {}
#endregion

#region LIFECYCLE
func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized:
		return
	_ensure_slot(DEFAULT_SLOT)
	_is_initialized = true
	initialized.emit()
#endregion

#region PUBLIC API
func set_backend(backend: AeroVideoPlayerBackend, slot_name: String = DEFAULT_SLOT) -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	if backend == null:
		backend = create_default_backend()
	var session := _ensure_slot(resolved_slot)
	session["backend"] = backend
	session["backend_name"] = _resolve_backend_name(backend)
	_slots[resolved_slot] = session
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	var surface: Node = session.get("surface", null)
	if backend.has_method("set_cover_mode"):
		backend.set_cover_mode(str(source.get("cover_mode", DEFAULT_COVER_MODE)))
	if backend.has_method("set_audio_level"):
		backend.set_audio_level(float(source.get("audio_level", DEFAULT_AUDIO_LEVEL)))
	if surface != null and backend.has_method("attach_surface"):
		backend.attach_surface(surface)

func set_backend_factory(factory: Callable) -> void:
	_backend_factory = factory

func get_backend(slot_name: String = DEFAULT_SLOT) -> AeroVideoPlayerBackend:
	_initialize()
	var session := _ensure_slot(slot_name)
	return session.get("backend", null)

func create_default_backend() -> AeroVideoPlayerBackend:
	if _backend_factory.is_valid():
		var created: Variant = _backend_factory.call()
		if created is AeroVideoPlayerBackend:
			return created
	return FakeBackendScript.new()

func get_default_source_config() -> Dictionary:
	var config := AeroVideoPlaybackContract.get_default_source_config()
	config["slot"] = DEFAULT_SLOT
	config["cover_mode"] = DEFAULT_COVER_MODE
	config["audio_level"] = DEFAULT_AUDIO_LEVEL
	return config

func normalize_source(source: Dictionary) -> Dictionary:
	var normalized := AeroVideoPlaybackContract.normalize_source(source)
	var normalized_path := str(normalized.get("path", "")).strip_edges()
	var normalized_kind := str(normalized.get("kind", SOURCE_KIND_FILE)).strip_edges().to_lower()
	var inferred_kind := _infer_source_kind(normalized_path)
	if inferred_kind == SOURCE_KIND_URL:
		normalized_kind = SOURCE_KIND_URL
	normalized["path"] = normalized_path
	normalized["kind"] = normalized_kind
	normalized["slot"] = _resolve_slot_from_source(source)
	normalized["cover_mode"] = _normalize_cover_mode(source.get("cover_mode", normalized.get("cover_mode", DEFAULT_COVER_MODE)))
	normalized["audio_level"] = _normalize_audio_level(source.get("audio_level", normalized.get("audio_level", DEFAULT_AUDIO_LEVEL)))
	return normalized

func can_load_source(source: Dictionary) -> bool:
	return _validate_source(normalize_source(source)).is_empty()

func set_active_slot(slot_name: String) -> Dictionary:
	_initialize()
	_active_slot = _normalize_slot_name(slot_name)
	_ensure_slot(_active_slot)
	return {"slot": _active_slot}

func get_active_slot() -> String:
	_initialize()
	return _active_slot

func get_slot_names() -> PackedStringArray:
	_initialize()
	var slot_names: Array[String] = []
	for slot_name in _slots.keys():
		slot_names.append(str(slot_name))
	slot_names.sort()
	return PackedStringArray(slot_names)

func attach_slot_surface(slot_name: String, node: Node) -> void:
	attach_surface(node, slot_name)

func detach_slot_surface(slot_name: String = "") -> void:
	detach_surface(slot_name)

func load(source: Dictionary, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name, source)
	if not is_active:
		_raise_error_for_slot(resolved_slot, ERROR_NOT_READY, "AeroVideoPlayerManager is inactive.", {"source": source.duplicate(true)}, true)
		return
	var session := _ensure_slot(resolved_slot)
	var normalized := normalize_source(_prepare_source_for_slot(source, resolved_slot))
	var validation_error := _validate_source(normalized)
	if not validation_error.is_empty():
		_raise_error_for_slot(resolved_slot, ERROR_INVALID_SOURCE, validation_error.get("message", "Invalid video source."), validation_error, true)
		return
	_transition_state_for_slot(resolved_slot, PlaybackState.LOADING, {"source": normalized.duplicate(true)})
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.load(normalized), ERROR_BACKEND_REJECTED, "Backend failed to load media.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	session["loaded_source"] = normalized.duplicate(true)
	session["media_info"] = backend.get_media_info()
	session["has_loaded_media"] = true
	session["last_error"] = {}
	_slots[resolved_slot] = session
	_apply_result_for_slot(resolved_slot, backend.set_loop(bool(normalized.get("loop", false))), ERROR_BACKEND_REJECTED, "Backend rejected loop config.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_apply_result_for_slot(resolved_slot, backend.set_rate(float(normalized.get("rate", 1.0))), ERROR_BACKEND_REJECTED, "Backend rejected playback rate.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	if backend.has_method("set_cover_mode"):
		_apply_result_for_slot(resolved_slot, backend.set_cover_mode(str(normalized.get("cover_mode", DEFAULT_COVER_MODE))), ERROR_BACKEND_REJECTED, "Backend rejected cover mode.")
		if _slot_state_name(resolved_slot) == STATE_ERROR:
			return
	if backend.has_method("set_audio_level"):
		_apply_result_for_slot(resolved_slot, backend.set_audio_level(float(normalized.get("audio_level", DEFAULT_AUDIO_LEVEL))), ERROR_BACKEND_REJECTED, "Backend rejected audio level.")
		if _slot_state_name(resolved_slot) == STATE_ERROR:
			return
	var surface: Node = session.get("surface", null)
	if surface != null:
		_apply_result_for_slot(resolved_slot, backend.attach_surface(surface), ERROR_INVALID_SURFACE, "Backend rejected the output surface.")
		if _slot_state_name(resolved_slot) == STATE_ERROR:
			return
	session = _ensure_slot(resolved_slot)
	session["media_info"] = backend.get_media_info()
	_slots[resolved_slot] = session
	_transition_state_for_slot(resolved_slot, PlaybackState.READY, {
		"source": session.get("loaded_source", {}).duplicate(true),
		"media_info": session.get("media_info", {}).duplicate(true),
	})
	var loaded_info: Dictionary = session.get("media_info", {}).duplicate(true)
	loaded_info["slot"] = resolved_slot
	if resolved_slot == _active_slot:
		media_loaded.emit(loaded_info.duplicate(true))
	slot_media_loaded.emit(resolved_slot, loaded_info.duplicate(true))
	if float(normalized.get("start_time", 0.0)) > 0.0:
		seek(float(normalized.get("start_time", 0.0)), resolved_slot)
	else:
		_emit_position_changed_for_slot(resolved_slot, backend.get_position(), backend.get_duration())
	if bool(normalized.get("autoplay", false)):
		play(resolved_slot)

func play(slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	if not _ensure_loaded_for_slot(resolved_slot, "Cannot play before media has been loaded."):
		return
	if _slot_state_name(resolved_slot) == STATE_PLAYING:
		return
	var session := _ensure_slot(resolved_slot)
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.play(), ERROR_BACKEND_REJECTED, "Backend failed to start playback.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_transition_state_for_slot(resolved_slot, PlaybackState.PLAYING, {"source": session.get("loaded_source", {}).duplicate(true)})

func pause(slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	if not _ensure_loaded_for_slot(resolved_slot, "Cannot pause before media has been loaded."):
		return
	var session := _ensure_slot(resolved_slot)
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.pause(), ERROR_BACKEND_REJECTED, "Backend failed to pause playback.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_transition_state_for_slot(resolved_slot, PlaybackState.PAUSED, {"source": session.get("loaded_source", {}).duplicate(true)})
	_emit_position_changed_for_slot(resolved_slot, backend.get_position(), backend.get_duration())

func stop(slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	if not _ensure_loaded_for_slot(resolved_slot, "Cannot stop before media has been loaded."):
		return
	var session := _ensure_slot(resolved_slot)
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_transition_state_for_slot(resolved_slot, PlaybackState.STOPPING, {"source": session.get("loaded_source", {}).duplicate(true)})
	_apply_result_for_slot(resolved_slot, backend.stop(), ERROR_BACKEND_REJECTED, "Backend failed to stop playback.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_transition_state_for_slot(resolved_slot, PlaybackState.READY, {"source": session.get("loaded_source", {}).duplicate(true)})
	_emit_position_changed_for_slot(resolved_slot, backend.get_position(), backend.get_duration())

func reset(slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	var had_loaded_media := bool(session.get("has_loaded_media", false))
	session["last_error"] = {}
	_slots[resolved_slot] = session
	if had_loaded_media:
		var backend: AeroVideoPlayerBackend = session.get("backend", null)
		_lifecycle_apply_result_for_slot(resolved_slot, backend.stop(), ERROR_BACKEND_REJECTED, "Backend failed to stop playback during reset.")
		_lifecycle_apply_result_for_slot(resolved_slot, backend.seek(0.0), ERROR_BACKEND_REJECTED, "Backend failed to seek playback during reset.")
		session = _ensure_slot(resolved_slot)
		session["last_error"] = {}
		_slots[resolved_slot] = session
		_transition_state_for_slot(resolved_slot, PlaybackState.READY, {
			"source": session.get("loaded_source", {}).duplicate(true),
			"media_info": session.get("media_info", {}).duplicate(true),
		})
		_emit_position_changed_for_slot(resolved_slot, get_position(resolved_slot), get_duration(resolved_slot))
		return
	_transition_state_for_slot(resolved_slot, PlaybackState.IDLE)

func unload(slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	if bool(session.get("has_loaded_media", false)):
		_lifecycle_apply_result_for_slot(resolved_slot, backend.unload(), ERROR_BACKEND_REJECTED, "Backend failed to unload media.")
	session["loaded_source"] = {}
	session["media_info"] = {}
	session["last_error"] = {}
	session["has_loaded_media"] = false
	_slots[resolved_slot] = session
	_transition_state_for_slot(resolved_slot, PlaybackState.IDLE)
	_emit_position_changed_for_slot(resolved_slot, 0.0, 0.0)

func seek(seconds: float, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	if not _ensure_loaded_for_slot(resolved_slot, "Cannot seek before media has been loaded."):
		return
	var session := _ensure_slot(resolved_slot)
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.seek(seconds), ERROR_BACKEND_REJECTED, "Backend failed to seek playback.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_emit_position_changed_for_slot(resolved_slot, backend.get_position(), backend.get_duration())
	if backend.get_duration() > 0.0 and backend.get_position() >= backend.get_duration() and not bool(get_state(resolved_slot).get("loop", false)):
		_emit_playback_finished_for_slot(resolved_slot)

func set_loop(enabled: bool, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	source["loop"] = enabled
	session["loaded_source"] = source
	_slots[resolved_slot] = session
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.set_loop(enabled), ERROR_BACKEND_REJECTED, "Backend failed to update loop mode.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_state_changed_for_slot(resolved_slot, get_state(resolved_slot))

func set_rate(rate: float, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	source["rate"] = rate
	session["loaded_source"] = source
	_slots[resolved_slot] = session
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.set_rate(rate), ERROR_BACKEND_REJECTED, "Backend failed to update playback rate.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	_state_changed_for_slot(resolved_slot, get_state(resolved_slot))

func set_cover_mode(cover_mode: String, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var normalized_cover_mode := _normalize_cover_mode(cover_mode)
	var session := _ensure_slot(resolved_slot)
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	source["cover_mode"] = normalized_cover_mode
	session["loaded_source"] = source
	_slots[resolved_slot] = session
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.set_cover_mode(normalized_cover_mode), ERROR_BACKEND_REJECTED, "Backend failed to update cover mode.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	session = _ensure_slot(resolved_slot)
	session["media_info"] = backend.get_media_info()
	_slots[resolved_slot] = session
	_state_changed_for_slot(resolved_slot, get_state(resolved_slot))

func set_audio_level(audio_level: float, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var normalized_audio_level := _normalize_audio_level(audio_level)
	var session := _ensure_slot(resolved_slot)
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	source["audio_level"] = normalized_audio_level
	session["loaded_source"] = source
	_slots[resolved_slot] = session
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.set_audio_level(normalized_audio_level), ERROR_BACKEND_REJECTED, "Backend failed to update audio level.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	session = _ensure_slot(resolved_slot)
	session["media_info"] = backend.get_media_info()
	_slots[resolved_slot] = session
	_state_changed_for_slot(resolved_slot, get_state(resolved_slot))

func get_state(slot_name: String = "") -> Dictionary:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	var backend_state: Dictionary = backend.get_state() if backend != null else {}
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	var media_info: Dictionary = session.get("media_info", {}).duplicate(true)
	if media_info.is_empty() and backend != null:
		media_info = backend.get_media_info()
	return AeroVideoPlaybackContract.build_state_snapshot({
		"slot": resolved_slot,
		"active_slot": _active_slot,
		"slot_names": get_slot_names(),
		"state": _slot_state_name(resolved_slot),
		"state_code": int(session.get("state_code", PlaybackState.IDLE)),
		"source": source,
		"media_info": media_info,
		"position": get_position(resolved_slot),
		"duration": get_duration(resolved_slot),
		"loop": bool(backend_state.get("loop", source.get("loop", false))),
		"rate": float(backend_state.get("rate", source.get("rate", 1.0))),
		"cover_mode": str(backend_state.get("cover_mode", source.get("cover_mode", DEFAULT_COVER_MODE))),
		"audio_level": float(backend_state.get("audio_level", source.get("audio_level", DEFAULT_AUDIO_LEVEL))),
		"audio": backend_state.get("audio", media_info.get("audio", {})),
		"surface_attached": bool(backend_state.get("surface_attached", session.get("surface", null) != null)),
		"backend": str(session.get("backend_name", "")),
		"last_error": session.get("last_error", {}).duplicate(true),
		"media_loaded": bool(session.get("has_loaded_media", false)),
	})

func get_slot_state(slot_name: String) -> Dictionary:
	return get_state(slot_name)

func get_duration(slot_name: String = "") -> float:
	_initialize()
	var session := _ensure_slot(_resolve_slot_name(slot_name))
	if not bool(session.get("has_loaded_media", false)):
		return 0.0
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	return backend.get_duration() if backend != null else 0.0

func get_position(slot_name: String = "") -> float:
	_initialize()
	var session := _ensure_slot(_resolve_slot_name(slot_name))
	if not bool(session.get("has_loaded_media", false)):
		return 0.0
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	return backend.get_position() if backend != null else 0.0

func get_media_info(slot_name: String = "") -> Dictionary:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	var info: Dictionary = session.get("media_info", {}).duplicate(true)
	if info.is_empty():
		info = {
			"cover_mode": str(_ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot).get("cover_mode", DEFAULT_COVER_MODE)),
			"audio": {"audio_level": float(_ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot).get("audio_level", DEFAULT_AUDIO_LEVEL))},
		}
	info["slot"] = resolved_slot
	return info

func attach_surface(node: Node, slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	if node == null:
		_raise_error_for_slot(resolved_slot, ERROR_INVALID_SURFACE, "Cannot attach a null output surface.", {}, true)
		return
	var session := _ensure_slot(resolved_slot)
	session["surface"] = node
	_slots[resolved_slot] = session
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.attach_surface(node), ERROR_INVALID_SURFACE, "Backend rejected the output surface.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	var source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), resolved_slot)
	if backend.has_method("set_cover_mode"):
		_apply_result_for_slot(resolved_slot, backend.set_cover_mode(str(source.get("cover_mode", DEFAULT_COVER_MODE))), ERROR_BACKEND_REJECTED, "Backend rejected the cover mode for the output surface.")
		if _slot_state_name(resolved_slot) == STATE_ERROR:
			return
	if backend.has_method("set_audio_level"):
		_apply_result_for_slot(resolved_slot, backend.set_audio_level(float(source.get("audio_level", DEFAULT_AUDIO_LEVEL))), ERROR_BACKEND_REJECTED, "Backend rejected the audio level for the output surface.")
		if _slot_state_name(resolved_slot) == STATE_ERROR:
			return
	session = _ensure_slot(resolved_slot)
	session["media_info"] = backend.get_media_info()
	_slots[resolved_slot] = session
	var detail := get_state(resolved_slot)
	detail["surface_path"] = str(node.get_path()) if node.is_inside_tree() else node.name
	_state_changed_for_slot(resolved_slot, detail)

func detach_surface(slot_name: String = "") -> void:
	_initialize()
	var resolved_slot := _resolve_slot_name(slot_name)
	var session := _ensure_slot(resolved_slot)
	session["surface"] = null
	_slots[resolved_slot] = session
	var backend: AeroVideoPlayerBackend = session.get("backend", null)
	_apply_result_for_slot(resolved_slot, backend.detach_surface(), ERROR_INVALID_SURFACE, "Backend failed to detach the output surface.")
	if _slot_state_name(resolved_slot) == STATE_ERROR:
		return
	var detail := get_state(resolved_slot)
	detail["surface_path"] = ""
	_state_changed_for_slot(resolved_slot, detail)

func get_last_error(slot_name: String = "") -> Dictionary:
	var session := _ensure_slot(_resolve_slot_name(slot_name))
	return session.get("last_error", {}).duplicate(true)
#endregion

#region PRIVATE HELPERS
func _validate_source(source: Dictionary) -> Dictionary:
	var validation := AeroVideoPlaybackContract.validate_source(source)
	if not validation.is_empty():
		return validation
	var cover_mode := _normalize_cover_mode(source.get("cover_mode", DEFAULT_COVER_MODE))
	if not COVER_MODES.has(cover_mode):
		return {
			"field": "cover_mode",
			"message": "Cover mode must be one of %s." % ", ".join(COVER_MODES),
			"source": source.duplicate(true),
		}
	var audio_level := float(source.get("audio_level", DEFAULT_AUDIO_LEVEL))
	if audio_level < 0.0 or audio_level > 1.0:
		return {
			"field": "audio_level",
			"message": "Audio level must stay within 0.0 and 1.0.",
			"source": source.duplicate(true),
		}
	return {}

func _ensure_loaded_for_slot(slot_name: String, message: String) -> bool:
	var session := _ensure_slot(slot_name)
	if not bool(session.get("has_loaded_media", false)):
		_raise_error_for_slot(slot_name, ERROR_NOT_READY, message, {}, true)
		return false
	return true

func _transition_state_for_slot(slot_name: String, state_code: int, detail: Dictionary = {}) -> void:
	var normalized_slot := _normalize_slot_name(slot_name)
	var session := _ensure_slot(normalized_slot)
	session["state_code"] = state_code
	session["state_name"] = STATE_NAMES.get(state_code, STATE_IDLE)
	_slots[normalized_slot] = session
	var payload := detail.duplicate(true)
	payload["slot"] = normalized_slot
	payload["state"] = str(session.get("state_name", STATE_IDLE))
	_state_changed_for_slot(normalized_slot, payload)

func _emit_position_changed_for_slot(slot_name: String, seconds: float, duration: float) -> void:
	var normalized := 0.0
	if duration > 0.0:
		normalized = clampf(seconds / duration, 0.0, 1.0)
	if slot_name == _active_slot:
		position_changed.emit(seconds, normalized)
	slot_position_changed.emit(slot_name, seconds, normalized)

func _emit_playback_finished_for_slot(slot_name: String) -> void:
	if slot_name == _active_slot:
		playback_finished.emit()
	slot_playback_finished.emit(slot_name)

func _lifecycle_apply_result_for_slot(slot_name: String, result: Dictionary, fallback_code: String, fallback_message: String) -> bool:
	if bool(result.get(AeroVideoPlaybackContract.RESULT_SUCCESS, false)):
		return true
	_raise_error_for_slot(
		slot_name,
		String(result.get(AeroVideoPlaybackContract.RESULT_CODE, fallback_code)),
		String(result.get(AeroVideoPlaybackContract.RESULT_MESSAGE, fallback_message)),
		result.get(AeroVideoPlaybackContract.RESULT_DETAIL, {}),
		true
	)
	return false

func _apply_result_for_slot(slot_name: String, result: Dictionary, fallback_code: String, fallback_message: String) -> void:
	if bool(result.get(AeroVideoPlaybackContract.RESULT_SUCCESS, false)):
		var session := _ensure_slot(slot_name)
		session["last_error"] = {}
		_slots[_normalize_slot_name(slot_name)] = session
		return
	_raise_error_for_slot(
		slot_name,
		String(result.get(AeroVideoPlaybackContract.RESULT_CODE, fallback_code)),
		String(result.get(AeroVideoPlaybackContract.RESULT_MESSAGE, fallback_message)),
		result.get(AeroVideoPlaybackContract.RESULT_DETAIL, {}),
		true
	)

func _raise_error_for_slot(slot_name: String, code: String, message: String, detail: Variant = {}, transition_to_error: bool = true) -> Dictionary:
	var normalized_slot := _normalize_slot_name(slot_name)
	var session := _ensure_slot(normalized_slot)
	var safe_detail: Dictionary = detail if typeof(detail) == TYPE_DICTIONARY else {"value": detail}
	session["last_error"] = {
		"code": code,
		"message": message,
		"detail": safe_detail.duplicate(true),
		"state": str(session.get("state_name", STATE_IDLE)),
		"slot": normalized_slot,
	}
	_slots[normalized_slot] = session
	if transition_to_error:
		_transition_state_for_slot(normalized_slot, PlaybackState.ERROR, session.get("last_error", {}).duplicate(true))
	var error_payload: Dictionary = session.get("last_error", {}).duplicate(true)
	if normalized_slot == _active_slot:
		error_raised.emit(error_payload.duplicate(true))
	slot_error_raised.emit(normalized_slot, error_payload.duplicate(true))
	return error_payload

func _ensure_slot(slot_name: String) -> Dictionary:
	var normalized_slot := _normalize_slot_name(slot_name)
	if not _slots.has(normalized_slot):
		_slots[normalized_slot] = {
			"backend": create_default_backend(),
			"backend_name": "",
			"state_name": STATE_IDLE,
			"state_code": PlaybackState.IDLE,
			"loaded_source": _ensure_source_defaults({}, normalized_slot),
			"media_info": {},
			"last_error": {},
			"has_loaded_media": false,
			"surface": null,
		}
		var created_backend: AeroVideoPlayerBackend = _slots[normalized_slot].get("backend", null) as AeroVideoPlayerBackend
		_slots[normalized_slot]["backend_name"] = _resolve_backend_name(created_backend)
	return _slots[normalized_slot]

func _resolve_backend_name(backend: AeroVideoPlayerBackend) -> String:
	return backend.get_script().resource_path.get_file().trim_suffix(".gd") if backend != null and backend.get_script() != null else "custom_backend"

func _resolve_slot_from_source(source: Dictionary) -> String:
	var direct_slot := str(source.get("slot", "")).strip_edges()
	if not direct_slot.is_empty():
		return _normalize_slot_name(direct_slot)
	var metadata: Dictionary = source.get("metadata", {}) if typeof(source.get("metadata", {})) == TYPE_DICTIONARY else {}
	if typeof(metadata) == TYPE_DICTIONARY:
		var metadata_slot := str(metadata.get("slot", "")).strip_edges()
		if not metadata_slot.is_empty():
			return _normalize_slot_name(metadata_slot)
	return _active_slot

func _resolve_slot_name(slot_name: String = "", source: Dictionary = {}) -> String:
	var explicit_slot := str(slot_name).strip_edges()
	if not explicit_slot.is_empty():
		return _normalize_slot_name(explicit_slot)
	if not source.is_empty():
		return _resolve_slot_from_source(source)
	return _normalize_slot_name(_active_slot)

func _with_slot(source: Dictionary, slot_name: String) -> Dictionary:
	var normalized_source := source.duplicate(true)
	normalized_source["slot"] = slot_name
	return normalized_source

func _prepare_source_for_slot(source: Dictionary, slot_name: String) -> Dictionary:
	var prepared_source := get_default_source_config()
	var session := _ensure_slot(slot_name)
	var seeded_source: Dictionary = _ensure_source_defaults(session.get("loaded_source", {}).duplicate(true), slot_name)
	if not seeded_source.is_empty():
		prepared_source.merge(seeded_source, true)
	prepared_source.merge(source.duplicate(true), true)
	return _ensure_source_defaults(prepared_source, slot_name)

func _ensure_source_defaults(source: Dictionary, slot_name: String) -> Dictionary:
	var normalized_source := get_default_source_config()
	normalized_source.merge(source.duplicate(true), true)
	normalized_source["slot"] = _normalize_slot_name(str(slot_name))
	normalized_source["cover_mode"] = _normalize_cover_mode(normalized_source.get("cover_mode", DEFAULT_COVER_MODE))
	normalized_source["audio_level"] = _normalize_audio_level(normalized_source.get("audio_level", DEFAULT_AUDIO_LEVEL))
	return normalized_source

func _normalize_cover_mode(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	return normalized if COVER_MODES.has(normalized) else DEFAULT_COVER_MODE

func _normalize_audio_level(value: Variant) -> float:
	return clampf(float(value), 0.0, 1.0)

func _slot_state_name(slot_name: String) -> String:
	var session := _ensure_slot(slot_name)
	return str(session.get("state_name", STATE_IDLE))

func _state_changed_for_slot(slot_name: String, detail: Dictionary) -> void:
	var state_name := str(detail.get("state", _slot_state_name(slot_name)))
	if slot_name == _active_slot:
		state_changed.emit(state_name, detail.duplicate(true))
	slot_state_changed.emit(slot_name, state_name, detail.duplicate(true))

static func _normalize_slot_name(slot_name: String) -> String:
	var normalized := slot_name.strip_edges()
	return normalized if not normalized.is_empty() else DEFAULT_SLOT

static func _infer_source_kind(path: String) -> String:
	var lowered := path.strip_edges().to_lower()
	if lowered.begins_with("http://") or lowered.begins_with("https://"):
		return SOURCE_KIND_URL
	return SOURCE_KIND_FILE
#endregion
