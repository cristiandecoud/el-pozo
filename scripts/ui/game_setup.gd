extends Control

const MIN_BOTS := 1
const MAX_BOTS := 4

var _bot_count: int = 1

@onready var name_input: LineEdit = $Panel/NameInput
@onready var bots_count: Label    = $Panel/BotsRow/BotsCount
@onready var bot_minus: Button    = $Panel/BotsRow/BotMinus
@onready var bot_plus: Button     = $Panel/BotsRow/BotPlus
@onready var start_btn: Button    = $Panel/Buttons/StartBtn
@onready var back_btn: Button     = $Panel/Buttons/BackBtn

func _ready() -> void:
	name_input.text = SaveData.get_setting("last_player_name", "") as String
	_update_bots_ui()

	bot_minus.pressed.connect(func():
		_bot_count = max(MIN_BOTS, _bot_count - 1)
		_update_bots_ui())
	bot_plus.pressed.connect(func():
		_bot_count = min(MAX_BOTS, _bot_count + 1)
		_update_bots_ui())
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file(
			"res://escenas/ui/main_menu/main_menu.tscn"))

func _update_bots_ui() -> void:
	bots_count.text = str(_bot_count)
	bot_minus.disabled = _bot_count <= MIN_BOTS
	bot_plus.disabled  = _bot_count >= MAX_BOTS

func _on_start() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	SaveData.start_session(player_name, _bot_count)
	get_tree().change_scene_to_file("res://escenas/game/game.tscn")
