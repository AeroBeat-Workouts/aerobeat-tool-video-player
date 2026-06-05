extends GutTest

const AeroVideoPlaybackContract := preload("res://addons/aerobeat-tool-core/globals/aero_video_playback_contract.gd")
const FAKE_BACKEND_SCRIPT := preload("res://addons/aerobeat-tool-video-player/src/AeroVideoPlayerFakeBackend.gd")
const GODOT_BACKEND_SCRIPT := preload("res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd")
const FAKE_VIDEO_STREAM_PLAYER_SCRIPT := preload("res://tests/helpers/FakeVideoStreamPlayer.gd")
const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_DURATION_SECONDS := 28.693313

var _manager: AeroVideoPlayerManager
var _external_tmp_dir: String = ""
var _external_sample_path: String = ""

func _make_fake_player() -> Node:
	return FAKE_VIDEO_STREAM_PLAYER_SCRIPT.new()

func _make_fake_vendor_backend() -> AeroVideoPlayerBackend:
	var backend := GODOT_BACKEND_SCRIPT.new()
	backend.set_player_factory(Callable(self, "_make_fake_player"))
	backend.set_remote_source_resolver(Callable(self, "_resolve_remote_sample"))
	return backend

func _resolve_remote_sample(_url: String) -> String:
	return _external_sample_path

func before_each() -> void:
	_manager = AeroVideoPlayerManager.new()
	add_child_autofree(_manager)
	_manager._initialize()
	_prepare_external_sample()

func after_each() -> void:
	if not _external_sample_path.is_empty() and FileAccess.file_exists(_external_sample_path):
		DirAccess.remove_absolute(_external_sample_path)
	if not _external_tmp_dir.is_empty() and DirAccess.dir_exists_absolute(_external_tmp_dir):
		DirAccess.remove_absolute(_external_tmp_dir)
	_external_sample_path = ""
	_external_tmp_dir = ""

func _prepare_external_sample() -> void:
	_external_tmp_dir = OS.get_cache_dir().path_join("aerobeat-tool-video-player-external-%s" % str(Time.get_unix_time_from_system()))
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_external_tmp_dir)
	assert_eq(mkdir_error, OK, "Should create a temporary directory for remote-url coverage")
	_external_sample_path = _external_tmp_dir.path_join("external-sample.ogv")
	var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(SAMPLE_VIDEO_PATH), _external_sample_path)
	assert_eq(copy_error, OK, "Should copy the proven sample outside the project tree for remote-url coverage")

func test_public_facade_exposes_stable_video_player_surface() -> void:
	assert_eq(AeroVideoPlayerManager.VERSION, "0.7.0", "Version should reflect the truthful transport contract addition")
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
	assert_true(_manager.has_method("get_transport_capabilities"), "Public facade should expose transport capability inspection")
	assert_true(_manager.has_method("get_transport_status"), "Public facade should expose transport status inspection")
	assert_true(_manager.has_method("step_frames"), "Public facade should expose frame stepping")
	assert_true(_manager.has_method("seek_to_frame"), "Public facade should expose frame-addressed seeking")
	assert_true(_manager.has_method("set_loop"), "Public facade should expose set_loop")
	assert_true(_manager.has_method("set_rate"), "Public facade should expose set_rate")
	assert_true(_manager.has_method("set_fit_mode"), "Public facade should expose set_fit_mode")
	assert_true(_manager.has_method("set_cover_mode"), "Compatibility seam should remain available for old callers")
	assert_true(_manager.has_method("set_audio_level"), "Public facade should expose set_audio_level")
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

func test_normalize_source_delegates_to_shared_contract_and_adds_slots_cover_and_audio() -> void:
	var source := {
		"path": " res://assets/videos/calm_blue_sea_1.ogv ",
		"autoplay": true,
		"fit_mode": "cover",
		"audio_level": 0.35,
		"metadata": {
			"slot": "right",
		},
	}
	var normalized := _manager.normalize_source(source)
	assert_eq(String(normalized.get("path", "")), "res://assets/videos/calm_blue_sea_1.ogv", "normalize_source should trim path whitespace")
	assert_eq(String(normalized.get("kind", "")), AeroVideoPlayerManager.SOURCE_KIND_FILE, "normalize_source should keep project paths as local file sources by default")
	assert_false(bool(normalized.get("loop", true)), "normalize_source should default loop to false")
	assert_true(bool(normalized.get("autoplay", false)), "normalize_source should preserve autoplay")
	assert_eq(float(normalized.get("start_time", -1.0)), 0.0, "normalize_source should default start_time to zero")
	assert_eq(float(normalized.get("rate", -1.0)), 1.0, "normalize_source should default rate to one")
	assert_eq(String(normalized.get("slot", "")), "right", "normalize_source should resolve slots from metadata")
	assert_eq(String(normalized.get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "normalize_source should preserve supported fit modes")
	assert_eq(String(normalized.get("cover_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "normalize_source should mirror the compatibility alias for old callers")
	assert_eq(float(normalized.get("audio_level", -1.0)), 0.35, "normalize_source should preserve audio level")

func test_normalize_source_reclassifies_http_urls_as_remote_sources() -> void:
	var normalized := _manager.normalize_source({
		"path": " https://upload.wikimedia.org/wikipedia/commons/6/65/Examplevideo.ogv ",
		"metadata": {"slot": "remote"},
	})
	assert_eq(String(normalized.get("path", "")), "https://upload.wikimedia.org/wikipedia/commons/6/65/Examplevideo.ogv", "normalize_source should trim remote URL whitespace")
	assert_eq(String(normalized.get("kind", "")), AeroVideoPlayerManager.SOURCE_KIND_URL, "normalize_source should classify http(s) paths as remote URLs even when kind is omitted")
	assert_eq(String(normalized.get("slot", "")), "remote", "normalize_source should still resolve the requested slot")

func test_primary_slot_transport_controls_preserve_existing_behavior_and_report_cover_audio() -> void:
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
		"fit_mode": AeroVideoPlayerManager.FIT_MODE_COVER,
		"audio_level": 0.4,
	})
	assert_eq(states.slice(0, 2), [AeroVideoPlayerManager.STATE_LOADING, AeroVideoPlayerManager.STATE_READY], "load should move through loading into ready")
	assert_eq(loaded_payloads.size(), 1, "load should emit one media_loaded payload")
	assert_eq(String(loaded_payloads[0].get("slot", "")), AeroVideoPlayerManager.DEFAULT_SLOT, "legacy media_loaded should still point at the primary slot")
	assert_eq(float(_manager.get_position()), 12.5, "load should honor start_time through seek")
	assert_eq(float(_manager.get_duration()), 120.0, "get_duration should reflect fake backend media info")
	assert_eq(String(_manager.get_state().get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "fit mode should flow through load")
	assert_eq(float(_manager.get_state().get("audio_level", -1.0)), 0.4, "audio level should flow through load")

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

func test_fake_backend_transport_contract_is_exact_owned_frame_index() -> void:
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 10.0,
		"fps_hint": 20.0,
	})

	var capabilities := _manager.get_transport_capabilities()
	assert_eq(String(capabilities.get("transport_mode", "")), AeroVideoPlayerManager.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX, "Default fake backend should report exact owned-frame transport")
	assert_true(bool(capabilities.get("can_step_forward", false)), "Fake backend should advertise forward frame stepping")
	assert_true(bool(capabilities.get("can_seek_frame", false)), "Fake backend should advertise frame-addressed seeking")
	assert_eq(float(capabilities.get("nominal_fps", -1.0)), 20.0, "Fake backend should surface the configured nominal fps")

	var seek_result := _manager.seek_to_frame(10)
	assert_true(bool(seek_result.get("success", false)), "seek_to_frame should succeed on the fake backend")
	assert_almost_eq(_manager.get_position(), 0.5, 0.0001, "Frame-addressed seek should move to the expected timestamp on the fake backend")
	var status := _manager.get_transport_status()
	assert_eq(int(status.get("frame_index", -1)), 10, "Transport status should report the current owned frame index")
	assert_eq(int(status.get("frame_count", -1)), 200, "Transport status should report the synthetic frame count")

	var step_result := _manager.step_frames(5)
	assert_true(bool(step_result.get("success", false)), "step_frames should succeed on the fake backend")
	assert_eq(int(_manager.get_transport_status().get("frame_index", -1)), 15, "Frame stepping should advance the owned frame index exactly")

func test_fit_mode_and_audio_level_can_be_toggled_per_slot_before_and_after_load() -> void:
	_manager.set_fit_mode(AeroVideoPlayerManager.FIT_MODE_STRETCH, "left")
	_manager.set_audio_level(0.25, "left")
	assert_eq(String(_manager.get_state("left").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_STRETCH, "set_fit_mode should seed fit mode before media is loaded")
	assert_eq(float(_manager.get_state("left").get("audio_level", -1.0)), 0.25, "set_audio_level should seed audio level before media is loaded")
	assert_eq(String(_manager.get_state().get("fit_mode", "")), AeroVideoPlayerManager.DEFAULT_FIT_MODE, "left cover changes should not leak to primary")

	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 42.0,
		"slot": "left",
	}, "left")
	assert_eq(String(_manager.get_state("left").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_STRETCH, "pre-load fit mode should survive into the loaded slot")
	assert_eq(float(_manager.get_state("left").get("audio_level", -1.0)), 0.25, "pre-load audio level should survive into the loaded slot")

	_manager.set_fit_mode(AeroVideoPlayerManager.FIT_MODE_COVER, "left")
	_manager.set_audio_level(0.9, "left")
	assert_eq(String(_manager.get_state("left").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "set_fit_mode should update the loaded slot independently")
	assert_eq(float(_manager.get_state("left").get("audio_level", -1.0)), 0.9, "set_audio_level should update the loaded slot independently")

func test_multi_slot_playback_state_surfaces_cover_and_audio_stay_independent() -> void:
	var left_surface := Control.new()
	left_surface.name = "LeftSurface"
	left_surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(left_surface)
	var right_surface := Control.new()
	right_surface.name = "RightSurface"
	right_surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(right_surface)

	_manager.attach_slot_surface("left", left_surface)
	_manager.attach_slot_surface("right", right_surface)
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 30.0,
		"start_time": 2.5,
		"loop": true,
		"fit_mode": AeroVideoPlayerManager.FIT_MODE_COVER,
		"audio_level": 0.55,
	}, "left")
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 75.0,
		"start_time": 5.0,
		"loop": false,
		"fit_mode": AeroVideoPlayerManager.FIT_MODE_STRETCH,
		"audio_level": 0.15,
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
	assert_eq(String(_manager.get_state("left").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "left slot should preserve its own fit mode")
	assert_eq(String(_manager.get_state("right").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_STRETCH, "right slot should preserve its own fit mode")
	assert_eq(float(_manager.get_state("left").get("audio_level", -1.0)), 0.55, "left slot should preserve its own audio level")
	assert_eq(float(_manager.get_state("right").get("audio_level", -1.0)), 0.15, "right slot should preserve its own audio level")

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
	var left_surface := Control.new()
	left_surface.name = "LeftSurface"
	left_surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(left_surface)
	var right_surface := Control.new()
	right_surface.name = "RightSurface"
	right_surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(right_surface)

	_manager.attach_surface(left_surface, "left")
	_manager.attach_surface(right_surface, "right")
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 20.0, "fit_mode": AeroVideoPlayerManager.FIT_MODE_COVER, "audio_level": 0.33}, "left")
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 20.0, "fit_mode": AeroVideoPlayerManager.FIT_MODE_STRETCH, "audio_level": 0.8}, "right")
	_manager.seek(8.0, "left")
	_manager.seek(12.0, "right")

	_manager.reset("left")
	assert_eq(float(_manager.get_position("left")), 0.0, "reset should rewind only the targeted slot")
	assert_eq(float(_manager.get_position("right")), 12.0, "reset should not rewind other slots")
	assert_eq(String(_manager.get_state("left").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "reset should preserve the targeted slot fit mode")
	assert_eq(float(_manager.get_state("right").get("audio_level", -1.0)), 0.8, "reset should not disturb other slot audio levels")

	_manager.unload("right")
	assert_eq(String(_manager.get_state("right").get("state", "")), AeroVideoPlayerManager.STATE_IDLE, "unload should idle only the targeted slot")
	assert_true(bool(_manager.get_state("right").get("surface_attached", false)), "unload should preserve the targeted slot surface binding for later reloads")
	assert_eq(String(_manager.get_state("left").get("state", "")), AeroVideoPlayerManager.STATE_READY, "unload should not disturb other loaded slots")

	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 20.0, "fit_mode": AeroVideoPlayerManager.FIT_MODE_CONTAIN, "audio_level": 0.2}, "right")
	assert_eq(String(_manager.get_state("right").get("state", "")), AeroVideoPlayerManager.STATE_READY, "A slot should be reloadable after unload without reattaching its surface")
	assert_true(bool(_manager.get_state("right").get("surface_attached", false)), "Reload after unload should still render through the preserved surface")

func test_manager_load_accepts_http_url_sources_without_explicit_kind_when_vendor_backend_is_injected() -> void:
	var manager := AeroVideoPlayerManager.new()
	manager.set_backend_factory(Callable(self, "_make_fake_vendor_backend"))
	add_child_autofree(manager)
	manager._initialize()
	var remote_errors: Array[Dictionary] = []
	manager.slot_error_raised.connect(func(slot_name: String, error_info: Dictionary): remote_errors.append({"slot": slot_name, "error": error_info.duplicate(true)}))

	var surface := Control.new()
	surface.name = "RemoteManagedSurface"
	surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(surface)
	manager.attach_surface(surface, "remote")
	manager.load({
		"path": "https://upload.wikimedia.org/wikipedia/commons/6/65/Examplevideo.ogv",
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"metadata": {"source": "wikimedia_repro"},
	}, "remote")

	assert_true(remote_errors.is_empty(), "Remote URL loads should not be rejected as invalid local-file sources when kind is omitted")
	assert_eq(String(manager.get_state("remote").get("state", "")), AeroVideoPlayerManager.STATE_READY, "Injected vendor backend should reach ready for http(s) sources without an explicit kind")
	assert_eq(String(manager.get_media_info("remote").get("kind", "")), AeroVideoPlayerManager.SOURCE_KIND_URL, "Media info should report the normalized remote url source kind")
	assert_eq(String(manager.get_media_info("remote").get("path", "")), "https://upload.wikimedia.org/wikipedia/commons/6/65/Examplevideo.ogv", "Manager should preserve the caller-facing URL after load")
	assert_eq(String(manager.get_media_info("remote").get("resolved_path", "")), _external_sample_path, "Injected vendor backend should use the deterministic resolved cache file path for remote loads")

func test_injected_godot_backend_reports_approx_time_seek_and_refuses_exact_frame_transport() -> void:
	var manager := AeroVideoPlayerManager.new()
	manager.set_backend_factory(Callable(self, "_make_fake_vendor_backend"))
	add_child_autofree(manager)
	manager._initialize()
	var slot_errors: Array[Dictionary] = []
	manager.slot_error_raised.connect(func(slot_name: String, error_info: Dictionary): slot_errors.append({"slot": slot_name, "error": error_info.duplicate(true)}))

	var surface := Control.new()
	surface.name = "TransportManagedSurface"
	surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(surface)
	manager.attach_surface(surface, "transport")
	manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"start_time": 2.0,
		"fps_hint": 30.0,
	}, "transport")

	var capabilities := manager.get_transport_capabilities("transport")
	assert_eq(String(capabilities.get("transport_mode", "")), AeroVideoPlayerManager.TRANSPORT_MODE_APPROX_TIME_SEEK, "Injected Godot backend should report approximate time-seek transport for the built-in .ogv path")
	assert_false(bool(capabilities.get("can_step_forward", true)), "Injected Godot backend should refuse exact frame stepping")
	assert_false(bool(capabilities.get("can_seek_frame", true)), "Injected Godot backend should refuse exact frame-addressed seek")

	var step_result := manager.step_frames(1, "transport")
	assert_false(bool(step_result.get("success", true)), "Frame stepping should fail against the approximate-only Godot backend")
	assert_eq(String(step_result.get("code", "")), AeroVideoPlayerManager.ERROR_TRANSPORT_UNSUPPORTED, "Approximate-only transport should fail with the shared transport-unsupported code")
	assert_eq(String(manager.get_state("transport").get("state", "")), AeroVideoPlayerManager.STATE_READY, "Refused frame stepping should not poison the slot playback state")
	assert_eq(float(manager.get_position("transport")), 2.0, "Refused frame stepping should leave the current timestamp unchanged")
	assert_eq(String(manager.get_last_error("transport").get("code", "")), AeroVideoPlayerManager.ERROR_TRANSPORT_UNSUPPORTED, "Manager should retain the non-fatal transport refusal as last_error")
	assert_eq(slot_errors.size(), 1, "Manager should still surface one slot-scoped error event for the refused transport operation")

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

func test_manager_can_drive_multiple_vendor_backends_through_one_facade_with_cover_and_audio() -> void:
	var manager := AeroVideoPlayerManager.new()
	manager.set_backend_factory(Callable(self, "_make_fake_vendor_backend"))
	add_child_autofree(manager)
	manager._initialize()

	var left_surface := Control.new()
	left_surface.name = "ManagedLeftSurface"
	left_surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(left_surface)
	var right_surface := Control.new()
	right_surface.name = "ManagedRightSurface"
	right_surface.custom_minimum_size = Vector2(640, 360)
	add_child_autofree(right_surface)
	manager.attach_surface(left_surface, "left")
	manager.attach_surface(right_surface, "right")
	manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"start_time": 3.25,
		"fit_mode": AeroVideoPlayerManager.FIT_MODE_COVER,
		"audio_level": 0.6,
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
		"fit_mode": AeroVideoPlayerManager.FIT_MODE_STRETCH,
		"audio_level": 0.2,
	}, "right")
	manager.seek(17.5, "left")
	manager.set_loop(false, "right")
	manager.set_audio_level(0.85, "right")

	assert_eq(str(manager.get_state("left").get("state", "")), AeroVideoPlayerManager.STATE_READY, "Injected vendor backend should still drive the stable manager into ready")
	assert_eq(str(manager.get_state("left").get("backend", "")), "AeroGodotVideoBackend", "Manager should report the injected real backend name per slot")
	assert_eq(str(manager.get_media_info("left").get("vendor", "")), "godot_video", "Media info should expose the Godot vendor when injected")
	assert_eq(float(manager.get_duration("left")), SAMPLE_DURATION_SECONDS, "Truthful proving path should use the real sample duration hint")
	assert_eq(float(manager.get_position("left")), 17.5, "Stable manager seek should flow through the injected vendor backend on the targeted slot")
	assert_eq(float(manager.get_position("right")), 1.5, "A different vendor-backed slot should keep its own position")
	assert_eq(String(manager.get_state("left").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_COVER, "Left slot should preserve its fit mode through the real backend")
	assert_eq(String(manager.get_state("right").get("fit_mode", "")), AeroVideoPlayerManager.FIT_MODE_STRETCH, "Right slot should preserve its fit mode through the real backend")
	assert_eq(float(manager.get_state("right").get("audio_level", -1.0)), 0.85, "Audio-level updates should flow through the real backend on the targeted slot")
