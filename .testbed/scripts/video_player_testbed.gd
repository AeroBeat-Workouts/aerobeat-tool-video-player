extends Control

const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"
const SAMPLE_DURATION_SECONDS := 28.693313
const SEEK_STEP_SECONDS := 5.0
const GodotBackendScript := preload("res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd")

@onready var path_label: Label = %PathLabel
@onready var backend_label: Label = %BackendLabel
@onready var status_label: Label = %StatusLabel
@onready var playback_label: Label = %PlaybackLabel
@onready var position_label: Label = %PositionLabel
@onready var duration_label: Label = %DurationLabel
@onready var seek_slider: HSlider = %SeekSlider
@onready var seek_value_label: Label = %SeekValueLabel
@onready var surface: Control = %Surface

var _manager: AeroVideoPlayerManager
var _is_updating_seek_slider: bool = false

func _ready() -> void:
	path_label.text = SAMPLE_VIDEO_PATH
	seek_slider.min_value = 0.0
	seek_slider.step = 0.01
	seek_slider.editable = false
	seek_slider.value = 0.0
	seek_value_label.text = _format_seconds(0.0)

	_manager = AeroVideoPlayerManager.new()
	_manager.set_backend(GodotBackendScript.new())
	add_child(_manager)
	_manager.state_changed.connect(_on_state_changed)
	_manager.media_loaded.connect(_on_media_loaded)
	_manager.position_changed.connect(_on_position_changed)
	_manager.error_raised.connect(_on_error_raised)
	_manager.attach_surface(surface)
	_load_sample()

func _process(_delta: float) -> void:
	if _manager == null:
		return
	_sync_transport_ui()

func _load_sample() -> void:
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": SAMPLE_DURATION_SECONDS,
		"metadata": {
			"source": "video_player_testbed",
			"real_sample": true,
			"duration_source": "ffprobe_2026-05-24",
		},
	})

func _on_state_changed(state: String, detail: Dictionary) -> void:
	status_label.text = "State: %s" % state
	if detail.has("surface_path"):
		status_label.text += " | Surface: %s" % String(detail.get("surface_path", ""))
	_sync_transport_ui()

func _on_media_loaded(info: Dictionary) -> void:
	status_label.text = "Loaded %s (%s)" % [String(info.get("path", "")), _format_seconds(float(info.get("duration", 0.0)))]
	_sync_transport_ui()

func _on_position_changed(_seconds: float, _normalized: float) -> void:
	_sync_transport_ui()

func _on_error_raised(error_info: Dictionary) -> void:
	status_label.text = "Error: %s" % String(error_info.get("message", "Unknown error"))
	_sync_transport_ui()

func _sync_transport_ui() -> void:
	if _manager == null:
		return
	var state := _manager.get_state()
	var position := _manager.get_position()
	var duration := _manager.get_duration()
	backend_label.text = "Backend: %s" % String(state.get("backend", "unknown"))
	playback_label.text = "Playback: %s" % String(state.get("state", "idle"))
	position_label.text = "Position: %s" % _format_seconds(position)
	duration_label.text = "Duration: %s" % _format_seconds(duration)
	seek_slider.editable = duration > 0.0
	seek_slider.max_value = maxf(duration, 0.0)
	_is_updating_seek_slider = true
	seek_slider.value = clampf(position, seek_slider.min_value, seek_slider.max_value)
	seek_value_label.text = _format_seconds(seek_slider.value)
	_is_updating_seek_slider = false

func _format_seconds(seconds: float) -> String:
	var clamped := maxf(seconds, 0.0)
	var minutes := int(floor(clamped / 60.0))
	var remainder := clamped - float(minutes * 60)
	return "%02d:%05.2f" % [minutes, remainder]

func _seek_by(delta_seconds: float) -> void:
	if _manager == null or _manager.get_duration() <= 0.0:
		return
	_manager.seek(clampf(_manager.get_position() + delta_seconds, 0.0, _manager.get_duration()))

func _on_load_button_pressed() -> void:
	_load_sample()

func _on_play_button_pressed() -> void:
	_manager.play()

func _on_pause_button_pressed() -> void:
	_manager.pause()

func _on_stop_button_pressed() -> void:
	_manager.stop()

func _on_seek_back_button_pressed() -> void:
	_seek_by(-SEEK_STEP_SECONDS)

func _on_seek_forward_button_pressed() -> void:
	_seek_by(SEEK_STEP_SECONDS)

func _on_seek_slider_value_changed(value: float) -> void:
	if _is_updating_seek_slider:
		return
	seek_value_label.text = _format_seconds(value)

func _on_seek_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed:
		return
	_manager.seek(seek_slider.value)
