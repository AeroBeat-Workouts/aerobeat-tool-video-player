## Backend interface contract for AeroBeat video playback vendors.
##
## Concrete backends should preserve the dictionary/signal vocabulary owned by the
## repo-root AeroToolManager facade while hiding vendor-specific player details.
extends RefCounted

const RESULT_SUCCESS := "success"
const RESULT_CODE := "code"
const RESULT_MESSAGE := "message"
const RESULT_DETAIL := "detail"

func load(_source: Dictionary) -> Dictionary:
	return _unsupported("load")

func play() -> Dictionary:
	return _unsupported("play")

func pause() -> Dictionary:
	return _unsupported("pause")

func stop() -> Dictionary:
	return _unsupported("stop")

func seek(_seconds: float) -> Dictionary:
	return _unsupported("seek")

func set_loop(_enabled: bool) -> Dictionary:
	return _unsupported("set_loop")

func set_rate(_rate: float) -> Dictionary:
	return _unsupported("set_rate")

func get_state() -> Dictionary:
	return {
		"state": "idle",
		"position": 0.0,
		"duration": 0.0,
		"loop": false,
		"rate": 1.0,
		"surface_attached": false,
	}

func get_position() -> float:
	return float(get_state().get("position", 0.0))

func get_duration() -> float:
	return float(get_state().get("duration", 0.0))

func get_media_info() -> Dictionary:
	return {}

func attach_surface(_node: Node) -> Dictionary:
	return _unsupported("attach_surface")

func detach_surface() -> Dictionary:
	return _unsupported("detach_surface")

func get_last_error() -> Dictionary:
	return {}

func _unsupported(method_name: String) -> Dictionary:
	return {
		RESULT_SUCCESS: false,
		RESULT_CODE: "backend_method_unimplemented",
		RESULT_MESSAGE: "%s is not implemented on this backend." % method_name,
		RESULT_DETAIL: {"method": method_name},
	}
