extends Control

const MIN_BOTS := 1
const MAX_BOTS := 4

const PLAYER_COLORS: Array[Color] = [
	Color("#F5C518"),  # Dorado
	Color("#3B82F6"),  # Azul
	Color("#22C55E"),  # Verde
	Color("#EF4444"),  # Rojo
	Color("#A855F7"),  # Violeta
]

var _bot_count:      int   = 1
var _selected_color: Color = PLAYER_COLORS[0]

@onready var name_input: LineEdit      = $Panel/NameInput
@onready var color_row:  HBoxContainer = $Panel/ColorRow
@onready var bots_count: Label         = $Panel/BotsRow/BotsCount
@onready var bot_minus:  Button        = $Panel/BotsRow/BotMinus
@onready var bot_plus:   Button        = $Panel/BotsRow/BotPlus
@onready var start_btn:  Button        = $Panel/Buttons/StartBtn
@onready var back_btn:   Button        = $Panel/Buttons/BackBtn

func _ready() -> void:
	name_input.text = SaveData.get_setting("last_player_name", "") as String
	_setup_color_buttons()
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

func _setup_color_buttons() -> void:
	for i in range(color_row.get_child_count()):
		var btn: Button = color_row.get_child(i)
		var col: Color  = PLAYER_COLORS[i]
		btn.pressed.connect(func(): _select_color(col))
	_select_color(PLAYER_COLORS[0])

func _select_color(col: Color) -> void:
	_selected_color = col
	for i in range(color_row.get_child_count()):
		var btn:   Button       = color_row.get_child(i)
		btn.flat                = false
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color          = PLAYER_COLORS[i]
		style.set_corner_radius_all(8)
		if PLAYER_COLORS[i].is_equal_approx(col):
			style.border_color = Color.WHITE
			style.set_border_width_all(4)
		btn.add_theme_stylebox_override("normal",  style)
		btn.add_theme_stylebox_override("hover",   style)
		btn.add_theme_stylebox_override("pressed", style)

func _update_bots_ui() -> void:
	bots_count.text    = str(_bot_count)
	bot_minus.disabled = _bot_count <= MIN_BOTS
	bot_plus.disabled  = _bot_count >= MAX_BOTS

func _on_start() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	SaveData.start_session(player_name, _selected_color, _bot_count)
	get_tree().change_scene_to_file("res://escenas/game/game.tscn")
