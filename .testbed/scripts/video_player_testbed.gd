extends Control

const SAMPLE_VIDEO_PATH := "res://assets/videos/calm_blue_sea_1.ogv"

@onready var status_label: Label = %StatusLabel
@onready var path_label: Label = %PathLabel
@onready var surface: ColorRect = %Surface

var _manager: AeroVideoPlayerManager

func _ready() -> void:
	path_label.text = SAMPLE_VIDEO_PATH
	_manager = AeroVideoPlayerManager.new()
	add_child(_manager)
	_manager.state_changed.connect(_on_state_changed)
	_manager.media_loaded.connect(_on_media_loaded)
	_manager.error_raised.connect(_on_error_raised)
	_manager.attach_surface(surface)
	_manager.load({
		"path": SAMPLE_VIDEO_PATH,
		"duration_hint": 12.0,
		"metadata": {
			"source": "video_player_testbed",
			"real_sample": true,
		},
	})

func _on_state_changed(state: String, detail: Dictionary) -> void:
	status_label.text = "State: %s" % state
	if detail.has("surface_path"):
		status_label.text += " | Surface: %s" % String(detail.get("surface_path", ""))

func _on_media_loaded(info: Dictionary) -> void:
	status_label.text = "Loaded %s (%ss)" % [String(info.get("path", "")), str(info.get("duration", 0.0))]

func _on_error_raised(error_info: Dictionary) -> void:
	status_label.text = "Error: %s" % String(error_info.get("message", "Unknown error"))

func _on_load_button_pressed() -> void:
	_manager.load({"path": SAMPLE_VIDEO_PATH, "duration_hint": 12.0})

func _on_play_button_pressed() -> void:
	_manager.play()

func _on_pause_button_pressed() -> void:
	_manager.pause()

func _on_stop_button_pressed() -> void:
	_manager.stop()
