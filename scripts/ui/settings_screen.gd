extends Control

@onready var font_slider: HSlider     = $Panel/FontSizeRow/FontSlider
@onready var speed_slider: HSlider    = $Panel/SpeedRow/SpeedSlider
@onready var theme_opt: OptionButton  = $Panel/ThemeRow/ThemeOpt
@onready var save_btn: Button         = $Panel/Buttons/SaveBtn
@onready var back_btn: Button         = $Panel/Buttons/BackBtn

func _ready() -> void:
	font_slider.value  = SaveData.get_setting("font_size", 14)
	speed_slider.value = SaveData.get_setting("animation_speed", 1.0)

	theme_opt.clear()
	theme_opt.add_item("Clásico")

	save_btn.pressed.connect(_on_save)
	back_btn.pressed.connect(_go_back)

func _on_save() -> void:
	SaveData.set_setting("font_size", int(font_slider.value))
	SaveData.set_setting("animation_speed", speed_slider.value)
	SaveData.set_setting("card_theme", "classic")
	_go_back()

func _go_back() -> void:
	get_tree().change_scene_to_file(
		"res://escenas/ui/main_menu/main_menu.tscn")
