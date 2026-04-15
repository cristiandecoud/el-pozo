extends Control

@onready var play_btn: Button     = $Content/PlayBtn
@onready var stats_btn: Button    = $Content/StatsBtn
@onready var settings_btn: Button = $Content/SettingsBtn

func _ready() -> void:
	play_btn.pressed.connect(func():
		get_tree().change_scene_to_file(
			"res://escenas/ui/game_setup/game_setup.tscn"))
	stats_btn.pressed.connect(func():
		get_tree().change_scene_to_file(
			"res://escenas/ui/stats/stats_screen.tscn"))
	settings_btn.pressed.connect(func():
		get_tree().change_scene_to_file(
			"res://escenas/ui/settings/settings_screen.tscn"))
