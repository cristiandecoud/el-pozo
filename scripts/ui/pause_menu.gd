class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var resume_btn: Button    = $Root/Panel/VBox/ResumeBtn
@onready var restart_btn: Button   = $Root/Panel/VBox/RestartBtn
@onready var settings_btn: Button  = $Root/Panel/VBox/SettingsBtn
@onready var main_menu_btn: Button = $Root/Panel/VBox/MainMenuBtn

func _ready() -> void:
	resume_btn.pressed.connect(func(): resume_requested.emit())
	restart_btn.pressed.connect(func(): restart_requested.emit())
	main_menu_btn.pressed.connect(func(): main_menu_requested.emit())
	# Settings overlay: implementado en fase 24
	settings_btn.pressed.connect(func(): pass)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
