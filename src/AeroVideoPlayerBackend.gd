## Tool-local backend alias for the shared AeroBeat video playback contract.
##
## The shared playback vocabulary lives in aerobeat-tool-core. This repo keeps a
## local backend type name so downstream consumers can reference a stable
## tool-video-player surface while method/result semantics stay aligned to the
## shared contract.
class_name AeroVideoPlayerBackend
extends RefCounted

const CoreContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")

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

func set_cover_mode(_cover_mode: String) -> Dictionary:
	return _unsupported("set_cover_mode")

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
