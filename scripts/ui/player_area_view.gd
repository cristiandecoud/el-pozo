# PlayerAreaView — Complete visual zone for one player
#
# Why it exists:
#   Each player has three card collections: well, board, and hand.
#   PlayerAreaView groups them into a single reusable visual unit. The same
#   scene is instantiated twice in game.gd: once for the human (show_hand = true)
#   and once for the bot (show_hand = false, hand hidden face-down).
#
# What it does:
#   - Shows the player's name and a section header for each zone.
#   - Renders the top card of the well with a golden border (well = win condition).
#   - Renders the top card of each board column as regular CardViews.
#   - Renders the full hand, or face-down cards if show_hand = false.
#   - Emits card_selected when the player clicks any card.
#
# Design:
#   refresh() destroys and recreates all child CardViews on every call.
#   The well card gets a distinct amber border via _apply_well_style() to signal
#   it is the most important zone — emptying it wins the game.
#   Lambdas capture the index with "var idx := i" to avoid closure-in-loop issues.

class_name PlayerAreaView
extends VBoxContainer

signal card_selected(source: GameManager.CardSource, index: int, card: Card)
signal card_drag_started(source: GameManager.CardSource, index: int, card: Card)
# Emitted when the player chooses a board column destination at end of turn.
signal board_dest_selected(col_index: int)

# When false, the hand is shown face-down (used for the bot).
var show_hand: bool = true

# Board destination selection mode — when true, card clicks on the board emit
# board_dest_selected instead of card_selected.
var _board_dest_mode: bool = false
var _new_col_slot: Button = null
var _new_col_idx: int = -1
var _current_player_board: Array = []

@onready var name_label: Label      = $PlayerName
@onready var well_count: Label      = $WellAndBoard/Well/WellCount
@onready var well_top_slot: Control = $WellAndBoard/Well/WellTopSlot
@onready var board_container: HBoxContainer = $WellAndBoard/BoardZone/Board
@onready var hand_container: HBoxContainer  = $HandZone/Hand
@onready var hand_zone: VBoxContainer       = $HandZone

const CardScene := preload("res://escenas/ui/card/card.tscn")

const CARD_W      := 180
const CARD_H      := 260
const STACK_OFFSET := 35   # px between stacked cards in a board column

# Amber border style for the well card — signals it is the win-condition zone.
var _style_well: StyleBoxFlat

func _ready() -> void:
	_style_well = StyleBoxFlat.new()
	_style_well.bg_color = Color("#F8F4E3")
	_style_well.set_border_width_all(3)
	_style_well.border_color = Color("#E8A020")
	_style_well.set_corner_radius_all(6)
	_style_well.set_content_margin_all(6)
	# Clip columns so they never push the layout beyond available height
	board_container.clip_children = CanvasItem.CLIP_CHILDREN_ONLY

# Main entry point — called by game.gd in _refresh_all().
func refresh(player: Player) -> void:
	name_label.text = player.name
	well_count.text = str(player.well.size()) + " cards"

	# Well: only the top card is visible; amber border marks it as the key zone
	for child in well_top_slot.get_children():
		child.queue_free()
	if player.well_top() != null:
		var cv: CardView = CardScene.instantiate()
		cv.card_data = player.well_top()
		cv.add_theme_stylebox_override("panel", _style_well)
		cv.card_clicked.connect(
			func(_v): card_selected.emit(GameManager.CardSource.WELL, 0,
										 player.well_top()))
		cv.card_drag_started.connect(
			func(_v): card_drag_started.emit(GameManager.CardSource.WELL, 0,
											 player.well_top()))
		well_top_slot.add_child(cv)

	# Board: fan layout — all cards visible, only the top card is interactive
	_current_player_board = player.board
	for child in board_container.get_children():
		child.queue_free()
	_new_col_slot = null  # freed by the loop above
	for i in range(player.board.size()):
		var col: Array = player.board[i]
		if col.is_empty():
			continue
		board_container.add_child(_build_board_column(col, i))

	# Hand: visible if human; hidden if bot (bot hand is shown externally in top-left)
	if show_hand:
		hand_zone.visible = true
		_rebuild_cards(hand_container, player.hand,
					   GameManager.CardSource.HAND)
	else:
		hand_zone.visible = false

# Returns the CardView node for the given source and index, or null if not found.
# Used by game.gd to mark the selected card with set_selected().
func get_card_view(source: GameManager.CardSource, index: int) -> CardView:
	match source:
		GameManager.CardSource.HAND:
			var children := hand_container.get_children()
			if index < children.size():
				return children[index] as CardView
		GameManager.CardSource.BOARD:
			# Search by the real board index stored in meta, not visual position,
			# because empty columns are skipped when rendering.
			for child in board_container.get_children():
				if child.has_meta("col_idx") and child.get_meta("col_idx") == index:
					var n := child.get_child_count()
					if n > 0:
						return child.get_child(n - 1) as CardView
		GameManager.CardSource.WELL:
			var children := well_top_slot.get_children()
			if not children.is_empty():
				return children[0] as CardView
	return null

# Highlights the player name in gold when it is their active turn.
func set_active_turn(is_active: bool) -> void:
	if is_active:
		name_label.add_theme_color_override("font_color", Color("#F5C518"))
	else:
		name_label.remove_theme_color_override("font_color")

# Activates or deactivates board-column destination mode.
# When active: board cards emit board_dest_selected and a "+" new-column slot
# is appended so the player can also create a fresh column.
func show_board_destinations(active: bool) -> void:
	_board_dest_mode = active
	if active:
		# Tint existing board children to signal they are selectable
		for child in board_container.get_children():
			child.modulate = Color(0.8, 1.0, 0.85, 1.0)
		# Prefer reusing an existing empty column over creating a new slot,
		# so the index passed to push_to_board is always valid.
		var target_idx := -1
		for i in range(_current_player_board.size()):
			if (_current_player_board[i] as Array).is_empty():
				target_idx = i
				break
		if target_idx == -1:
			target_idx = _current_player_board.size()
		if target_idx < Player.MAX_BOARD_COLUMNS:
			_new_col_idx = target_idx
			_add_new_col_slot(_new_col_idx)
	else:
		# Remove the "+" slot and restore colours
		_new_col_idx = -1
		if _new_col_slot != null:
			_new_col_slot.queue_free()
			_new_col_slot = null
		for child in board_container.get_children():
			child.modulate = Color(1, 1, 1, 1)

# Appends a "+" button to board_container that creates a new column.
func _add_new_col_slot(col_index: int) -> void:
	_new_col_slot = Button.new()
	_new_col_slot.text = "+"
	_new_col_slot.custom_minimum_size = Vector2(60, 90)
	_new_col_slot.pressed.connect(func(): board_dest_selected.emit(col_index))
	board_container.add_child(_new_col_slot)

# Builds a Control that renders all cards in a column as a vertical fan.
# Cards are offset by STACK_OFFSET px each; only the top (last) card is clickable.
func _build_board_column(col: Array, col_idx: int) -> Control:
	var column_ctrl := Control.new()
	column_ctrl.set_meta("col_idx", col_idx)  # used by game.gd for drag-drop detection
	var stack_h := CARD_H + STACK_OFFSET * (col.size() - 1)
	column_ctrl.custom_minimum_size = Vector2(CARD_W, stack_h)

	for i in range(col.size()):
		var cv: CardView = CardScene.instantiate()
		cv.card_data = col[i]
		cv.position = Vector2(0, STACK_OFFSET * i)
		cv.custom_minimum_size = Vector2(CARD_W, CARD_H)

		if i < col.size() - 1:
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			# Top card — interactive
			var idx := col_idx
			cv.card_clicked.connect(func(_v):
				if _board_dest_mode:
					board_dest_selected.emit(idx)
				else:
					card_selected.emit(GameManager.CardSource.BOARD, idx, col.back()))
			cv.card_drag_started.connect(func(_v):
				card_drag_started.emit(GameManager.CardSource.BOARD, idx, col.back()))

		column_ctrl.add_child(cv)

	return column_ctrl

# Rebuilds a container of CardViews from an array of cards.
func _rebuild_cards(container: HBoxContainer, cards: Array[Card],
					source: GameManager.CardSource) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in range(cards.size()):
		var cv: CardView = CardScene.instantiate()
		cv.card_data = cards[i]
		var idx := i
		cv.card_clicked.connect(
			func(_v): card_selected.emit(source, idx, cards[idx]))
		cv.card_drag_started.connect(
			func(_v): card_drag_started.emit(source, idx, cards[idx]))
		container.add_child(cv)
