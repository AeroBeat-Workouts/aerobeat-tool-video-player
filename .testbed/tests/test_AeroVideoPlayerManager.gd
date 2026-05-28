extends GutTest

const AeroVideoPlaybackContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")
const FAKE_BACKEND_SCRIPT := preload("res://addons/aerobeat-tool-video-player/src/AeroVideoPlayerFakeBackend.gd")
const GODOT_BACKEND_SCRIPT := preload("res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd")
const FAKE_VIDEO_STREAM_PLAYER_SCRIPT := preload("res://tests/helpers/FakeVideoStreamPlayer.gd")
const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_DURATION_SECONDS := 28.693313

var _manager: AeroVideoPlayerManager

func _make_fake_player() -> Node:
	return FAKE_VIDEO_STREAM_PLAYER_SCRIPT.new()

func _make_fake_vendor_backend() -> AeroVideoPlayerBackend:
	var backend := GODOT_BACKEND_SCRIPT.new()
	backend.set_player_factory(Callable(self, "_make_fake_player"))
	return backend

func before_each() -> void:
	_manager = AeroVideoPlayerManager.new()
	add_child_autofree(_manager)
	_manager._initialize()

func test_public_facade_exposes_stable_video_player_surface() -> void:
	assert_eq(AeroVideoPlayerManager.VERSION, "0.4.0", "Version should reflect loop + multi-slot support")
	assert_true(_manager.has_signal("state_changed"), "Public facade should expose state_changed")
	assert_true(_manager.has_signal("position_changed"), "Public facade should expose position_changed")
	assert_true(_manager.has_signal("media_loaded"), "Public facade should expose media_loaded")
	assert_true(_manager.has_signal("playback_finished"), "Public facade should expose playback_finished")
	assert_true(_manager.has_signal("error_raised"), "Public facade should expose error_raised")
	assert_true(_manager.has_signal("slot_state_changed"), "Public facade should expose slot_state_changed")
	assert_true(_manager.has_signal("slot_position_changed"), "Public facade should expose slot_position_changed")
	assert_true(_manager.has_signal("slot_media_loaded"), "Public facade should expose slot_media_loaded")
	assert_true(_manager.has_signal("slot_playback_finished"), "Public facade should expose slot_playback_finished")
	assert_true(_manager.has_signal("slot_error_raised"), "Public facade should expose slot_error_raised")
	assert_true(_manager.has_method("set_active_slot"), "Public facade should expose set_active_slot")
	assert_true(_manager.has_method("get_active_slot"), "Public facade should expose get_active_slot")
	assert_true(_manager.has_method("get_slot_names"), "Public facade should expose get_slot_names")
	assert_true(_manager.has_method("attach_slot_surface"), "Public facade should expose attach_slot_surface")
	assert_true(_manager.has_method("detach_slot_surface"), "Public facade should expose detach_slot_surface")
	assert_true(_manager.has_method("get_slot_state"), "Public facade should expose get_slot_state")
	assert_true(_manager.has_method("load"), "Public facade should expose load")
	assert_true(_manager.has_method("play"), "Public facade should expose play")
	assert_true(_manager.has_method("pause"), "Public facade should expose pause")
	assert_true(_manager.has_method("stop"), "Public facade should expose stop")
	assert_true(_manager.has_method("reset"), "Public facade should expose reset")
	assert_true(_manager.has_method("unload"), "Public facade should expose unload")
	assert_true(_manager.has_method("seek"), "Public facade should expose seek")
	assert_true(_manager.has_method("set_loop"), "Public facade should expose set_loop")
	assert_true(_manager.has_method("set_rate"), "Public facade should expose set_rate")
	assert_true(_manager.has_method("attach_surface"), "Public facade should expose attach_surface")
	assert_true(_manager.has_method("detach_surface"), "Public facade should expose detach_surface")
	assert_true(_manager.get_backend() is RefCounted, "Manager should default to a backend instance")
	assert_eq(_manager.get_active_slot(), AeroVideoPlayerManager.DEFAULT_SLOT, "Manager should default the active slot to primary")
	assert_eq(_manager.get_slot_names(), PackedStringArray([AeroVideoPlayerManager.DEFAULT_SLOT]), "Manager should bootstrap the primary slot")

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

func test_normalize_source_delegates_to_shared_contract_and_adds_slots() -> void:
	var source := {
		"path": " res://assets/videos/calm_blue_sea_1.ogv ",
		"autoplay": true,
		"metadata": {
			"slot": "right",
		},
	}
	var normalized := _manager.normalize_source(source)
	var shared := AeroVideoPlaybackContract.normalize_source(source)
	shared["slot"] = "right"
	assert_eq(normalized, shared, "manager normalization should match the shared contract plus slot resolution")
	assert_eq(String(normalized.get("path", "")), "res://assets/videos/calm_blue_sea_1.ogv", "normalize_source should trim path whitespace")
	assert_eq(String(normalized.get("kind", "")), AeroVideoPlayerManager.SOURCE_KIND_FILE, "normalize_source should default kind to file")
	assert_false(bool(normalized.get("loop", true)), "normalize_source should default loop to false")
	assert_true(bool(normalized.get("autoplay", false)), "normalize_source should preserve autoplay")
	assert_eq(float(normalized.get("start_time", -1.0)), 0.0, "normalize_source should default start_time to zero")
	assert_eq(float(normalized.get("rate", -1.0)), 1.0, "normalize_source should default rate to one")
	assert_eq(String(normalized.get("slot", "")), "right", "normalize_source should resolve slots from metadata")

func test_primary_slot_transport_controls_preserve_existing_behavior() -> void:
	var states: Array[String] = []
	var loaded_payloads: Array[Dictionary] = []
	var positions: Array[Array] = []
	_manager.state_changed.connect(func(state: String, _detail: Dictionary): states.append(state))
	_manager.media_loaded.connect(func(info: Dictionary): loaded_payloads.append(info))
	_manager.position_changed.connect(func(seconds: float, normalized: float): positions.append([seconds, normalized]))

	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 120.0,
		"start_time": 12.5,
		"rate": 1.5,
	})
	assert_eq(states.slice(0, 2), [AeroVideoPlayerManager.STATE_LOADING, AeroVideoPlayerManager.STATE_READY], "load should move through loading into ready")
	assert_eq(loaded_payloads.size(), 1, "load should emit one media_loaded payload")
	assert_eq(String(loaded_payloads[0].get("slot", "")), AeroVideoPlayerManager.DEFAULT_SLOT, "legacy media_loaded should still point at the primary slot")
	assert_eq(float(_manager.get_position()), 12.5, "load should honor start_time through seek")
	assert_eq(float(_manager.get_duration()), 120.0, "get_duration should reflect fake backend media info")

	_manager.play()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_PLAYING, "play should move the contract into playing")
	_manager.pause()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_PAUSED, "pause should move the contract into paused")
	_manager.seek(60.0)
	assert_eq(float(_manager.get_position()), 60.0, "seek should update the playback position")
	assert_eq(positions.back(), [60.0, 0.5], "position_changed should emit normalized progress")
	_manager.stop()
	assert_eq(String(_manager.get_state().get("state", "")), AeroVideoPlayerManager.STATE_READY, "stop should return the contract to ready when media remains loaded")
	assert_eq(float(_manager.get_position()), 0.0, "stop should reset position to zero")

func test_loop_can_be_toggled_per_slot_before_and_after_load() -> void:
	_manager.set_loop(true, "left")
	assert_true(bool(_manager.get_state("left").get("loop", false)), "set_loop should seed loop state before media is loaded")
	assert_false(bool(_manager.get_state().get("loop", true)), "pre-load loop on left should not leak to primary")

	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 42.0,
		"slot": "left",
	})
	assert_true(bool(_manager.get_state("left").get("loop", false)), "pre-load loop state should survive into the loaded slot")
	assert_eq(String(_manager.get_state("left").get("source", {}).get("slot", "")), "left", "loaded source should retain the resolved slot")

	_manager.set_loop(false, "left")
	assert_false(bool(_manager.get_state("left").get("loop", true)), "set_loop should toggle the loaded slot independently")
	assert_false(bool(_manager.get_state().get("loop", true)), "left loop changes should not mutate the primary slot state")

func test_multi_slot_playback_state_and_surfaces_stay_independent() -> void:
	var slot_states: Array[Dictionary] = []
	var slot_positions: Array[Dictionary] = []
	var slot_loaded: Array[Dictionary] = []
	_manager.slot_state_changed.connect(func(slot_name: String, state: String, detail: Dictionary): slot_states.append({"slot": slot_name, "state": state, "detail": detail.duplicate(true)}))
	_manager.slot_position_changed.connect(func(slot_name: String, seconds: float, normalized: float): slot_positions.append({"slot": slot_name, "seconds": seconds, "normalized": normalized}))
	_manager.slot_media_loaded.connect(func(slot_name: String, info: Dictionary): slot_loaded.append({"slot": slot_name, "info": info.duplicate(true)}))

	var left_surface := Node.new()
	left_surface.name = "LeftSurface"
	add_child_autofree(left_surface)
	var right_surface := Node.new()
	right_surface.name = "RightSurface"
	add_child_autofree(right_surface)

	_manager.attach_slot_surface("left", left_surface)
	_manager.attach_slot_surface("right", right_surface)
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 30.0,
		"start_time": 2.5,
		"loop": true,
	}, "left")
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 75.0,
		"start_time": 5.0,
		"loop": false,
	}, "right")
	_manager.play("left")
	_manager.seek(10.0, "right")
	_manager.pause("left")

	assert_eq(_manager.get_slot_names(), PackedStringArray(["left", AeroVideoPlayerManager.DEFAULT_SLOT, "right"]), "manager should track all created slot names")
	assert_true(bool(_manager.get_state("left").get("surface_attached", false)), "left slot should remember its own surface")
	assert_true(bool(_manager.get_state("right").get("surface_attached", false)), "right slot should remember its own surface")
	assert_eq(String(_manager.get_state("left").get("state", "")), AeroVideoPlayerManager.STATE_PAUSED, "left slot pause should not affect the right slot")
	assert_eq(String(_manager.get_state("right").get("state", "")), AeroVideoPlayerManager.STATE_READY, "right slot should remain ready after seek-only flow")
	assert_eq(float(_manager.get_position("left")), 2.5, "left slot should preserve its own seek position")
	assert_eq(float(_manager.get_position("right")), 10.0, "right slot should preserve its own seek position")
	assert_true(bool(_manager.get_state("left").get("loop", false)), "left slot should preserve its own loop flag")
	assert_false(bool(_manager.get_state("right").get("loop", true)), "right slot should preserve its own loop flag")
	assert_eq(slot_loaded.size(), 2, "each loaded slot should emit slot_media_loaded once")
	assert_true(slot_states.any(func(entry: Dictionary): return entry.get("slot", "") == "left" and entry.get("state", "") == AeroVideoPlayerManager.STATE_PLAYING), "left slot should emit a playing state")
	assert_true(slot_positions.any(func(entry: Dictionary): return entry.get("slot", "") == "right" and is_equal_approx(float(entry.get("seconds", 0.0)), 10.0)), "right slot should emit its own seek position")

func test_active_slot_controls_legacy_signals_while_slot_signals_stay_complete() -> void:
	var generic_loaded_slots: Array[String] = []
	var slot_loaded_slots: Array[String] = []
	_manager.media_loaded.connect(func(info: Dictionary): generic_loaded_slots.append(String(info.get("slot", ""))))
	_manager.slot_media_loaded.connect(func(slot_name: String, _info: Dictionary): slot_loaded_slots.append(slot_name))

	_manager.set_active_slot("right")
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 10.0}, "left")
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 10.0}, "right")

	assert_eq(generic_loaded_slots, ["right"], "legacy media_loaded should only mirror the active slot")
	assert_eq(slot_loaded_slots, ["left", "right"], "slot_media_loaded should report every slot event")

func test_reset_and_unload_are_slot_scoped() -> void:
	var left_surface := Node.new()
	left_surface.name = "LeftSurface"
	add_child_autofree(left_surface)
	var right_surface := Node.new()
	right_surface.name = "RightSurface"
	add_child_autofree(right_surface)

	_manager.attach_surface(left_surface, "left")
	_manager.attach_surface(right_surface, "right")
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 20.0}, "left")
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 20.0}, "right")
	_manager.seek(8.0, "left")
	_manager.seek(12.0, "right")

	_manager.reset("left")
	assert_eq(float(_manager.get_position("left")), 0.0, "reset should rewind only the targeted slot")
	assert_eq(float(_manager.get_position("right")), 12.0, "reset should not rewind other slots")
	assert_true(bool(_manager.get_state("left").get("surface_attached", false)), "reset should preserve the targeted slot surface")
	assert_true(bool(_manager.get_state("right").get("surface_attached", false)), "reset should not disturb other slot surfaces")

	_manager.unload("right")
	assert_eq(String(_manager.get_state("right").get("state", "")), AeroVideoPlayerManager.STATE_IDLE, "unload should idle only the targeted slot")
	assert_eq(String(_manager.get_state("left").get("state", "")), AeroVideoPlayerManager.STATE_READY, "unload should not disturb other loaded slots")
	assert_false(bool(_manager.get_state("right").get("surface_attached", true)), "unload should detach the targeted slot surface")
	assert_true(bool(_manager.get_state("left").get("surface_attached", false)), "unload should not detach other slot surfaces")

func test_invalid_source_raises_slot_scoped_contract_error_without_crashing() -> void:
	var slot_errors: Array[Dictionary] = []
	_manager.slot_error_raised.connect(func(slot_name: String, error_info: Dictionary): slot_errors.append({"slot": slot_name, "error": error_info.duplicate(true)}))

	_manager.load({"path": "", "kind": "file"}, "gallery")
	assert_eq(slot_errors.size(), 1, "Invalid load should raise one slot contract error")
	assert_eq(String(slot_errors[0].get("slot", "")), "gallery", "slot error should identify the failing slot")
	assert_eq(String(slot_errors[0].get("error", {}).get("code", "")), AeroVideoPlayerManager.ERROR_INVALID_SOURCE, "Invalid load should use the shared invalid_source error code")
	assert_eq(String(_manager.get_state("gallery").get("state", "")), AeroVideoPlayerManager.STATE_ERROR, "Invalid load should transition the failing slot into error")
	assert_eq(String(_manager.get_last_error("gallery").get("code", "")), AeroVideoPlayerManager.ERROR_INVALID_SOURCE, "Last error should retain the failure payload per slot")

func test_backend_can_be_swapped_per_slot_for_tests() -> void:
	var left_backend := FAKE_BACKEND_SCRIPT.new()
	var right_backend := FAKE_BACKEND_SCRIPT.new()
	_manager.set_backend(left_backend, "left")
	_manager.set_backend(right_backend, "right")
	assert_same(_manager.get_backend("left"), left_backend, "set_backend should allow deterministic backend substitution per slot")
	assert_same(_manager.get_backend("right"), right_backend, "set_backend should not collapse multiple slots onto one backend")

func test_manager_can_drive_multiple_vendor_backends_through_one_facade() -> void:
	var manager := AeroVideoPlayerManager.new()
	manager.set_backend_factory(Callable(self, "_make_fake_vendor_backend"))
	add_child_autofree(manager)
	manager._initialize()

	var left_surface := Node.new()
	left_surface.name = "ManagedLeftSurface"
	add_child_autofree(left_surface)
	var right_surface := Node.new()
	right_surface.name = "ManagedRightSurface"
	add_child_autofree(right_surface)
	manager.attach_surface(left_surface, "left")
	manager.attach_surface(right_surface, "right")
	manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"start_time": 3.25,
		"metadata": {
			"real_sample": true,
			"source": "tool_repo_testbed",
		},
	}, "left")
	manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"start_time": 1.5,
		"loop": true,
	}, "right")
	manager.seek(17.5, "left")
	manager.set_loop(false, "right")

	assert_eq(str(manager.get_state("left").get("state", "")), AeroVideoPlayerManager.STATE_READY, "Injected vendor backend should still drive the stable manager into ready")
	assert_eq(str(manager.get_state("left").get("backend", "")), "AeroGodotVideoBackend", "Manager should report the injected real backend name per slot")
	assert_eq(str(manager.get_media_info("left").get("vendor", "")), "godot_video", "Media info should expose the Godot vendor when injected")
	assert_eq(float(manager.get_duration("left")), SAMPLE_DURATION_SECONDS, "Truthful proving path should use the real sample duration hint")
	assert_eq(float(manager.get_position("left")), 17.5, "Stable manager seek should flow through the injected vendor backend on the targeted slot")
	assert_eq(float(manager.get_position("right")), 1.5, "A different vendor-backed slot should keep its own position")
	assert_false(bool(manager.get_state("right").get("loop", true)), "Loop updates should remain independently slot-scoped with vendor backends")
