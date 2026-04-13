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
#       IDLE              → no card selected, waiting for the player to click
#       CARD_SELECTED     → player chose a card, must now choose a ladder
#       AWAITING_BOARD_COL → player pressed "End turn", must choose which hand
#                           card goes down to the board
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

enum InteractionState { IDLE, CARD_SELECTED, AWAITING_BOARD_COL }

var game_manager: GameManager
var state: InteractionState = InteractionState.IDLE
var selected_source: GameManager.CardSource
var selected_index: int
var selected_card: Card

# Tracks the CardView node that is currently selected so we can clear its
# visual state when the selection changes or the turn ends.
var _selected_card_view: CardView = null

const PlayerAreaScene := preload("res://escenas/ui/player_area/player_area.tscn")
const LadderScene     := preload("res://escenas/ui/ladder/ladder.tscn")
const HUDScene        := preload("res://escenas/ui/hud/hud.tscn")

@onready var opponent_row: HBoxContainer      = $Layout/OpponentRow
@onready var human_row: HBoxContainer         = $Layout/HumanRow
@onready var ladders_container: HBoxContainer = $Layout/CentralArea/LaddersContainer
@onready var deck_count: Label                = $Layout/CentralArea/DeckArea/DeckCard/DeckCount
@onready var layout: VBoxContainer            = $Layout

var human_area: PlayerAreaView
var bot_area: PlayerAreaView
var hud: HUDView

func _ready() -> void:
	game_manager = GameManager.new()
	game_manager.state_changed.connect(_refresh_all)
	game_manager.game_won.connect(_on_game_won)
	game_manager.turn_started.connect(_on_turn_started)

	# Instantiate player areas
	human_area = PlayerAreaScene.instantiate()
	human_area.show_hand = true
	human_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_area.card_selected.connect(_on_human_card_selected)
	human_row.add_child(human_area)

	bot_area = PlayerAreaScene.instantiate()
	bot_area.show_hand = false  # Bot's hand is never revealed
	bot_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opponent_row.add_child(bot_area)

	# HUD at the bottom of the layout
	hud = HUDScene.instantiate()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.end_turn_requested.connect(_on_end_turn_pressed)
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

	game_manager.setup()
	game_manager.begin_turn()

# Rebuilds the entire UI from the current game state.
# This is the single synchronization point between logic and view.
func _refresh_all() -> void:
	human_area.refresh(game_manager.players[0])
	bot_area.refresh(game_manager.players[1])
	_rebuild_ladders()
	deck_count.text = str(game_manager.deck.size())
	hud.refresh(game_manager)
	var current := game_manager.current_player()
	human_area.set_active_turn(current.is_human)
	bot_area.set_active_turn(not current.is_human)

# Destroys and recreates all LadderViews to reflect current ladder state.
func _rebuild_ladders() -> void:
	for child in ladders_container.get_children():
		child.queue_free()
	for i in range(game_manager.ladder_manager.ladders.size()):
		var lv: LadderView = LadderScene.instantiate()
		lv.ladder_data = game_manager.ladder_manager.ladders[i]
		lv.ladder_index = i
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.ladder_clicked.connect(_on_ladder_clicked)
		ladders_container.add_child(lv)

# The player clicked a card. Interpreted differently depending on current state:
#   - In AWAITING_BOARD_COL: a click on a hand card ends the turn by placing it.
#   - Otherwise: selects the card and waits for a ladder click.
func _on_human_card_selected(source: GameManager.CardSource,
							  index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return

	# End-of-turn flow: player already pressed "End turn" and now chooses
	# which hand card to place on the board with a direct click.
	if state == InteractionState.AWAITING_BOARD_COL:
		if source == GameManager.CardSource.HAND:
			var col := game_manager.current_player().board.size()
			_clear_selection()
			_clear_ladder_highlights()
			_do_end_turn(index, col)
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
		var msg := selected_card.label() + " → ladder " + str(ladder_index + 1)
		hud.set_status("Played " + selected_card.label() + ". Keep playing or end your turn.")
		hud.log_action(msg)
	state = InteractionState.IDLE

# The player pressed "End turn": switches to board-column selection mode.
func _on_end_turn_pressed() -> void:
	if game_manager.current_player().hand.is_empty():
		hud.set_status("No cards in hand to place on the board.")
		return
	state = InteractionState.AWAITING_BOARD_COL
	hud.set_status("Choose a card from your hand to place on the board.")

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
		_refresh_all()
		human_area.modulate = Color(1.0, 1.0, 1.0, 1.0)
		hud.set_status("Your turn")

# Game over: display the winner and lock the UI.
func _on_game_won(player: Player) -> void:
	hud.set_status(player.name + " wins!")
	hud.disable_actions()
