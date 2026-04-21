class_name RivalBoardOverlay
extends CanvasLayer

@onready var shield:        ColorRect     = $Shield
@onready var color_bar:     ColorRect     = $Panel/Margin/VBox/Header/ColorBar
@onready var player_name:   Label         = $Panel/Margin/VBox/Header/PlayerName
@onready var board_display: HBoxContainer = $Panel/Margin/VBox/Scroll/BoardDisplay

func setup(player: Player) -> void:
	var player_color := SaveData.get_player_color(player.player_number)
	color_bar.color  = player_color
	player_name.text = player.name
	player_name.add_theme_color_override("font_color", player_color)
	_build_board(player)
	shield.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			queue_free())

func _build_board(player: Player) -> void:
	for child in board_display.get_children():
		child.queue_free()
	var columns := player.get_board_columns()
	if columns.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(tablero vacío)"
		empty_lbl.add_theme_color_override("font_color", Color("#888888"))
		board_display.add_child(empty_lbl)
		return
	for col in columns:
		if col.is_empty():
			continue
		var col_box := VBoxContainer.new()
		col_box.custom_minimum_size = Vector2(52, 0)
		for card in col:
			var lbl := Label.new()
			lbl.text = card.display_value() + card.suit_symbol()
			lbl.add_theme_font_size_override("font_size", 14)
			col_box.add_child(lbl)
		board_display.add_child(col_box)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
