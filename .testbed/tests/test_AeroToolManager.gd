extends GutTest

const FAKE_BACKEND_SCRIPT := preload("res://src/AeroVideoPlayerFakeBackend.gd")

var _manager: AeroToolManager

func before_each() -> void:
	_manager = AeroToolManager.new()
	add_child_autofree(_manager)
	_manager._initialize()

func test_public_contract_shell_exposes_first_slice_surface() -> void:
	assert_eq(AeroToolManager.VERSION, "0.1.0", "Version should reflect the first contract-shell slice")
	assert_true(_manager.has_signal("state_changed"), "Public facade should expose state_changed")
	assert_true(_manager.has_signal("position_changed"), "Public facade should expose position_changed")
	assert_true(_manager.has_signal("media_loaded"), "Public facade should expose media_loaded")
	assert_true(_manager.has_signal("playback_finished"), "Public facade should expose playback_finished")
	assert_true(_manager.has_signal("error_raised"), "Public facade should expose error_raised")
	assert_true(_manager.has_method("load"), "Public facade should expose load")
	assert_true(_manager.has_method("play"), "Public facade should expose play")
	assert_true(_manager.has_method("pause"), "Public facade should expose pause")
	assert_true(_manager.has_method("stop"), "Public facade should expose stop")
	assert_true(_manager.has_method("seek"), "Public facade should expose seek")
	assert_true(_manager.has_method("set_loop"), "Public facade should expose set_loop")
	assert_true(_manager.has_method("set_rate"), "Public facade should expose set_rate")
	assert_true(_manager.has_method("get_state"), "Public facade should expose get_state")
	assert_true(_manager.has_method("get_duration"), "Public facade should expose get_duration")
	assert_true(_manager.has_method("get_position"), "Public facade should expose get_position")
	assert_true(_manager.has_method("get_media_info"), "Public facade should expose get_media_info")
	assert_true(_manager.has_method("attach_surface"), "Public facade should expose attach_surface")
	assert_true(_manager.has_method("detach_surface"), "Public facade should expose detach_surface")
	assert_true(_manager.has_method("get_last_error"), "Public facade should expose get_last_error")
	assert_true(_manager.get_backend() is RefCounted, "Manager should default to a backend instance")

func test_normalize_source_applies_default_contract_values() -> void:
	var normalized := _manager.normalize_source({
		"path": " res://videos/example.ogv ",
		"autoplay": true,
		"metadata": "not-a-dictionary",
	})
	assert_eq(String(normalized.get("path", "")), "res://videos/example.ogv", "normalize_source should trim path whitespace")
	assert_eq(String(normalized.get("kind", "")), AeroToolManager.SOURCE_KIND_FILE, "normalize_source should default kind to file")
	assert_false(bool(normalized.get("loop", true)), "normalize_source should default loop to false")
	assert_true(bool(normalized.get("autoplay", false)), "normalize_source should preserve autoplay")
	assert_eq(float(normalized.get("start_time", -1.0)), 0.0, "normalize_source should default start_time to zero")
	assert_eq(float(normalized.get("rate", -1.0)), 1.0, "normalize_source should default rate to one")
	assert_eq(normalized.get("metadata", {}), {}, "normalize_source should coerce non-dictionary metadata to an empty dictionary")

func test_load_and_basic_transport_controls_use_fake_backend_contract() -> void:
	var states: Array[String] = []
	var loaded_payloads: Array[Dictionary] = []
	var positions: Array[Array] = []
	_manager.state_changed.connect(func(state: String, _detail: Dictionary): states.append(state))
	_manager.media_loaded.connect(func(info: Dictionary): loaded_payloads.append(info))
	_manager.position_changed.connect(func(seconds: float, normalized: float): positions.append([seconds, normalized]))

	_manager.load({
		"path": "res://videos/example.ogv",
		"duration_hint": 120.0,
		"start_time": 12.5,
		"rate": 1.5,
	})
	assert_eq(states.slice(0, 2), [AeroToolManager.STATE_LOADING, AeroToolManager.STATE_READY], "load should move through loading into ready")
	assert_eq(loaded_payloads.size(), 1, "load should emit one media_loaded payload")
	assert_eq(String(loaded_payloads[0].get("path", "")), "res://videos/example.ogv", "media_loaded should expose the loaded path")
	assert_eq(float(loaded_payloads[0].get("duration", 0.0)), 120.0, "media_loaded should expose fake backend duration")
	assert_eq(_manager.get_position(), 12.5, "load should honor start_time through seek")
	assert_eq(_manager.get_duration(), 120.0, "get_duration should reflect fake backend media info")

	_manager.play()
	assert_eq(String(_manager.get_state().get("state", "")), AeroToolManager.STATE_PLAYING, "play should move the contract into playing")
	_manager.pause()
	assert_eq(String(_manager.get_state().get("state", "")), AeroToolManager.STATE_PAUSED, "pause should move the contract into paused")
	_manager.seek(60.0)
	assert_eq(_manager.get_position(), 60.0, "seek should update the playback position")
	assert_eq(positions.back(), [60.0, 0.5], "position_changed should emit normalized progress")
	_manager.stop()
	assert_eq(String(_manager.get_state().get("state", "")), AeroToolManager.STATE_READY, "stop should return the contract to ready when media remains loaded")
	assert_eq(_manager.get_position(), 0.0, "stop should reset position to zero")

func test_attach_and_detach_surface_track_binding_contract() -> void:
	var output_surface := Node.new()
	output_surface.name = "VideoSurface"
	add_child_autofree(output_surface)

	_manager.attach_surface(output_surface)
	var attached_state := _manager.get_state()
	assert_true(bool(attached_state.get("surface_attached", false)), "attach_surface should mark the state as bound to a surface")

	_manager.detach_surface()
	var detached_state := _manager.get_state()
	assert_false(bool(detached_state.get("surface_attached", true)), "detach_surface should clear the surface binding")

func test_invalid_source_raises_contract_error_without_crashing() -> void:
	var errors: Array[Dictionary] = []
	_manager.error_raised.connect(func(error_info: Dictionary): errors.append(error_info))

	_manager.load({"path": "", "kind": "file"})
	assert_eq(errors.size(), 1, "Invalid load should raise one contract error")
	assert_eq(String(errors[0].get("code", "")), AeroToolManager.ERROR_INVALID_SOURCE, "Invalid load should use the frozen invalid_source error code")
	assert_eq(String(_manager.get_state().get("state", "")), AeroToolManager.STATE_ERROR, "Invalid load should transition into error")
	assert_eq(String(_manager.get_last_error().get("code", "")), AeroToolManager.ERROR_INVALID_SOURCE, "Last error should retain the failure payload")

func test_fake_backend_can_be_swapped_explicitly_for_tests() -> void:
	var backend := FAKE_BACKEND_SCRIPT.new()
	_manager.set_backend(backend)
	assert_same(_manager.get_backend(), backend, "set_backend should allow deterministic backend substitution for tests")
