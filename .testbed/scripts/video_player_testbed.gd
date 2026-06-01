extends Control

const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_VIDEO_PROJECT_PATH := "assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_DURATION_SECONDS := 28.693313
const SAMPLE_REMOTE_URL := "https://example.com/path/to/video.ogv"
const SEEK_STEP_SECONDS := 5.0
const RESPONSIVE_STACK_BREAKPOINT := 1180.0
const SLOT_LEFT := "left"
const SLOT_RIGHT := "right"
const SLOT_NAMES := [SLOT_LEFT, SLOT_RIGHT]
const FIT_MODE_OPTIONS := [
	AeroVideoPlayerManager.FIT_MODE_STRETCH,
	AeroVideoPlayerManager.FIT_MODE_CONTAIN,
	AeroVideoPlayerManager.FIT_MODE_COVER,
]
const GodotBackendBridgeScript := preload("res://addons/aerobeat-tool-video-player/src/AeroVideoPlayerGodotBackendBridge.gd")

@onready var status_label: Label = %StatusLabel
@onready var active_slot_label: Label = %ActiveSlotLabel
@onready var slots_row: BoxContainer = %SlotsRow
@onready var slot_ui := {
	SLOT_LEFT: {
		"path_label": %LeftPathLabel,
		"backend_label": %LeftBackendLabel,
		"playback_label": %LeftPlaybackLabel,
		"position_label": %LeftPositionLabel,
		"duration_label": %LeftDurationLabel,
		"seek_slider": %LeftSeekSlider,
		"seek_value_label": %LeftSeekValueLabel,
		"loop_checkbox": %LeftLoopCheckBox,
		"cover_option": %LeftCoverModeOption,
		"audio_slider": %LeftAudioLevelSlider,
		"audio_value_label": %LeftAudioLevelValueLabel,
		"surface": %LeftSurface,
	},
	SLOT_RIGHT: {
		"path_label": %RightPathLabel,
		"backend_label": %RightBackendLabel,
		"playback_label": %RightPlaybackLabel,
		"position_label": %RightPositionLabel,
		"duration_label": %RightDurationLabel,
		"seek_slider": %RightSeekSlider,
		"seek_value_label": %RightSeekValueLabel,
		"loop_checkbox": %RightLoopCheckBox,
		"cover_option": %RightCoverModeOption,
		"audio_slider": %RightAudioLevelSlider,
		"audio_value_label": %RightAudioLevelValueLabel,
		"surface": %RightSurface,
	},
}

var _manager: AeroVideoPlayerManager
var _slot_slider_updates := {
	SLOT_LEFT: false,
	SLOT_RIGHT: false,
}
var _slot_audio_slider_updates := {
	SLOT_LEFT: false,
	SLOT_RIGHT: false,
}
var _slot_cover_updates := {
	SLOT_LEFT: false,
	SLOT_RIGHT: false,
}
var _external_sample_dir: String = ""
var _external_sample_path: String = ""

func _ready() -> void:
	_prepare_external_sample()
	resized.connect(_on_testbed_resized)
	_update_responsive_layout()
	for slot_name in SLOT_NAMES:
		var ui: Dictionary = slot_ui.get(slot_name, {})
		var path_label: Label = ui.get("path_label")
		var seek_slider: HSlider = ui.get("seek_slider")
		var seek_value_label: Label = ui.get("seek_value_label")
		var cover_option: OptionButton = ui.get("cover_option")
		var audio_slider: HSlider = ui.get("audio_slider")
		var audio_value_label: Label = ui.get("audio_value_label")
		path_label.text = SAMPLE_VIDEO_PROJECT_PATH
		seek_slider.min_value = 0.0
		seek_slider.step = 0.01
		seek_slider.editable = false
		seek_slider.value = 0.0
		seek_value_label.text = _format_seconds(0.0)
		cover_option.clear()
		for mode in FIT_MODE_OPTIONS:
			cover_option.add_item(mode.capitalize(), FIT_MODE_OPTIONS.find(mode))
		audio_slider.min_value = 0.0
		audio_slider.max_value = 1.0
		audio_slider.step = 0.01
		audio_slider.value = AeroVideoPlayerManager.DEFAULT_AUDIO_LEVEL
		audio_value_label.text = _format_audio_level(AeroVideoPlayerManager.DEFAULT_AUDIO_LEVEL)
		_inject_source_controls(slot_name)

	var backend_bridge := GodotBackendBridgeScript.new()
	_manager = backend_bridge.create_manager()
	add_child(_manager)
	_manager.slot_state_changed.connect(_on_slot_state_changed)
	_manager.slot_media_loaded.connect(_on_slot_media_loaded)
	_manager.slot_position_changed.connect(_on_slot_position_changed)
	_manager.slot_error_raised.connect(_on_slot_error_raised)

	for slot_name in SLOT_NAMES:
		var ui: Dictionary = slot_ui.get(slot_name, {})
		var surface: Control = ui.get("surface")
		_manager.attach_surface(surface, slot_name)
		_manager.set_loop(bool((ui.get("loop_checkbox") as CheckBox).button_pressed), slot_name)
		_manager.set_fit_mode(FIT_MODE_OPTIONS[(ui.get("cover_option") as OptionButton).selected], slot_name)
		_manager.set_audio_level((ui.get("audio_slider") as HSlider).value, slot_name)
		_load_project_source(slot_name)

	_sync_global_ui()

func _exit_tree() -> void:
	if not _external_sample_path.is_empty() and FileAccess.file_exists(_external_sample_path):
		DirAccess.remove_absolute(_external_sample_path)
	if not _external_sample_dir.is_empty() and DirAccess.dir_exists_absolute(_external_sample_dir):
		DirAccess.remove_absolute(_external_sample_dir)

func _prepare_external_sample() -> void:
	_external_sample_dir = OS.get_cache_dir().path_join("aerobeat-tool-video-player-testbed")
	DirAccess.make_dir_recursive_absolute(_external_sample_dir)
	_external_sample_path = _external_sample_dir.path_join("calm_blue_sea_1.ogv")
	if not FileAccess.file_exists(_external_sample_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAMPLE_VIDEO_PATH), _external_sample_path)

func _inject_source_controls(slot_name: String) -> void:
	var ui: Dictionary = slot_ui.get(slot_name, {})
	var surface: Control = ui.get("surface")
	if surface == null:
		return
	var column := _find_slot_column(surface)
	if column == null:
		return
	var path_label: Label = ui.get("path_label")

	var source_row := HBoxContainer.new()
	source_row.name = "%sSourceRow" % slot_name.capitalize()
	source_row.add_theme_constant_override("separation", 8)

	var source_input := LineEdit.new()
	source_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_input.placeholder_text = "Package path, device path, or URL"
	source_input.text = SAMPLE_VIDEO_PROJECT_PATH
	source_row.add_child(source_input)

	var duration_spin := SpinBox.new()
	duration_spin.custom_minimum_size = Vector2(110, 0)
	duration_spin.min_value = 0.0
	duration_spin.max_value = 36000.0
	duration_spin.step = 0.01
	duration_spin.value = SAMPLE_DURATION_SECONDS
	source_row.add_child(duration_spin)

	var load_button := Button.new()
	load_button.text = "Load path"
	load_button.pressed.connect(_load_slot_from_input.bind(slot_name))
	source_row.add_child(load_button)

	var preset_row := HBoxContainer.new()
	preset_row.name = "%sPresetRow" % slot_name.capitalize()
	preset_row.add_theme_constant_override("separation", 8)

	var packaged_button := Button.new()
	packaged_button.text = "Packaged"
	packaged_button.pressed.connect(_load_project_source.bind(slot_name))
	preset_row.add_child(packaged_button)

	var external_button := Button.new()
	external_button.text = "Device file"
	external_button.pressed.connect(_load_external_source.bind(slot_name))
	preset_row.add_child(external_button)

	var url_button := Button.new()
	url_button.text = "URL"
	url_button.pressed.connect(_load_url_source.bind(slot_name))
	preset_row.add_child(url_button)

	var timeline_hint := Label.new()
	timeline_hint.text = "Timeline: click or drag to seek"
	timeline_hint.name = "%sTimelineHint" % slot_name.capitalize()

	column.add_child(source_row)
	column.move_child(source_row, path_label.get_index() + 1)
	column.add_child(preset_row)
	column.move_child(preset_row, source_row.get_index() + 1)
	column.add_child(timeline_hint)
	var seek_row := (ui.get("seek_slider") as HSlider).get_parent()
	column.move_child(timeline_hint, seek_row.get_index() + 1)

	ui["source_input"] = source_input
	ui["duration_spin"] = duration_spin
	slot_ui[slot_name] = ui

func _process(_delta: float) -> void:
	if _manager == null:
		return
	for slot_name in SLOT_NAMES:
		_sync_slot_ui(slot_name)
	_sync_global_ui()

func _on_testbed_resized() -> void:
	_update_responsive_layout()

func _update_responsive_layout() -> void:
	if slots_row == null:
		return
	slots_row.vertical = size.x < RESPONSIVE_STACK_BREAKPOINT

func _find_slot_column(surface: Control) -> VBoxContainer:
	var current: Node = surface
	while current != null:
		if current is VBoxContainer:
			return current as VBoxContainer
		current = current.get_parent()
	return null

func _load_project_source(slot_name: String) -> void:
	_set_slot_source_input(slot_name, SAMPLE_VIDEO_PROJECT_PATH, SAMPLE_DURATION_SECONDS)
	_load_source(slot_name, SAMPLE_VIDEO_PROJECT_PATH, "project_relative")

func _load_external_source(slot_name: String) -> void:
	_set_slot_source_input(slot_name, _external_sample_path, SAMPLE_DURATION_SECONDS)
	_load_source(slot_name, _external_sample_path, "absolute_device_path")

func _load_url_source(slot_name: String) -> void:
	_set_slot_source_input(slot_name, SAMPLE_REMOTE_URL, SAMPLE_DURATION_SECONDS)
	_load_source(slot_name, SAMPLE_REMOTE_URL, "url")

func _load_slot_from_input(slot_name: String) -> void:
	var ui: Dictionary = slot_ui.get(slot_name, {})
	var source_input: LineEdit = ui.get("source_input")
	if source_input == null:
		return
	_load_source(slot_name, source_input.text, "manual")

func _load_source(slot_name: String, path: String, source_variant: String) -> void:
	if _manager == null:
		return
	_manager.set_active_slot(slot_name)
	var ui: Dictionary = slot_ui.get(slot_name, {})
	var loop_checkbox: CheckBox = ui.get("loop_checkbox")
	var cover_option: OptionButton = ui.get("cover_option")
	var audio_slider: HSlider = ui.get("audio_slider")
	var fit_mode: String = FIT_MODE_OPTIONS[clampi(cover_option.selected, 0, FIT_MODE_OPTIONS.size() - 1)]
	var duration_hint := _selected_duration_hint(slot_name)
	var path_label: Label = ui.get("path_label")
	if path_label != null:
		path_label.text = path
	_manager.load({
		"path": path,
		"slot": slot_name,
		"loop": loop_checkbox.button_pressed,
		"fit_mode": fit_mode,
		"audio_level": audio_slider.value,
		"duration_hint": duration_hint,
		"metadata": {
			"source": "video_player_testbed",
			"source_variant": source_variant,
			"real_sample": path in [SAMPLE_VIDEO_PATH, SAMPLE_VIDEO_PROJECT_PATH, _external_sample_path, SAMPLE_REMOTE_URL],
			"duration_source": "manual_or_fixture",
			"slot": slot_name,
		},
	}, slot_name)

func _on_slot_state_changed(slot_name: String, _state: String, detail: Dictionary) -> void:
	if detail.has("surface_path"):
		status_label.text = "State update for %s | Surface: %s" % [slot_name, String(detail.get("surface_path", ""))]
	_sync_slot_ui(slot_name)
	_sync_global_ui()

func _on_slot_media_loaded(slot_name: String, info: Dictionary) -> void:
	status_label.text = "Loaded %s into %s (%s)" % [String(info.get("path", "")), slot_name, _format_seconds(float(info.get("duration", 0.0)))]
	_sync_slot_ui(slot_name)
	_sync_global_ui()

func _on_slot_position_changed(slot_name: String, _seconds: float, _normalized: float) -> void:
	_sync_slot_ui(slot_name)

func _on_slot_error_raised(slot_name: String, error_info: Dictionary) -> void:
	status_label.text = "Error on %s: %s" % [slot_name, String(error_info.get("message", "Unknown error"))]
	_sync_slot_ui(slot_name)
	_sync_global_ui()

func _sync_global_ui() -> void:
	if _manager == null:
		return
	active_slot_label.text = "Active slot: %s | Slots: %s" % [_manager.get_active_slot(), ", ".join(_manager.get_slot_names())]

func _sync_slot_ui(slot_name: String) -> void:
	if _manager == null:
		return
	var ui: Dictionary = slot_ui.get(slot_name, {})
	var state := _manager.get_state(slot_name)
	var position := _manager.get_position(slot_name)
	var duration := _manager.get_duration(slot_name)
	var audio: Dictionary = state.get("audio", {}) if typeof(state.get("audio", {})) == TYPE_DICTIONARY else {}
	var backend_label: Label = ui.get("backend_label")
	var playback_label: Label = ui.get("playback_label")
	var position_label: Label = ui.get("position_label")
	var duration_label: Label = ui.get("duration_label")
	var seek_slider: HSlider = ui.get("seek_slider")
	var seek_value_label: Label = ui.get("seek_value_label")
	var loop_checkbox: CheckBox = ui.get("loop_checkbox")
	var cover_option: OptionButton = ui.get("cover_option")
	var audio_slider: HSlider = ui.get("audio_slider")
	var audio_value_label: Label = ui.get("audio_value_label")
	backend_label.text = "Backend: %s" % String(state.get("backend", "unknown"))
	playback_label.text = "Playback: %s | Loop: %s | Fit: %s | Audio: %s | Resolved: %s" % [
		String(state.get("state", "idle")),
		"on" if bool(state.get("loop", false)) else "off",
		String(state.get("fit_mode", AeroVideoPlayerManager.DEFAULT_FIT_MODE)),
		_format_audio_level(float(audio.get("audio_level", state.get("audio_level", AeroVideoPlayerManager.DEFAULT_AUDIO_LEVEL)))),
		String(_manager.get_media_info(slot_name).get("resolved_path", _manager.get_media_info(slot_name).get("path", ""))),
	]
	position_label.text = "Position: %s" % _format_seconds(position)
	duration_label.text = "Duration: %s" % _format_seconds(duration)
	seek_slider.editable = duration > 0.0
	seek_slider.max_value = maxf(duration, 0.0)
	_slot_slider_updates[slot_name] = true
	seek_slider.value = clampf(position, seek_slider.min_value, seek_slider.max_value)
	seek_value_label.text = _format_seconds(seek_slider.value)
	loop_checkbox.set_pressed_no_signal(bool(state.get("loop", false)))
	_slot_slider_updates[slot_name] = false
	_slot_cover_updates[slot_name] = true
	cover_option.select(FIT_MODE_OPTIONS.find(String(state.get("fit_mode", AeroVideoPlayerManager.DEFAULT_FIT_MODE))))
	_slot_cover_updates[slot_name] = false
	_slot_audio_slider_updates[slot_name] = true
	audio_slider.value = float(audio.get("audio_level", state.get("audio_level", AeroVideoPlayerManager.DEFAULT_AUDIO_LEVEL)))
	audio_value_label.text = _format_audio_level(audio_slider.value)
	_slot_audio_slider_updates[slot_name] = false

func _format_seconds(seconds: float) -> String:
	var clamped := maxf(seconds, 0.0)
	var minutes := int(floor(clamped / 60.0))
	var remainder := clamped - float(minutes * 60)
	return "%02d:%05.2f" % [minutes, remainder]

func _format_audio_level(value: float) -> String:
	return "%.0f%%" % (clampf(value, 0.0, 1.0) * 100.0)

func _selected_duration_hint(slot_name: String) -> float:
	var spin: SpinBox = slot_ui.get(slot_name, {}).get("duration_spin")
	return float(spin.value) if spin != null else SAMPLE_DURATION_SECONDS

func _set_slot_source_input(slot_name: String, path: String, duration_hint: float) -> void:
	var ui: Dictionary = slot_ui.get(slot_name, {})
	var source_input: LineEdit = ui.get("source_input")
	var duration_spin: SpinBox = ui.get("duration_spin")
	if source_input != null:
		source_input.text = path
	if duration_spin != null:
		duration_spin.value = duration_hint

func _seek_by(slot_name: String, delta_seconds: float) -> void:
	if _manager == null or _manager.get_duration(slot_name) <= 0.0:
		return
	_manager.set_active_slot(slot_name)
	_manager.seek(clampf(_manager.get_position(slot_name) + delta_seconds, 0.0, _manager.get_duration(slot_name)), slot_name)

func _on_left_load_button_pressed() -> void:
	_load_slot_from_input(SLOT_LEFT)

func _on_left_play_button_pressed() -> void:
	_manager.set_active_slot(SLOT_LEFT)
	_manager.play(SLOT_LEFT)

func _on_left_pause_button_pressed() -> void:
	_manager.set_active_slot(SLOT_LEFT)
	_manager.pause(SLOT_LEFT)

func _on_left_stop_button_pressed() -> void:
	_manager.set_active_slot(SLOT_LEFT)
	_manager.stop(SLOT_LEFT)

func _on_left_unload_button_pressed() -> void:
	_manager.set_active_slot(SLOT_LEFT)
	_manager.unload(SLOT_LEFT)

func _on_left_seek_back_button_pressed() -> void:
	_seek_by(SLOT_LEFT, -SEEK_STEP_SECONDS)

func _on_left_seek_forward_button_pressed() -> void:
	_seek_by(SLOT_LEFT, SEEK_STEP_SECONDS)

func _on_left_seek_slider_value_changed(value: float) -> void:
	if bool(_slot_slider_updates.get(SLOT_LEFT, false)):
		return
	(slot_ui[SLOT_LEFT].get("seek_value_label") as Label).text = _format_seconds(value)

func _on_left_seek_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed:
		return
	_manager.set_active_slot(SLOT_LEFT)
	_manager.seek((slot_ui[SLOT_LEFT].get("seek_slider") as HSlider).value, SLOT_LEFT)

func _on_left_loop_check_box_toggled(toggled_on: bool) -> void:
	_manager.set_active_slot(SLOT_LEFT)
	_manager.set_loop(toggled_on, SLOT_LEFT)

func _on_left_fit_mode_option_item_selected(index: int) -> void:
	if bool(_slot_cover_updates.get(SLOT_LEFT, false)):
		return
	_manager.set_active_slot(SLOT_LEFT)
	_manager.set_fit_mode(FIT_MODE_OPTIONS[index], SLOT_LEFT)

func _on_left_cover_mode_option_item_selected(index: int) -> void:
	_on_left_fit_mode_option_item_selected(index)

func _on_left_audio_level_slider_value_changed(value: float) -> void:
	if bool(_slot_audio_slider_updates.get(SLOT_LEFT, false)):
		return
	(slot_ui[SLOT_LEFT].get("audio_value_label") as Label).text = _format_audio_level(value)
	_manager.set_active_slot(SLOT_LEFT)
	_manager.set_audio_level(value, SLOT_LEFT)

func _on_right_load_button_pressed() -> void:
	_load_slot_from_input(SLOT_RIGHT)

func _on_right_play_button_pressed() -> void:
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.play(SLOT_RIGHT)

func _on_right_pause_button_pressed() -> void:
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.pause(SLOT_RIGHT)

func _on_right_stop_button_pressed() -> void:
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.stop(SLOT_RIGHT)

func _on_right_unload_button_pressed() -> void:
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.unload(SLOT_RIGHT)

func _on_right_seek_back_button_pressed() -> void:
	_seek_by(SLOT_RIGHT, -SEEK_STEP_SECONDS)

func _on_right_seek_forward_button_pressed() -> void:
	_seek_by(SLOT_RIGHT, SEEK_STEP_SECONDS)

func _on_right_seek_slider_value_changed(value: float) -> void:
	if bool(_slot_slider_updates.get(SLOT_RIGHT, false)):
		return
	(slot_ui[SLOT_RIGHT].get("seek_value_label") as Label).text = _format_seconds(value)

func _on_right_seek_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed:
		return
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.seek((slot_ui[SLOT_RIGHT].get("seek_slider") as HSlider).value, SLOT_RIGHT)

func _on_right_loop_check_box_toggled(toggled_on: bool) -> void:
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.set_loop(toggled_on, SLOT_RIGHT)

func _on_right_fit_mode_option_item_selected(index: int) -> void:
	if bool(_slot_cover_updates.get(SLOT_RIGHT, false)):
		return
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.set_fit_mode(FIT_MODE_OPTIONS[index], SLOT_RIGHT)

func _on_right_cover_mode_option_item_selected(index: int) -> void:
	_on_right_fit_mode_option_item_selected(index)

func _on_right_audio_level_slider_value_changed(value: float) -> void:
	if bool(_slot_audio_slider_updates.get(SLOT_RIGHT, false)):
		return
	(slot_ui[SLOT_RIGHT].get("audio_value_label") as Label).text = _format_audio_level(value)
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.set_audio_level(value, SLOT_RIGHT)
