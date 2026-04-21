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
#   - All state transitions go through _transition_to(), which handles exit
#     cleanup and entry setup in one place.
#   - Coordinates the bot's turn: waits a visual delay then calls game_manager.run_bot_turn().
#   - Listens to game_won to lock the UI when the game ends.

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

const PlayerAreaScene        := preload("res://escenas/ui/player_area/player_area.tscn")
const LadderScene            := preload("res://escenas/ui/ladder/ladder.tscn")
const HUDScene               := preload("res://escenas/ui/hud/hud.tscn")
const CardScene              := preload("res://escenas/ui/card/card.tscn")
const PauseMenuScene         := preload("res://escenas/ui/pause_menu/pause_menu.tscn")
const GameOverScene          := preload("res://escenas/ui/game_over/game_over.tscn")
const RivalBoardOverlayScene := preload("res://escenas/game/rival_board_overlay/rival_board_overlay.tscn")
const RivalAreaScene         := preload("res://escenas/game/rival_area/rival_area.tscn")

@onready var rivals_row:        HBoxContainer = $MainLayout/RivalsRow
@onready var human_row:         HBoxContainer = $MainLayout/HumanRow
@onready var ladders_container: HBoxContainer = $MainLayout/LaddersArea/LaddersContainer
@onready var deck_count:        Label         = $MainLayout/LaddersArea/DeckArea/DeckCard/DeckCount
@onready var main_layout:       VBoxContainer = $MainLayout

var human_area: PlayerAreaView
var hud: HUDView
var _pause_menu: PauseMenu = null
var _rival_views: Dictionary = {}
var _single_rival_area: PlayerAreaView = null  # used when bot_count == 1
var _rival_overlay: RivalBoardOverlay = null

func _ready() -> void:
	game_manager = GameManager.new()
	game_manager.state_changed.connect(_refresh_all)
	game_manager.game_won.connect(_on_game_won)
	game_manager.turn_started.connect(_on_turn_started)

	human_area = PlayerAreaScene.instantiate()
	human_area.show_hand = true
	human_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_area.card_selected.connect(_on_human_card_selected)
	human_area.card_drag_started.connect(_on_card_drag_started)
	human_area.board_dest_selected.connect(_on_board_dest_selected)
	human_row.add_child(human_area)

	hud = HUDScene.instantiate()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.end_turn_requested.connect(_on_end_turn_pressed)
	hud.pause_requested.connect(_toggle_pause)
	main_layout.add_child(hud)

	var deck_card_panel: PanelContainer = $MainLayout/LaddersArea/DeckArea/DeckCard
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A3A5C")
	style.set_border_width_all(2)
	style.border_color = Color("#2A5A8C")
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	deck_card_panel.add_theme_stylebox_override("panel", style)
	deck_count.add_theme_color_override("font_color", Color("#F0EDE0"))

	var player_name: String = SaveData.session.get("player_name", "Jugador") as String
	var bot_count:   int    = SaveData.session.get("bot_count", 1) as int
	game_manager.setup(player_name, bot_count)
	_build_rival_views()
	game_manager.begin_turn()

# ── State machine ─────────────────────────────────────────────────────────────

# Single entry point for all state transitions.
# Exit cleanup runs first (deselect card, clear highlights, hide board destinations).
# Entry setup runs after (highlight valid ladders, show board destinations, update HUD).
# Callers must set selected_source/index/card BEFORE calling _transition_to(CARD_SELECTED).
func _transition_to(new_state: InteractionState, status: String = "") -> void:
	match state:
		InteractionState.CARD_SELECTED:
			_clear_selection()
			_clear_ladder_highlights()
		InteractionState.AWAITING_BOARD_DEST:
			human_area.show_board_destinations(false)
			_end_turn_hand_index = -1

	state = new_state

	match new_state:
		InteractionState.IDLE:
			human_area.show_board_destinations(false)
			_end_turn_hand_index = -1
			if status.is_empty():
				status = "Your turn"
		InteractionState.CARD_SELECTED:
			_highlight_valid_ladders(selected_card)
			if status.is_empty():
				status = "Choose a ladder to play " + selected_card.label()
		InteractionState.AWAITING_BOARD_CARD:
			_clear_selection()
			_clear_ladder_highlights()
			_end_turn_hand_index = -1
			if status.is_empty():
				status = "Choose a hand card to place on the board. (End Turn or Esc to cancel.)"
		InteractionState.AWAITING_BOARD_DEST:
			human_area.show_board_destinations(true)
			if status.is_empty():
				status = "Choose a board column (+). Click another hand card to change. Esc to cancel."

	hud.set_status(status)

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	human_area.refresh(game_manager.human_player())
	if _single_rival_area != null:
		_single_rival_area.refresh(game_manager.bot_players()[0])
	else:
		for player in _rival_views:
			(_rival_views[player] as RivalAreaView).refresh()
	_rebuild_ladders()
	deck_count.text = str(game_manager.deck_size())
	hud.set_human_turn(game_manager.current_player().is_human)
	var current := game_manager.current_player()
	human_area.set_active_turn(current.is_human)
	if _single_rival_area != null:
		_single_rival_area.set_active_turn(not current.is_human)
	else:
		for p in _rival_views:
			(_rival_views[p] as RivalAreaView).set_active(p == current)

func _rebuild_ladders() -> void:
	for child in ladders_container.get_children():
		child.queue_free()
	_add_ladder_btn = null  # freed by the loop above
	for i in range(game_manager.ladder_count()):
		var lv: LadderView = LadderScene.instantiate()
		lv.ladder_data = game_manager.ladder_at(i)
		lv.ladder_index = i
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.ladder_clicked.connect(_on_ladder_clicked)
		ladders_container.add_child(lv)
	_add_ladder_btn = Button.new()
	_add_ladder_btn.text = "+"
	_add_ladder_btn.custom_minimum_size = Vector2(50, 90)
	_add_ladder_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_add_ladder_btn.pressed.connect(_on_add_ladder_pressed)
	ladders_container.add_child(_add_ladder_btn)

# ── Interaction ───────────────────────────────────────────────────────────────

func _on_human_card_selected(source: GameManager.CardSource,
							  index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return

	if state == InteractionState.AWAITING_BOARD_CARD:
		if source != GameManager.CardSource.HAND:
			return
		_end_turn_hand_index = index
		_transition_to(InteractionState.AWAITING_BOARD_DEST)
		return

	# In AWAITING_BOARD_DEST: allow switching to a different hand card.
	if state == InteractionState.AWAITING_BOARD_DEST:
		if source == GameManager.CardSource.HAND:
			_end_turn_hand_index = index
			human_area.show_board_destinations(false)
			human_area.show_board_destinations(true)
			hud.set_status("Choose a board column (+). Click another hand card to change. Esc to cancel.")
		return

	# Normal card selection (or re-selection).
	selected_source = source
	selected_index  = index
	selected_card   = card
	_transition_to(InteractionState.CARD_SELECTED)
	_selected_card_view = human_area.get_card_view(source, index)
	if _selected_card_view != null:
		_selected_card_view.set_selected(true)

func _on_ladder_clicked(ladder_index: int) -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var ok := game_manager.try_play_card(selected_source, selected_index, ladder_index)
	if not ok:
		hud.set_status("Can't play there. Choose another ladder.")
		return
	var msg := selected_card.label() + " → ladder " + str(ladder_index + 1)
	hud.log_action(msg)
	_transition_to(InteractionState.IDLE,
				   "Played " + selected_card.label() + ". Keep playing or end your turn.")

func _on_end_turn_pressed() -> void:
	if state == InteractionState.AWAITING_BOARD_CARD \
	   or state == InteractionState.AWAITING_BOARD_DEST:
		_transition_to(InteractionState.IDLE)
		return
	if game_manager.current_player().hand.is_empty():
		hud.set_status("No cards in hand to place on the board.")
		return
	_transition_to(InteractionState.AWAITING_BOARD_CARD)

func _on_board_dest_selected(col_index: int) -> void:
	if state != InteractionState.AWAITING_BOARD_DEST:
		return
	var hand_index := _end_turn_hand_index  # save before _transition_to resets it
	_transition_to(InteractionState.IDLE)
	var ok := game_manager.try_end_turn(hand_index, col_index)
	if not ok:
		hud.set_status("Could not end turn.")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _highlight_valid_ladders(card: Card) -> void:
	var valid := game_manager.playable_ladders_for(card)
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null:
			lv.set_valid_target(valid.has(lv.ladder_index))

func _clear_ladder_highlights() -> void:
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null:
			lv.set_valid_target(false)

func _clear_selection() -> void:
	if _selected_card_view != null:
		_selected_card_view.set_selected(false)
		_selected_card_view = null

# ── Turn management ───────────────────────────────────────────────────────────

func _on_turn_started(player: Player) -> void:
	human_area.set_active_turn(player.is_human)
	if _single_rival_area != null:
		_single_rival_area.set_active_turn(not player.is_human)
	else:
		for p in _rival_views:
			(_rival_views[p] as RivalAreaView).set_active(p == player)
	if not player.is_human:
		human_area.modulate = Color(0.5, 0.5, 0.5, 1.0)
		hud.set_status("Bot is thinking...")
		var delay: float = SaveData.get_setting("bot_turn_delay", 0.5)
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		game_manager.run_bot_turn()
		human_area.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if not game_manager.is_game_over:
			_refresh_all()
			hud.set_status("Your turn")

func _on_game_won(player: Player) -> void:
	hud.disable_actions()
	var go: GameOver = GameOverScene.instantiate()
	add_child(go)
	go.setup(player, game_manager.human_player().name, game_manager.turn_count, game_manager.cards_played)

# ── Drag & drop ───────────────────────────────────────────────────────────────

func _on_card_drag_started(source: GameManager.CardSource,
							index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return
	if state == InteractionState.AWAITING_BOARD_DEST:
		return  # already committed to a card; ignore new drags

	if state == InteractionState.AWAITING_BOARD_CARD:
		if source != GameManager.CardSource.HAND:
			return
		_end_turn_hand_index = index
		_transition_to(InteractionState.AWAITING_BOARD_DEST)
		_drag_is_end_turn = true
		_drag_source_view = human_area.get_card_view(source, index)
		if _drag_source_view != null:
			_drag_source_view.modulate.a = 0.4
		_start_ghost(card)
		return

	# Normal drag: play the card on a ladder.
	selected_source = source
	selected_index  = index
	selected_card   = card
	_transition_to(InteractionState.CARD_SELECTED)
	_drag_source_view = human_area.get_card_view(source, index)
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 0.4
	_start_ghost(card)

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
			_transition_to(InteractionState.AWAITING_BOARD_CARD)
			get_viewport().set_input_as_handled()
		elif state == InteractionState.AWAITING_BOARD_CARD:
			_transition_to(InteractionState.IDLE)
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _end_drag() -> void:
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 1.0
		_drag_source_view = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_try_drop_at_mouse()

func _cancel_drag() -> void:
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 1.0
		_drag_source_view = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_drag_is_end_turn = false
	_transition_to(InteractionState.IDLE)

func _try_drop_at_mouse() -> void:
	var mouse_pos := get_global_mouse_position()

	if _drag_is_end_turn:
		_drag_is_end_turn = false
		var col := human_area.get_board_col_at_position(mouse_pos)
		if col >= 0:
			_on_board_dest_selected(col)
			return
		# Dropped outside board — revert to hand-card-selection step
		_transition_to(InteractionState.AWAITING_BOARD_CARD,
					   "Choose a card from your hand to place on the board.")
		return

	# Normal drag — check ladders
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null and lv.get_global_rect().has_point(mouse_pos):
			_on_ladder_clicked(lv.ladder_index)
			return
	if _add_ladder_btn != null \
	   and _add_ladder_btn.get_global_rect().has_point(mouse_pos):
		_on_add_ladder_pressed()
		return
	_transition_to(InteractionState.IDLE)

# ── Ladders ───────────────────────────────────────────────────────────────────

func _on_add_ladder_pressed() -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var ok := game_manager.try_start_new_ladder(selected_source, selected_index)
	var msg := "New ladder started! Keep playing or end your turn." if ok \
			   else "Only an Ace can start a new ladder."
	_transition_to(InteractionState.IDLE, msg)

# ── Rival views ───────────────────────────────────────────────────────────────

func _build_rival_views() -> void:
	for child in rivals_row.get_children():
		child.queue_free()
	_rival_views.clear()
	_single_rival_area = null
	var bots := game_manager.bot_players()
	if bots.size() == 1:
		var view: PlayerAreaView = PlayerAreaScene.instantiate()
		view.show_hand = false
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rivals_row.add_child(view)
		_single_rival_area = view
	else:
		for player in game_manager.bot_players():
			var view: RivalAreaView = RivalAreaScene.instantiate()
			rivals_row.add_child(view)
			view.setup(player)
			view.inspect_requested.connect(_show_rival_board)
			_rival_views[player] = view

# ── Rival board overlay ───────────────────────────────────────────────────────

func _show_rival_board(player: Player) -> void:
	if _rival_overlay != null:
		_rival_overlay.queue_free()
	_rival_overlay = RivalBoardOverlayScene.instantiate()
	add_child(_rival_overlay)
	_rival_overlay.setup(player)
	_rival_overlay.tree_exited.connect(func(): _rival_overlay = null)

# ── Pause ─────────────────────────────────────────────────────────────────────

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
