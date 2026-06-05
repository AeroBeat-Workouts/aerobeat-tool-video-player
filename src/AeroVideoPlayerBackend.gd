## Tool-local backend alias for the shared AeroBeat video playback contract.
##
## The shared playback vocabulary lives in aerobeat-tool-core. This repo keeps a
## local backend type name so downstream consumers can reference a stable
## tool-video-player surface while method/result semantics stay aligned to the
## shared contract.
class_name AeroVideoPlayerBackend
extends RefCounted

const CoreContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")
const TRANSPORT_MODE_EXACT_DECODED_FRAME := "exact_decoded_frame"
const TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX := "exact_owned_frame_index"
const TRANSPORT_MODE_APPROX_TIME_SEEK := "approx_time_seek"
const TRANSPORT_UNSUPPORTED_CODE := "backend_transport_unsupported"

func load(_source: Dictionary) -> Dictionary:
	return _unsupported("load")

func play() -> Dictionary:
	return _unsupported("play")

func pause() -> Dictionary:
	return _unsupported("pause")

func stop() -> Dictionary:
	return _unsupported("stop")

func unload() -> Dictionary:
	return _unsupported("unload")

func seek(_seconds: float) -> Dictionary:
	return _unsupported("seek")

func set_loop(_enabled: bool) -> Dictionary:
	return _unsupported("set_loop")

func set_rate(_rate: float) -> Dictionary:
	return _unsupported("set_rate")

func set_fit_mode(_fit_mode: String) -> Dictionary:
	return _unsupported("set_fit_mode")

func set_cover_mode(_cover_mode: String) -> Dictionary:
	return set_fit_mode(_cover_mode)

func set_audio_level(_audio_level: float) -> Dictionary:
	return _unsupported("set_audio_level")

func get_state() -> Dictionary:
	return CoreContract.build_state_snapshot()

func get_position() -> float:
	return float(get_state().get("position", 0.0))

func get_duration() -> float:
	return float(get_state().get("duration", 0.0))

func get_media_info() -> Dictionary:
	return {}

func get_transport_capabilities() -> Dictionary:
	return {
		"transport_mode": TRANSPORT_MODE_APPROX_TIME_SEEK,
		"can_step_forward": false,
		"can_step_backward": false,
		"can_seek_frame": false,
		"nominal_fps": null,
		"frame_duration_sec": null,
		"exactness_note": "This backend does not expose a frame-addressed transport contract.",
		"limitation_code": TRANSPORT_UNSUPPORTED_CODE,
	}

func get_transport_status() -> Dictionary:
	var state := get_state()
	var capabilities := get_transport_capabilities()
	return {
		"transport_mode": capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK),
		"can_step_forward": bool(capabilities.get("can_step_forward", false)),
		"can_step_backward": bool(capabilities.get("can_step_backward", false)),
		"can_seek_frame": bool(capabilities.get("can_seek_frame", false)),
		"frame_index": null,
		"frame_count": null,
		"nominal_fps": capabilities.get("nominal_fps", null),
		"frame_duration_sec": capabilities.get("frame_duration_sec", null),
		"paused": str(state.get("state", "")) == CoreContract.STATE_PAUSED,
		"position_sec": float(state.get("position", 0.0)),
		"duration_sec": float(state.get("duration", 0.0)),
		"exactness_note": capabilities.get("exactness_note", ""),
		"limitation_code": capabilities.get("limitation_code", TRANSPORT_UNSUPPORTED_CODE),
	}

func step_frames(_delta_frames: int) -> Dictionary:
	return _transport_unsupported("step_frames")

func seek_to_frame(_frame_index: int) -> Dictionary:
	return _transport_unsupported("seek_to_frame")

func attach_surface(_node: Node) -> Dictionary:
	return _unsupported("attach_surface")

func detach_surface() -> Dictionary:
	return _unsupported("detach_surface")

func get_last_error() -> Dictionary:
	return {}

func _unsupported(method_name: String) -> Dictionary:
	return CoreContract.fail(
		"backend_method_unimplemented",
		"%s is not implemented on this backend." % method_name,
		{"method": method_name}
	)

func _transport_unsupported(method_name: String) -> Dictionary:
	var capabilities := get_transport_capabilities()
	return CoreContract.fail(
		TRANSPORT_UNSUPPORTED_CODE,
		"%s requires exact frame-addressed transport, but this backend only supports %s." % [method_name, str(capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK))],
		{
			"method": method_name,
			"transport_mode": capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK),
			"capabilities": capabilities.duplicate(true),
		}
	)
