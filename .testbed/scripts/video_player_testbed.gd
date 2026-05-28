extends Control

const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_DURATION_SECONDS := 28.693313
const SEEK_STEP_SECONDS := 5.0
const SLOT_LEFT := "left"
const SLOT_RIGHT := "right"
const SLOT_NAMES := [SLOT_LEFT, SLOT_RIGHT]
const COVER_MODE_OPTIONS := [
	AeroVideoPlayerManager.COVER_MODE_STRETCH,
	AeroVideoPlayerManager.COVER_MODE_CONTAIN,
	AeroVideoPlayerManager.COVER_MODE_COVER,
]
const GodotBackendScript := preload("res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd")

@onready var status_label: Label = %StatusLabel
@onready var active_slot_label: Label = %ActiveSlotLabel
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
		"cover_option": %LeftCoverOptionButton,
		"audio_slider": %LeftAudioSlider,
		"audio_value_label": %LeftAudioValueLabel,
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
		"cover_option": %RightCoverOptionButton,
		"audio_slider": %RightAudioSlider,
		"audio_value_label": %RightAudioValueLabel,
		"surface": %RightSurface,
	},
}

var _manager: AeroVideoPlayerManager
var _slot_slider_updates := {
	SLOT_LEFT: false,
	SLOT_RIGHT: false,
}
var _slot_cover_updates := {
	SLOT_LEFT: false,
	SLOT_RIGHT: false,
}
var _slot_audio_updates := {
	SLOT_LEFT: false,
	SLOT_RIGHT: false,
}

func _ready() -> void:
	for slot_name in SLOT_NAMES:
		var ui: Dictionary = slot_ui.get(slot_name, {})
		var path_label: Label = ui.get("path_label")
		var seek_slider: HSlider = ui.get("seek_slider")
		var seek_value_label: Label = ui.get("seek_value_label")
		var cover_option: OptionButton = ui.get("cover_option")
		var audio_slider: HSlider = ui.get("audio_slider")
		var audio_value_label: Label = ui.get("audio_value_label")
		path_label.text = SAMPLE_VIDEO_PATH
		seek_slider.min_value = 0.0
		seek_slider.step = 0.01
		seek_slider.editable = false
		seek_slider.value = 0.0
		seek_value_label.text = _format_seconds(0.0)
		cover_option.clear()
		for cover_mode in COVER_MODE_OPTIONS:
			cover_option.add_item(_cover_mode_label(cover_mode))
		audio_slider.min_value = 0.0
		audio_slider.max_value = 1.0
		audio_slider.step = 0.01
		audio_slider.value = 1.0
		audio_value_label.text = _format_audio_level(1.0)

	_manager = AeroVideoPlayerManager.new()
	_manager.set_backend_factory(Callable(self, "_create_backend"))
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
		_manager.set_cover_mode(AeroVideoPlayerManager.DEFAULT_COVER_MODE, slot_name)
		_manager.set_audio_level((ui.get("audio_slider") as HSlider).value, slot_name)
		_load_sample(slot_name)

	_sync_global_ui()

func _process(_delta: float) -> void:
	if _manager == null:
		return
	for slot_name in SLOT_NAMES:
		_sync_slot_ui(slot_name)
	_sync_global_ui()

func _create_backend() -> AeroVideoPlayerBackend:
	return GodotBackendScript.new()

func _load_sample(slot_name: String) -> void:
	if _manager == null:
		return
	_manager.set_active_slot(slot_name)
	var ui: Dictionary = slot_ui.get(slot_name, {})
	var loop_checkbox: CheckBox = ui.get("loop_checkbox")
	var audio_slider: HSlider = ui.get("audio_slider")
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"slot": slot_name,
		"loop": loop_checkbox.button_pressed,
		"cover_mode": _selected_cover_mode(slot_name),
		"audio_level": audio_slider.value,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"metadata": {
			"source": "video_player_testbed",
			"real_sample": true,
			"duration_source": "ffprobe_2026-05-24",
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
	playback_label.text = "Playback: %s | Loop: %s | Cover: %s | Audio: %s" % [
		String(state.get("state", "idle")),
		"on" if bool(state.get("loop", false)) else "off",
		String(state.get("cover_mode", AeroVideoPlayerManager.DEFAULT_COVER_MODE)),
		_format_audio_level(float(state.get("audio_level", 1.0))),
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
	cover_option.select(_cover_mode_index(String(state.get("cover_mode", AeroVideoPlayerManager.DEFAULT_COVER_MODE))))
	_slot_cover_updates[slot_name] = false
	_slot_audio_updates[slot_name] = true
	audio_slider.value = float(state.get("audio_level", 1.0))
	audio_value_label.text = _format_audio_level(audio_slider.value)
	_slot_audio_updates[slot_name] = false

func _format_seconds(seconds: float) -> String:
	var clamped := maxf(seconds, 0.0)
	var minutes := int(floor(clamped / 60.0))
	var remainder := clamped - float(minutes * 60)
	return "%02d:%05.2f" % [minutes, remainder]

func _format_audio_level(audio_level: float) -> String:
	return "%d%%" % int(round(clampf(audio_level, 0.0, 1.0) * 100.0))

func _seek_by(slot_name: String, delta_seconds: float) -> void:
	if _manager == null or _manager.get_duration(slot_name) <= 0.0:
		return
	_manager.set_active_slot(slot_name)
	_manager.seek(clampf(_manager.get_position(slot_name) + delta_seconds, 0.0, _manager.get_duration(slot_name)), slot_name)

func _cover_mode_index(cover_mode: String) -> int:
	var normalized := String(cover_mode).strip_edges().to_lower()
	var index := COVER_MODE_OPTIONS.find(normalized)
	return index if index >= 0 else COVER_MODE_OPTIONS.find(AeroVideoPlayerManager.DEFAULT_COVER_MODE)

func _cover_mode_label(cover_mode: String) -> String:
	match cover_mode:
		AeroVideoPlayerManager.COVER_MODE_STRETCH:
			return "Stretch"
		AeroVideoPlayerManager.COVER_MODE_COVER:
			return "Cover"
		_:
			return "Contain"

func _selected_cover_mode(slot_name: String) -> String:
	var option: OptionButton = slot_ui.get(slot_name, {}).get("cover_option")
	var selected := option.selected
	if selected < 0 or selected >= COVER_MODE_OPTIONS.size():
		return AeroVideoPlayerManager.DEFAULT_COVER_MODE
	return COVER_MODE_OPTIONS[selected]

func _on_left_load_button_pressed() -> void:
	_load_sample(SLOT_LEFT)

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

func _on_left_cover_option_button_item_selected(_index: int) -> void:
	if bool(_slot_cover_updates.get(SLOT_LEFT, false)):
		return
	_manager.set_active_slot(SLOT_LEFT)
	_manager.set_cover_mode(_selected_cover_mode(SLOT_LEFT), SLOT_LEFT)

func _on_left_audio_slider_value_changed(value: float) -> void:
	(slot_ui[SLOT_LEFT].get("audio_value_label") as Label).text = _format_audio_level(value)
	if bool(_slot_audio_updates.get(SLOT_LEFT, false)):
		return
	_manager.set_active_slot(SLOT_LEFT)
	_manager.set_audio_level(value, SLOT_LEFT)

func _on_right_load_button_pressed() -> void:
	_load_sample(SLOT_RIGHT)

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

func _on_right_cover_option_button_item_selected(_index: int) -> void:
	if bool(_slot_cover_updates.get(SLOT_RIGHT, false)):
		return
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.set_cover_mode(_selected_cover_mode(SLOT_RIGHT), SLOT_RIGHT)

func _on_right_audio_slider_value_changed(value: float) -> void:
	(slot_ui[SLOT_RIGHT].get("audio_value_label") as Label).text = _format_audio_level(value)
	if bool(_slot_audio_updates.get(SLOT_RIGHT, false)):
		return
	_manager.set_active_slot(SLOT_RIGHT)
	_manager.set_audio_level(value, SLOT_RIGHT)
