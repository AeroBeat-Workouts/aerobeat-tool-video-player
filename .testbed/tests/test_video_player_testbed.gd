extends GutTest

const TESTBED_SCENE := preload("res://scenes/video_player_testbed.tscn")
const SLOT_LEFT := "left"
const SAMPLE_VIDEO_PROJECT_PATH := "assets/videos/calm_blue_sea_1.ogv"

func test_testbed_injects_arbitrary_source_inputs_and_clickable_timeline_seek() -> void:
	var testbed := TESTBED_SCENE.instantiate()
	add_child_autofree(testbed)
	await get_tree().process_frame
	await get_tree().process_frame

	var left_ui: Dictionary = testbed.slot_ui.get(SLOT_LEFT, {})
	assert_true(left_ui.has("source_input"), "Tool proving surface should expose a manual source input for arbitrary path loading")
	assert_true(left_ui.has("duration_spin"), "Tool proving surface should expose a duration hint input for arbitrary source seeking")
	assert_true(left_ui.get("surface") is Control, "Tool proving surface should bind each slot to a Control container so vendor cover math targets the slot bounds")
	assert_eq(str(testbed._manager.get_backend(SLOT_LEFT).get_script().resource_path.get_file()), "AeroGodotVideoBackend.gd", "Tool proving surface should still route real playback through the injected Godot vendor backend via the repo-owned bridge")

	var source_input: LineEdit = left_ui.get("source_input")
	var duration_spin: SpinBox = left_ui.get("duration_spin")
	var seek_slider: HSlider = left_ui.get("seek_slider")
	source_input.text = SAMPLE_VIDEO_PROJECT_PATH
	duration_spin.value = 28.693313
	testbed._load_slot_from_input(SLOT_LEFT)

	assert_eq(String(testbed._manager.get_media_info(SLOT_LEFT).get("path", "")), SAMPLE_VIDEO_PROJECT_PATH, "Manual source loading should preserve the caller-facing project-relative path")
	assert_eq(String(testbed._manager.get_state(SLOT_LEFT).get("state", "")), AeroVideoPlayerManager.STATE_READY, "Manual source loading should leave the slot ready for interaction")

	testbed._load_external_source(SLOT_LEFT)
	assert_eq(String(testbed._manager.get_media_info(SLOT_LEFT).get("path", "")), testbed._external_sample_path, "External-source preset should load the copied outside-project sample path")
	assert_true(seek_slider.editable, "Loaded media with a duration hint should expose a clickable seek timeline")

	seek_slider.value = 11.25
	testbed._on_left_seek_slider_drag_ended(true)
	assert_eq(float(testbed._manager.get_position(SLOT_LEFT)), 11.25, "Timeline drag/click completion should seek the active slot to the slider value")
