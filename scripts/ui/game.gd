# game.gd — Central coordinator for the game scene
#
# Why it exists:
#   GameManager handles pure game logic (no UI). The views (CardView, LadderView,
#   etc.) display data but know nothing about the game. game.gd is the glue
#   between both layers: it interprets UI events, translates them into
#   GameManager calls, and updates the views with the new state.
#
# What it does:
#   - Instantiates and connects all sub-views (player areas, ladders, HUD)
#     in _ready(), because they are created dynamically based on game data.
#   - Manages the interaction state machine (InteractionState):
#       IDLE               → no card selected, waiting for the player to click
#       CARD_SELECTED      → player chose a card, must now choose a ladder
#       AWAITING_BOARD_CARD → player pressed "End turn", must choose which hand
#                            card goes down to the board
#       AWAITING_BOARD_DEST → hand card chosen, must now choose which board
#                            column to place it in (or new column via "+")
#   - Coordinates the bot's turn: waits a visual delay then calls BotPlayer.play().
#   - Listens to game_won to lock the UI when the game ends.
#
# Design:
#   Interaction state (selected_source, selected_index, selected_card) is stored
#   in instance variables because the flow can span multiple frames (user clicks
#   card A, then ladder B on the next click).
#
#   _refresh_all() is the single visual update point: it is called every time
#   GameManager emits state_changed. No partial updates; everything is rebuilt.
#   Simple and correct.
#
#   Joker value is derived automatically from the ladder state: if the ladder
#   is empty the joker acts as an Ace (1); otherwise it takes top_value + 1.

extends Control

enum InteractionState { IDLE, CARD_SELECTED, AWAITING_BOARD_CARD, AWAITING_BOARD_DEST }

var game_manager: GameManager
var state: InteractionState = InteractionState.IDLE
var selected_source: GameManager.CardSource
var selected_index: int
var selected_card: Card

# Tracks the CardView node that is currently selected so we can clear its
# visual state when the selection changes or the turn ends.
var _selected_card_view: CardView = null

# Holds the hand index chosen in AWAITING_BOARD_CARD, used when the player
# subsequently picks a board column in AWAITING_BOARD_DEST.
var _end_turn_hand_index: int = -1

# Drag & drop state
var _drag_ghost: CardView = null       # floating card image under the cursor
var _drag_source_view: CardView = null # original card, dimmed while dragging
var _drag_is_end_turn: bool = false    # true when dragging during end-turn flow
var _add_ladder_btn: Button = null     # "+" button at the end of the ladders row

const PlayerAreaScene  := preload("res://escenas/ui/player_area/player_area.tscn")
const LadderScene      := preload("res://escenas/ui/ladder/ladder.tscn")
const HUDScene         := preload("res://escenas/ui/hud/hud.tscn")
const CardScene        := preload("res://escenas/ui/card/card.tscn")
const PauseMenuScene   := preload("res://escenas/ui/pause_menu/pause_menu.tscn")
const GameOverScene    := preload("res://escenas/ui/game_over/game_over.tscn")

@onready var opponent_row: HBoxContainer      = $Layout/OpponentRow
@onready var human_row: HBoxContainer         = $Layout/HumanRow
@onready var ladders_container: HBoxContainer = $Layout/CentralArea/LaddersContainer
@onready var deck_count: Label                = $Layout/CentralArea/DeckArea/DeckCard/DeckCount
@onready var layout: VBoxContainer            = $Layout

var human_area: PlayerAreaView
var bot_area: PlayerAreaView
var hud: HUDView
var _bot_hand_count: Label = null
var _pause_menu: PauseMenu = null

var _turn_count: int = 0
var _cards_played: int = 0

func _ready() -> void:
	game_manager = GameManager.new()
	game_manager.state_changed.connect(_refresh_all)
	game_manager.game_won.connect(_on_game_won)
	game_manager.turn_started.connect(_on_turn_started)
	game_manager.turn_ended.connect(func(_p: Player): _turn_count += 1)

	# Instantiate player areas
	human_area = PlayerAreaScene.instantiate()
	human_area.show_hand = true
	human_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_area.card_selected.connect(_on_human_card_selected)
	human_area.card_drag_started.connect(_on_card_drag_started)
	human_area.board_dest_selected.connect(_on_board_dest_selected)
	human_row.add_child(human_area)

	# Compact bot-hand widget — sits in the top-left corner of opponent_row
	var bot_hand_box := VBoxContainer.new()
	bot_hand_box.add_theme_constant_override("separation", 2)
	bot_hand_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var hand_title_lbl := Label.new()
	hand_title_lbl.text = "HAND"
	hand_title_lbl.add_theme_font_size_override("font_size", 20)
	hand_title_lbl.add_theme_color_override("font_color", Color("#888888"))
	bot_hand_box.add_child(hand_title_lbl)
	var hand_slot := Control.new()
	hand_slot.custom_minimum_size = Vector2(90, 130)
	var hand_card: CardView = CardScene.instantiate()
	hand_card.face_down = true
	hand_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_slot.add_child(hand_card)
	_bot_hand_count = Label.new()
	_bot_hand_count.add_theme_font_size_override("font_size", 36)
	_bot_hand_count.add_theme_color_override("font_color", Color("#F0EDE0"))
	_bot_hand_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bot_hand_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bot_hand_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_slot.add_child(_bot_hand_count)
	bot_hand_box.add_child(hand_slot)
	opponent_row.add_child(bot_hand_box)

	bot_area = PlayerAreaScene.instantiate()
	bot_area.show_hand = false  # Bot's hand is never revealed; shown via bot_hand_box
	bot_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	opponent_row.add_child(bot_area)

	# HUD at the bottom of the layout
	hud = HUDScene.instantiate()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.end_turn_requested.connect(_on_end_turn_pressed)
	hud.pause_requested.connect(_toggle_pause)
	layout.add_child(hud)

	# Style the deck panel as a face-down card (navy blue)
	var deck_card_panel: PanelContainer = $Layout/CentralArea/DeckArea/DeckCard
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A3A5C")
	style.set_border_width_all(2)
	style.border_color = Color("#2A5A8C")
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	deck_card_panel.add_theme_stylebox_override("panel", style)
	deck_count.add_theme_color_override("font_color", Color("#F0EDE0"))

	var player_name: String = SaveData.session.get("player_name", "Jugador") as String
	var bot_count: int = SaveData.session.get("bot_count", 1) as int
	game_manager.setup(player_name, bot_count)
	game_manager.begin_turn()

# Rebuilds the entire UI from the current game state.
# This is the single synchronization point between logic and view.
func _refresh_all() -> void:
	human_area.refresh(game_manager.players[0])
	bot_area.refresh(game_manager.players[1])
	_bot_hand_count.text = str(game_manager.players[1].hand.size())
	_rebuild_ladders()
	deck_count.text = str(game_manager.deck.size())
	hud.refresh(game_manager)
	var current := game_manager.current_player()
	human_area.set_active_turn(current.is_human)
	bot_area.set_active_turn(not current.is_human)

# Destroys and recreates all LadderViews to reflect current ladder state.
# A persistent "+" button at the end lets the player create a new ladder slot
# whenever they hold an Ace (or a joker they intend to use as an Ace).
func _rebuild_ladders() -> void:
	for child in ladders_container.get_children():
		child.queue_free()
	_add_ladder_btn = null  # freed by the loop above
	for i in range(game_manager.ladder_manager.ladders.size()):
		var lv: LadderView = LadderScene.instantiate()
		lv.ladder_data = game_manager.ladder_manager.ladders[i]
		lv.ladder_index = i
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.ladder_clicked.connect(_on_ladder_clicked)
		ladders_container.add_child(lv)
	# "+" button — always visible; only meaningful when an Ace is selected
	_add_ladder_btn = Button.new()
	_add_ladder_btn.text = "+"
	_add_ladder_btn.custom_minimum_size = Vector2(50, 90)
	_add_ladder_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_add_ladder_btn.pressed.connect(_on_add_ladder_pressed)
	ladders_container.add_child(_add_ladder_btn)

# The player clicked a card. Interpreted differently depending on current state:
#   - In AWAITING_BOARD_CARD: a hand click picks the card to place on the board.
#   - In AWAITING_BOARD_DEST: only board-card clicks matter (handled via board_dest_selected).
#   - Otherwise: selects the card and waits for a ladder click.
func _on_human_card_selected(source: GameManager.CardSource,
							  index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return

	# Step 1 of end-turn: player picks which hand card to send down.
	if state == InteractionState.AWAITING_BOARD_CARD:
		if source != GameManager.CardSource.HAND:
			return
		_end_turn_hand_index = index
		state = InteractionState.AWAITING_BOARD_DEST
		human_area.show_board_destinations(true)
		hud.set_status("Choose a board column (+). Click another hand card to change. Esc to cancel.")
		return

	# Step 2: board destination is handled by board_dest_selected signal.
	# But allow the player to switch to a different hand card by clicking it.
	if state == InteractionState.AWAITING_BOARD_DEST:
		if source == GameManager.CardSource.HAND:
			_end_turn_hand_index = index
			# Rebuild destination highlighting for the new selection
			human_area.show_board_destinations(false)
			human_area.show_board_destinations(true)
			hud.set_status("Choose a board column (+). Click another hand card to change. Esc to cancel.")
		return

	# Clear the previous selection before setting the new one
	_clear_selection()

	selected_source = source
	selected_index = index
	selected_card = card
	state = InteractionState.CARD_SELECTED

	# Mark the clicked CardView as selected (golden border)
	_selected_card_view = human_area.get_card_view(source, index)
	if _selected_card_view != null:
		_selected_card_view.set_selected(true)

	# Highlight ladders where this card can be played
	_highlight_valid_ladders(card)

	hud.set_status("Choose a ladder to play " + card.label())

# The player clicked a ladder. Only acts if a card is already selected.
func _on_ladder_clicked(ladder_index: int) -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var joker_value := 0
	if selected_card.is_joker:
		joker_value = _joker_value_for_ladder(ladder_index)
	var ok := game_manager.try_play_card(
		selected_source, selected_index, ladder_index, joker_value)
	_clear_selection()
	_clear_ladder_highlights()
	if not ok:
		hud.set_status("Can't play there. Choose another ladder.")
	else:
		_cards_played += 1
		var msg := selected_card.label() + " → ladder " + str(ladder_index + 1)
		hud.set_status("Played " + selected_card.label() + ". Keep playing or end your turn.")
		hud.log_action(msg)
	state = InteractionState.IDLE

# The player pressed "End turn": step 1 — pick a hand card to send down.
# Pressing it again while in the end-turn flow cancels the whole operation.
func _on_end_turn_pressed() -> void:
	if state == InteractionState.AWAITING_BOARD_CARD \
	   or state == InteractionState.AWAITING_BOARD_DEST:
		_cancel_end_turn_flow()
		return
	if game_manager.current_player().hand.is_empty():
		hud.set_status("No cards in hand to place on the board.")
		return
	_clear_selection()
	_clear_ladder_highlights()
	state = InteractionState.AWAITING_BOARD_CARD
	hud.set_status("Choose a hand card to place on the board. (End Turn or Esc to cancel.)")

# Aborts the end-turn flow and returns to normal play.
func _cancel_end_turn_flow() -> void:
	human_area.show_board_destinations(false)
	_end_turn_hand_index = -1
	state = InteractionState.IDLE
	hud.set_status("Your turn")

# Step 2 — player chose which board column (or new column) to place the card in.
func _on_board_dest_selected(col_index: int) -> void:
	if state != InteractionState.AWAITING_BOARD_DEST:
		return
	human_area.show_board_destinations(false)
	_do_end_turn(_end_turn_hand_index, col_index)
	_end_turn_hand_index = -1

# Executes the actual end-of-turn: places the chosen card onto the board.
func _do_end_turn(hand_index: int, board_col: int) -> void:
	var ok := game_manager.try_end_turn(hand_index, board_col)
	if not ok:
		hud.set_status("Could not end turn.")
	state = InteractionState.IDLE

# Returns the value a joker must take when played on the given ladder:
# 1 (Ace) if the ladder is empty, or top_value + 1 otherwise.
func _joker_value_for_ladder(ladder_index: int) -> int:
	var ladder: Array = game_manager.ladder_manager.ladders[ladder_index]
	if ladder.is_empty():
		return 1
	return ladder.back().value + 1

# Clears the golden border from the currently selected CardView.
func _clear_selection() -> void:
	if _selected_card_view != null:
		_selected_card_view.set_selected(false)
		_selected_card_view = null

# Highlights ladders where the given card can legally be played.
func _highlight_valid_ladders(card: Card) -> void:
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv == null:
			continue
		var joker_value := 0
		if card.is_joker:
			joker_value = _joker_value_for_ladder(lv.ladder_index)
			# Ladder is complete — joker can't extend beyond K
			if joker_value > 13:
				lv.set_valid_target(false)
				continue
		var can_play := game_manager.ladder_manager.can_play_on(
			card, lv.ladder_index, joker_value)
		lv.set_valid_target(can_play)

# Removes the valid-target highlight from all ladders.
func _clear_ladder_highlights() -> void:
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null:
			lv.set_valid_target(false)

# Bot's turn: dims the human area, waits a visual delay, runs the bot, then restores.
func _on_turn_started(player: Player) -> void:
	human_area.set_active_turn(player.is_human)
	bot_area.set_active_turn(not player.is_human)
	if not player.is_human:
		human_area.modulate = Color(0.5, 0.5, 0.5, 1.0)
		hud.set_status("Bot is thinking...")
		await get_tree().create_timer(0.8).timeout
		BotPlayer.play(game_manager)
		human_area.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Do not overwrite the win message if the bot emptied its well
		if not game_manager.is_game_over:
			_refresh_all()
			hud.set_status("Your turn")

# Game over: save stats, lock the HUD, and show the GameOver overlay.
func _on_game_won(player: Player) -> void:
	hud.disable_actions()
	var human := game_manager.players[0]
	SaveData.record_game_result(human.name, player.is_human, _turn_count, _cards_played)
	var go: GameOver = GameOverScene.instantiate()
	add_child(go)
	go.setup(player, human.name, _turn_count, _cards_played)

# ── Drag & drop ──────────────────────────────────────────────────────────────

# Player started dragging a card. Two modes:
#   Normal play  — drags from hand/well/board toward a ladder.
#   End-turn     — drags a hand card (in AWAITING_BOARD_CARD) toward a board column.
func _on_card_drag_started(source: GameManager.CardSource,
							index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return
	if state == InteractionState.AWAITING_BOARD_DEST:
		return  # already committed to a card; ignore new drags

	# End-turn drag: player dragged a hand card while choosing what to send down.
	if state == InteractionState.AWAITING_BOARD_CARD:
		if source != GameManager.CardSource.HAND:
			return
		_end_turn_hand_index = index
		state = InteractionState.AWAITING_BOARD_DEST
		human_area.show_board_destinations(true)
		_drag_is_end_turn = true
		_drag_source_view = human_area.get_card_view(source, index)
		if _drag_source_view != null:
			_drag_source_view.modulate.a = 0.4
		_start_ghost(card)
		return

	# Normal drag: play the card on a ladder.
	_clear_selection()
	_clear_ladder_highlights()
	selected_source = source
	selected_index  = index
	selected_card   = card
	state = InteractionState.CARD_SELECTED
	_drag_source_view = human_area.get_card_view(source, index)
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 0.4
	_start_ghost(card)
	_highlight_valid_ladders(card)

# Creates the floating ghost card that follows the cursor.
func _start_ghost(card: Card) -> void:
	_drag_ghost = CardScene.instantiate()
	_drag_ghost.card_data = card
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.custom_minimum_size = Vector2(180, 260)
	_drag_ghost.z_index = 100
	add_child(_drag_ghost)
	_drag_ghost.position = get_global_mouse_position() - Vector2(90, 130)

# Handles mouse movement and release while a drag ghost is active.
# Escape during drag/end-turn flow is consumed here so _unhandled_input
# (which opens the pause menu) does not also fire.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _drag_ghost != null:
			_cancel_drag()
			get_viewport().set_input_as_handled()
		elif state == InteractionState.AWAITING_BOARD_DEST:
			human_area.show_board_destinations(false)
			_end_turn_hand_index = -1
			state = InteractionState.AWAITING_BOARD_CARD
			hud.set_status("Choose a hand card to place on the board. (End Turn or Esc to cancel.)")
			get_viewport().set_input_as_handled()
		elif state == InteractionState.AWAITING_BOARD_CARD:
			_cancel_end_turn_flow()
			get_viewport().set_input_as_handled()
		return
	if _drag_ghost == null:
		return
	if event is InputEventMouseMotion:
		_drag_ghost.position = get_global_mouse_position() - Vector2(90, 130)
	elif event is InputEventMouseButton \
		 and event.button_index == MOUSE_BUTTON_LEFT \
		 and not event.pressed:
		_end_drag()

# Escape when not in a drag/end-turn flow → toggle pause menu.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

# Cleans up the ghost and resolves the drop.
func _end_drag() -> void:
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 1.0
		_drag_source_view = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_try_drop_at_mouse()

# Cancels an in-progress drag without taking any action.
func _cancel_drag() -> void:
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 1.0
		_drag_source_view = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	if _drag_is_end_turn:
		_drag_is_end_turn = false
		human_area.show_board_destinations(false)
		_end_turn_hand_index = -1
		state = InteractionState.IDLE
	else:
		_clear_selection()
		_clear_ladder_highlights()
		state = InteractionState.IDLE
	hud.set_status("Your turn")

# Checks whether the mouse is over a valid drop target and resolves the action.
# End-turn drag: looks for board columns and the "+" new-column slot.
# Normal drag:   looks for ladders and the "+" new-ladder button.
func _try_drop_at_mouse() -> void:
	var mouse_pos := get_global_mouse_position()

	if _drag_is_end_turn:
		_drag_is_end_turn = false
		for child in human_area.board_container.get_children():
			if child.get_global_rect().has_point(mouse_pos):
				if child.has_meta("col_idx"):
					_on_board_dest_selected(child.get_meta("col_idx"))
				else:
					# Must be the "+" new-column button — use the pre-computed index
					if human_area._new_col_idx >= 0:
						_on_board_dest_selected(human_area._new_col_idx)
				return
		# Dropped outside board — revert to hand-card-selection step
		human_area.show_board_destinations(false)
		_end_turn_hand_index = -1
		state = InteractionState.AWAITING_BOARD_CARD
		hud.set_status("Choose a card from your hand to place on the board.")
		return

	# Normal drag — check ladders
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null and lv.get_global_rect().has_point(mouse_pos):
			_on_ladder_clicked(lv.ladder_index)
			return
	# Check the "+" new-ladder button
	if _add_ladder_btn != null \
	   and _add_ladder_btn.get_global_rect().has_point(mouse_pos):
		_on_add_ladder_pressed()
		return
	# Dropped on nothing — cancel without an error message
	_clear_selection()
	_clear_ladder_highlights()
	state = InteractionState.IDLE
	hud.set_status("Your turn")

# ── Pause ────────────────────────────────────────────────────────────────────

func _toggle_pause() -> void:
	if game_manager.is_game_over:
		return
	if _pause_menu != null:
		_unpause()
		return
	get_tree().paused = true
	_pause_menu = PauseMenuScene.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_unpause)
	_pause_menu.restart_requested.connect(_restart_game)
	_pause_menu.main_menu_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://escenas/ui/main_menu/main_menu.tscn"))

func _unpause() -> void:
	get_tree().paused = false
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://escenas/game/game.tscn")

# ── Ladders ──────────────────────────────────────────────────────────────────

# Creates a new empty ladder slot and immediately plays the selected Ace there.
# Only valid when an Ace (or a joker used as Ace) is selected.
func _on_add_ladder_pressed() -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var effective_val := selected_card.value
	if selected_card.is_joker:
		effective_val = 1  # joker acts as Ace on a fresh ladder
	if effective_val != 1:
		hud.set_status("Only an Ace can start a new ladder.")
		return
	game_manager.ladder_manager.add_ladder_slot()
	var new_idx := game_manager.ladder_manager.ladders.size() - 1
	var joker_value := 1 if selected_card.is_joker else 0
	var ok := game_manager.try_play_card(
		selected_source, selected_index, new_idx, joker_value)
	_clear_selection()
	_clear_ladder_highlights()
	if ok:
		_cards_played += 1
		hud.set_status("New ladder started! Keep playing or end your turn.")
	else:
		hud.set_status("Couldn't start new ladder.")
	state = InteractionState.IDLE
