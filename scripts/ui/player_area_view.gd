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
var _player: Player = null

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
@onready var hand_container: Control        = $HandZone/Hand
@onready var hand_zone: VBoxContainer       = $HandZone

const CardScene := preload("res://escenas/ui/card/card.tscn")

const CARD_W        := 180
const CARD_H        := 260
const STACK_OFFSET  := 35    # px between stacked cards in a board column

const FAN_SPACING     := 58    # px between card left edges in the hand fan
const FAN_ANGLE       := 5.0   # degrees of rotation per step from center
const FAN_ARC         := 10.0  # parabolic y-drop (px) per t² at the edges
# Rival hand fan — smaller cards, inverted fan (top pivot, arc opens downward)
const RIVAL_CARD_W  := 105
const RIVAL_CARD_H  := 150
const RIVAL_SPACING := 32
const RIVAL_ANGLE   := 5.0
const RIVAL_ARC     := 1.0
const RIVAL_PEEK    := 0   # px of rival card visible — roughly half the card height
const RIVAL_HIDE_Y  := RIVAL_CARD_H - RIVAL_PEEK

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
	_player = player
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

	# Hand: fan at bottom for human; inverted fan at top for rivals
	hand_zone.visible = true
	if show_hand:
		move_child(hand_zone, get_child_count() - 1)
		hand_container.scale = Vector2(1, 1)
		_rebuild_hand_fan(player.hand)
	else:
		move_child(hand_zone, 0)
		_rebuild_rival_fan(player.hand.size())

# Returns the board column index under global_pos, or -1 if none.
# Checks existing columns first, then the "+" new-column slot.
func get_board_col_at_position(global_pos: Vector2) -> int:
	for child in board_container.get_children():
		if child.get_global_rect().has_point(global_pos):
			if child.has_meta("col_idx"):
				return child.get_meta("col_idx")
			elif _new_col_idx >= 0:
				return _new_col_idx
	return -1

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

# Colored border when it is this player's active turn.
func set_active(active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1a2e")
	if active and _player != null:
		style.border_color = SaveData.get_player_color(_player.player_number)
		style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

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
		var target_idx := _player.next_board_col_for_placement()
		if target_idx >= 0:
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
					card_selected.emit(GameManager.CardSource.BOARD, idx, _player.board_top(idx)))
			cv.card_drag_started.connect(func(_v):
				card_drag_started.emit(GameManager.CardSource.BOARD, idx, _player.board_top(idx)))

		column_ctrl.add_child(cv)

	return column_ctrl

# Builds an inverted fan for rivals — smaller cards, top-center pivot so the
# fan opens downward (simulates holding cards from the opposite side of the table).
func _rebuild_rival_fan(count: int) -> void:
	for child in hand_container.get_children():
		child.queue_free()
	hand_container.scale = Vector2(1, 1)
	if count == 0:
		hand_container.custom_minimum_size = Vector2(0, 0)
		return
	var half     := (count - 1) / 2.0
	var fan_w    := RIVAL_SPACING * (count - 1) + RIVAL_CARD_W
	var clip_h   := RIVAL_PEEK
	hand_container.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	hand_container.custom_minimum_size = Vector2(fan_w, clip_h)
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Force size after VBox layout pass so the clip rect matches clip_h exactly
	hand_container.set_deferred("size", Vector2(fan_w, clip_h))
	# Prevent hand_zone from expanding and pulling the container taller
	hand_zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hand_zone.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	for i in range(count):
		var cv: CardView = CardScene.instantiate()
		cv.face_down = true
		cv.custom_minimum_size = Vector2(RIVAL_CARD_W, RIVAL_CARD_H)
		var t := i - half
		# Push cards upward so only the lower half remains visible inside the clip rect.
		cv.position         = Vector2(i * RIVAL_SPACING, -RIVAL_HIDE_Y + t * t * RIVAL_ARC)
		# -t: bottoms spread outward (Λ), top-center pivot = grip at top
		cv.rotation_degrees = -t * RIVAL_ANGLE
		cv.pivot_offset     = Vector2(RIVAL_CARD_W / 2.0, 0)
		cv.z_index          = i
		cv.mouse_filter     = Control.MOUSE_FILTER_IGNORE
		hand_container.add_child(cv)

# Builds the hand as a rotated fan arc.
# Cards are laid out left-to-right with x = i * FAN_SPACING.
# Rotation and a parabolic y-offset create the held-fan illusion.
# Pivot is at the card's bottom center so rotation fans outward naturally.
func _rebuild_hand_fan(cards: Array[Card]) -> void:
	for child in hand_container.get_children():
		child.queue_free()

	var n := cards.size()
	if n == 0:
		hand_container.custom_minimum_size = Vector2(0, 0)
		return

	var fan_width  := FAN_SPACING * (n - 1) + CARD_W
	var half       := (n - 1) / 2.0
	var max_arc_y  := half * half * FAN_ARC
	# Height: half the card visible + hover headroom (cards offset down by HOVER_LIFT
	# so the upward hover motion doesn't clip at the container top).
	hand_container.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	hand_container.custom_minimum_size = Vector2(fan_width,
			CARD_H / 2 + max_arc_y + CardView.HOVER_LIFT + 8)

	for i in range(n):
		var cv: CardView = CardScene.instantiate()
		cv.card_data     = cards[i]
		cv.lift_on_hover = true
		cv.custom_minimum_size = Vector2(CARD_W, CARD_H)

		var t    := i - half
		# Offset y by HOVER_LIFT so hover (position.y -= HOVER_LIFT) stays in-bounds
		cv.position         = Vector2(i * FAN_SPACING, CardView.HOVER_LIFT + t * t * FAN_ARC)
		cv.rotation_degrees = t * FAN_ANGLE
		cv.pivot_offset     = Vector2(CARD_W / 2.0, CARD_H)
		cv.z_index          = i

		var idx := i
		cv.card_clicked.connect(
			func(_v): card_selected.emit(GameManager.CardSource.HAND, idx, cards[idx]))
		cv.card_drag_started.connect(
			func(_v): card_drag_started.emit(GameManager.CardSource.HAND, idx, cards[idx]))
		hand_container.add_child(cv)
