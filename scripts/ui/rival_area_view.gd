class_name RivalAreaView
extends PanelContainer

signal inspect_requested(player: Player)

var _player: Player

@onready var color_bar:  ColorRect     = $Margin/VBox/Header/ColorBar
@onready var name_label: Label         = $Margin/VBox/Header/NameLabel
@onready var well_card:  Label         = $Margin/VBox/WellRow/WellCard
@onready var hand_count: Label         = $Margin/VBox/HandCount
@onready var board_tops: HBoxContainer = $Margin/VBox/BoardTops

func setup(player: Player) -> void:
	_player = player
	mouse_entered.connect(func(): inspect_requested.emit(_player))
	gui_input.connect(_on_gui_input)
	refresh()

func refresh() -> void:
	var player_color := SaveData.get_player_color(_player.player_number)
	color_bar.color  = player_color
	name_label.text  = _player.name
	name_label.add_theme_color_override("font_color", player_color)
	var top          := _player.well_top()
	if top == null:
		well_card.text = "GANÓ"
	else:
		well_card.text = top.display_value() + " " + top.suit_symbol()
	hand_count.text  = "Mano: " + str(_player.hand.size())
	_rebuild_board_tops()

func set_active(active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1a1a")
	if active:
		style.border_color = SaveData.get_player_color(_player.player_number)
		style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

func _rebuild_board_tops() -> void:
	for child in board_tops.get_children():
		child.queue_free()
	for i in range(_player.board.size()):
		var top := _player.board_top(i)
		if top == null:
			continue
		var lbl := Label.new()
		lbl.text = top.display_value()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.custom_minimum_size = Vector2(24, 0)
		board_tops.add_child(lbl)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		inspect_requested.emit(_player)

