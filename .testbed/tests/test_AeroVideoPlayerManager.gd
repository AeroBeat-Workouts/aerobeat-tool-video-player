extends GutTest

const AeroVideoPlaybackContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")
const FAKE_BACKEND_SCRIPT := preload("res://src/AeroVideoPlayerFakeBackend.gd")
const GODOT_BACKEND_SCRIPT := preload("res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd")
const FAKE_VIDEO_STREAM_PLAYER_SCRIPT := preload("res://tests/helpers/FakeVideoStreamPlayer.gd")
const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_DURATION_SECONDS := 28.693313

var _manager: AeroVideoPlayerManager

func _make_fake_player() -> Node:
	return FAKE_VIDEO_STREAM_PLAYER_SCRIPT.new()

func before_each() -> void:
	_manager = AeroVideoPlayerManager.new()
	add_child_autofree(_manager)
	_manager._initialize()

func test_public_facade_exposes_stable_video_player_surface() -> void:
	assert_eq(AeroVideoPlayerManager.VERSION, "0.3.0", "Version should reflect the lifecycle API expansion")
	assert_true(_manager.has_signal("state_changed"), "Public facade should expose state_changed")
	assert_true(_manager.has_signal("position_changed"), "Public facade should expose position_changed")
	assert_true(_manager.has_signal("media_loaded"), "Public facade should expose media_loaded")
	assert_true(_manager.has_signal("playback_finished"), "Public facade should expose playback_finished")
	assert_true(_manager.has_signal("error_raised"), "Public facade should expose error_raised")
	assert_true(_manager.has_method("load"), "Public facade should expose load")
	assert_true(_manager.has_method("play"), "Public facade should expose play")
	assert_true(_manager.has_method("pause"), "Public facade should expose pause")
	assert_true(_manager.has_method("stop"), "Public facade should expose stop")
	assert_true(_manager.has_method("reset"), "Public facade should expose reset")
	assert_true(_manager.has_method("unload"), "Public facade should expose unload")
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

func test_manager_constants_match_shared_tool_core_contract() -> void:
	assert_eq(AeroVideoPlayerManager.STATE_IDLE, AeroVideoPlaybackContract.STATE_IDLE, "idle state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.STATE_LOADING, AeroVideoPlaybackContract.STATE_LOADING, "loading state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.STATE_READY, AeroVideoPlaybackContract.STATE_READY, "ready state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.STATE_PLAYING, AeroVideoPlaybackContract.STATE_PLAYING, "playing state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.STATE_PAUSED, AeroVideoPlaybackContract.STATE_PAUSED, "paused state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.STATE_STOPPING, AeroVideoPlaybackContract.STATE_STOPPING, "stopping state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.STATE_ERROR, AeroVideoPlaybackContract.STATE_ERROR, "error state should come from tool-core")
	assert_eq(AeroVideoPlayerManager.ERROR_INVALID_SOURCE, AeroVideoPlaybackContract.ERROR_INVALID_SOURCE, "invalid_source should come from tool-core")
	assert_eq(AeroVideoPlayerManager.ERROR_INVALID_SURFACE, AeroVideoPlaybackContract.ERROR_INVALID_SURFACE, "invalid_surface should come from tool-core")
	assert_eq(AeroVideoPlayerManager.ERROR_BACKEND_REJECTED, AeroVideoPlaybackContract.ERROR_BACKEND_REJECTED, "backend_rejected should come from tool-core")
	assert_eq(AeroVideoPlayerManager.ERROR_NOT_READY, AeroVideoPlaybackContract.ERROR_NOT_READY, "not_ready should come from tool-core")

func test_normalize_source_delegates_to_shared_contract() -> void:
	var source := {
		"path": " res://assets/videos/calm_blue_sea_1.ogv ",
		"autoplay": true,
		"metadata": "not-a-dictionary",
	}
	var normalized := _manager.normalize_source(source)
	var shared := AeroVideoPlaybackContract.normalize_source(source)
	assert_eq(normalized, shared, "manager normalization should match the shared tool-core contract exactly")
	assert_eq(String(normalized.get("path", "")), "res://assets/videos/calm_blue_sea_1.ogv", "normalize_source should trim path whitespace")
	assert_eq(String(normalized.get("kind", "")), AeroVideoPlayerManager.SOURCE_KIND_FILE, "normalize_source should default kind to file")
	assert_false(bool(normalized.get("loop", true)), "normalize_source should default loop to false")
	assert_true(bool(normalized.get("autoplay", false)), "normalize_source should preserve autoplay")
	assert_eq(float(normalized.get("start_time", -1.0)), 0.0, "normalize_source should default start_time to zero")
	assert_eq(float(normalized.get("rate", -1.0)), 1.0, "normalize_source should default rate to one")
	assert_eq(normalized.get("metadata", {}), {}, "normalize_source should coerce non-dictionary metadata to an empty dictionary")

func test_load_and_basic_transport_controls_preserve_lifecycle_semantics() -> void:
	var states: Array[String] = []
	var loaded_payloads: Array[Dictionary] = []
	var positions: Array[Array] = []
	_manager.state_changed.connect(func(state: String, _detail: Dictionary): states.append(state))
	_manager.media_loaded.connect(func(info: Dictionary): loaded_payloads.append(info))
	_manager.position_changed.connect(func(seconds: float, normalized: float): positions.append([seconds, normalized]))

	_manager.load({
		"path": "res://assets/videos/calm_blue_sea_1.ogv",
		"duration_hint": 120.0,
		"start_time": 12.5,
		"rate": 1.5,
	})
	assert_eq(states.slice(0, 2), [AeroVideoPlayerManager.STATE_LOADING, AeroVideoPlayerManager.STATE_READY], "load should move through loading into ready")
	assert_eq(loaded_payloads.size(), 1, "load should emit one media_loaded payload")
	assert_eq(String(loaded_payloads[0].get("path", "")), "res://assets/videos/calm_blue_sea_1.ogv", "media_loaded should expose the loaded path")
	assert_eq(float(loaded_payloads[0].get("duration", 0.0)), 120.0, "media_loaded should expose fake backend duration")
	assert_eq(_manager.get_position(), 12.5, "load should honor start_time through seek")
	assert_eq(_manager.get_duration(), 120.0, "get_duration should reflect fake backend media info")

	_manager.play()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_PLAYING, "play should move the contract into playing")
	_manager.pause()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_PAUSED, "pause should move the contract into paused")
	_manager.seek(60.0)
	assert_eq(_manager.get_position(), 60.0, "seek should update the playback position")
	assert_eq(positions.back(), [60.0, 0.5], "position_changed should emit normalized progress")
	_manager.stop()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_READY, "stop should return the contract to ready when media remains loaded")
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

func test_reset_clears_error_and_preserves_loaded_media_and_surface() -> void:
	var output_surface := Node.new()
	output_surface.name = "VideoSurface"
	add_child_autofree(output_surface)
	_manager.attach_surface(output_surface)
	_manager.load({
		"path": "res://assets/videos/calm_blue_sea_1.ogv",
		"duration_hint": 120.0,
	})
	_manager.play()
	_manager.seek(45.0)
	_manager.load({"path": "", "kind": "file"})
	assert_eq(String(_manager.get_last_error().get("code", "")), AeroVideoPlayerManager.ERROR_INVALID_SOURCE, "invalid load should seed last_error before reset")

	_manager.reset()

	var state := _manager.get_state()
	assert_eq(String(state.get("state", "")), AeroVideoPlayerManager.STATE_READY, "reset should leave loaded media ready for reuse")
	assert_eq(_manager.get_last_error(), {}, "reset should clear manager last_error")
	assert_eq(float(_manager.get_position()), 0.0, "reset should seek playback back to zero")
	assert_true(bool(state.get("surface_attached", false)), "reset should preserve the current surface attachment")
	assert_eq(String(state.get("source", {}).get("path", "")), "res://assets/videos/calm_blue_sea_1.ogv", "reset should preserve the loaded source")
	assert_eq(float(state.get("media_info", {}).get("duration", 0.0)), 120.0, "reset should preserve media info")

	_manager.reset()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_READY, "reset should be idempotent while media remains loaded")

func test_unload_clears_loaded_media_and_forces_not_ready_behavior() -> void:
	var output_surface := Node.new()
	output_surface.name = "VideoSurface"
	add_child_autofree(output_surface)
	_manager.attach_surface(output_surface)
	_manager.load({
		"path": "res://assets/videos/calm_blue_sea_1.ogv",
		"duration_hint": 120.0,
	})
	_manager.play()
	_manager.load({"path": "", "kind": "file"})
	assert_false(_manager.get_last_error().is_empty(), "invalid load should seed last_error before unload")

	_manager.unload()

	var state := _manager.get_state()
	assert_eq(String(state.get("state", "")), AeroVideoPlayerManager.STATE_IDLE, "unload should leave the manager idle")
	assert_eq(_manager.get_last_error(), {}, "unload should clear manager last_error")
	assert_eq(state.get("source", {}), {}, "unload should clear the loaded source")
	assert_eq(state.get("media_info", {}), {}, "unload should clear media info")
	assert_false(bool(state.get("surface_attached", true)), "unload should detach any attached surface")
	assert_eq(_manager.get_position(), 0.0, "unload should make position behave as not-ready")
	assert_eq(_manager.get_duration(), 0.0, "unload should make duration behave as not-ready")

	_manager.play()
	assert_eq(String(_manager.get_last_error().get("code", "")), AeroVideoPlayerManager.ERROR_NOT_READY, "play after unload should behave as not-ready until a new load")

	_manager.unload()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_IDLE, "unload should be idempotent")

func test_invalid_source_raises_contract_error_without_crashing() -> void:
	var errors: Array[Dictionary] = []
	_manager.error_raised.connect(func(error_info: Dictionary): errors.append(error_info))

	_manager.load({"path": "", "kind": "file"})
	assert_eq(errors.size(), 1, "Invalid load should raise one contract error")
	assert_eq(String(errors[0].get("code", "")), AeroVideoPlayerManager.ERROR_INVALID_SOURCE, "Invalid load should use the shared invalid_source error code")
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_ERROR, "Invalid load should transition into error")
	assert_eq(String(_manager.get_last_error().get("code", "")), AeroVideoPlayerManager.ERROR_INVALID_SOURCE, "Last error should retain the failure payload")

func test_fake_backend_can_be_swapped_explicitly_for_tests() -> void:
	var backend := FAKE_BACKEND_SCRIPT.new()
	_manager.set_backend(backend)
	assert_same(_manager.get_backend(), backend, "set_backend should allow deterministic backend substitution for tests")

func test_manager_can_be_injected_with_godot_vendor_backend_for_truthful_seek_path() -> void:
	var manager := AeroVideoPlayerManager.new()
	var backend := GODOT_BACKEND_SCRIPT.new()
	backend.set_player_factory(Callable(self, "_make_fake_player"))
	manager.set_backend(backend)
	add_child_autofree(manager)
	manager._initialize()

	var surface := Node.new()
	surface.name = "ManagedSurface"
	add_child_autofree(surface)
	manager.attach_surface(surface)
	manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"start_time": 3.25,
		"metadata": {
			"real_sample": true,
			"source": "tool_repo_testbed",
		},
	})

	assert_eq(str(manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_READY, "Injected vendor backend should still drive the stable manager into ready")
	assert_eq(str(manager.get_state().get("backend", "")), "AeroGodotVideoBackend", "Manager should report the injected real backend name")
	assert_eq(str(manager.get_media_info().get("vendor", "")), "godot_video", "Media info should expose the Godot vendor when injected")
	assert_eq(float(manager.get_duration()), SAMPLE_DURATION_SECONDS, "Truthful proving path should use the real sample duration hint")
	assert_eq(float(manager.get_position()), 3.25, "Injected backend should honor start_time via seek")

	manager.seek(17.5)
	assert_eq(float(manager.get_position()), 17.5, "Stable manager seek should flow through the injected vendor backend")
	assert_eq(float(manager.get_state().get("position", 0.0)), 17.5, "State snapshot should expose the injected backend seek position")
