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

# When false, the hand is shown face-down (used for the bot).
var show_hand: bool = true

@onready var name_label: Label      = $PlayerName
@onready var well_count: Label      = $WellAndBoard/Well/WellCount
@onready var well_top_slot: Control = $WellAndBoard/Well/WellTopSlot
@onready var board_container: HBoxContainer = $WellAndBoard/BoardZone/Board
@onready var hand_container: HBoxContainer  = $HandZone/Hand

const CardScene := preload("res://escenas/ui/card/card.tscn")

# Amber border style for the well card — signals it is the win-condition zone.
var _style_well: StyleBoxFlat

func _ready() -> void:
	_style_well = StyleBoxFlat.new()
	_style_well.bg_color = Color("#F8F4E3")
	_style_well.set_border_width_all(3)
	_style_well.border_color = Color("#E8A020")
	_style_well.set_corner_radius_all(6)
	_style_well.set_content_margin_all(6)

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
		well_top_slot.add_child(cv)

	# Board: top card per column, with ×N depth indicator when stacked
	for child in board_container.get_children():
		child.queue_free()
	var col_view_idx := 0
	for i in range(player.board.size()):
		var col: Array = player.board[i]
		if col.is_empty():
			continue
		var cv: CardView = CardScene.instantiate()
		cv.card_data = col.back()
		var idx := col_view_idx
		col_view_idx += 1
		cv.card_clicked.connect(
			func(_v): card_selected.emit(GameManager.CardSource.BOARD, idx, col.back()))
		if col.size() > 1:
			var wrapper := VBoxContainer.new()
			wrapper.add_child(cv)
			var count_lbl := Label.new()
			count_lbl.text = "×" + str(col.size())
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_lbl.add_theme_font_size_override("font_size", 11)
			count_lbl.add_theme_color_override("font_color", Color("#AAAAAA"))
			wrapper.add_child(count_lbl)
			board_container.add_child(wrapper)
		else:
			board_container.add_child(cv)

	# Hand: visible if human, face-down if bot
	if show_hand:
		_rebuild_cards(hand_container, player.hand,
					   GameManager.CardSource.HAND)
	else:
		for child in hand_container.get_children():
			child.queue_free()
		for _i in range(player.hand.size()):
			var cv: CardView = CardScene.instantiate()
			cv.face_down = true
			hand_container.add_child(cv)

# Returns the CardView node for the given source and index, or null if not found.
# Used by game.gd to mark the selected card with set_selected().
func get_card_view(source: GameManager.CardSource, index: int) -> CardView:
	match source:
		GameManager.CardSource.HAND:
			var children := hand_container.get_children()
			if index < children.size():
				return children[index] as CardView
		GameManager.CardSource.BOARD:
			var children := board_container.get_children()
			if index < children.size():
				var child := children[index]
				if child is CardView:
					return child as CardView
				# VBoxContainer wrapper: first child is the CardView
				if child.get_child_count() > 0:
					return child.get_child(0) as CardView
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
		container.add_child(cv)
