class_name TurnController
extends Node

signal status_updated(text: String)
signal action_logged(text: String)
signal valid_ladders_changed(indices: Array[int])
signal board_destinations_visible(show: bool)
signal selection_cleared()
signal bot_thinking_started()
signal bot_thinking_ended()
signal move_about_to_play(event: CardMoveEvent)
signal animation_finished

enum State { IDLE, CARD_SELECTED, AWAITING_BOARD_CARD, AWAITING_BOARD_DEST }

var game_manager: GameManager
var state: State = State.IDLE
var selected_source: GameManager.CardSource
var selected_index:  int
var selected_card:   Card
var _end_turn_hand_index: int = -1
var _bot_running: bool = false

func setup(gm: GameManager) -> void:
	game_manager = gm

# ── Input intents (called by game.gd) ─────────────────────────────────────────

func on_card_input(source: GameManager.CardSource, index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return

	if state == State.AWAITING_BOARD_CARD:
		if source != GameManager.CardSource.HAND:
			return
		_end_turn_hand_index = index
		_transition_to(State.AWAITING_BOARD_DEST)
		return

	if state == State.AWAITING_BOARD_DEST:
		if source == GameManager.CardSource.HAND:
			_end_turn_hand_index = index
			board_destinations_visible.emit(false)
			board_destinations_visible.emit(true)
			status_updated.emit("Choose a board column (+). Click another hand card to change. Esc to cancel.")
		return

	selected_source = source
	selected_index  = index
	selected_card   = card
	_transition_to(State.CARD_SELECTED)

func on_ladder_chosen(ladder_index: int) -> void:
	if state != State.CARD_SELECTED:
		return
	var ok := game_manager.try_play_card(selected_source, selected_index, ladder_index)
	if not ok:
		status_updated.emit("Can't play there. Choose another ladder.")
		return
	action_logged.emit(selected_card.label() + " → ladder " + str(ladder_index + 1))
	_transition_to(State.IDLE, "Played " + selected_card.label() + ". Keep playing or end your turn.")

func on_end_turn_requested() -> void:
	if state == State.AWAITING_BOARD_CARD or state == State.AWAITING_BOARD_DEST:
		_transition_to(State.IDLE)
		return
	if game_manager.current_player().hand.is_empty():
		status_updated.emit("No cards in hand to place on the board.")
		return
	_transition_to(State.AWAITING_BOARD_CARD)

func on_board_dest_chosen(col_index: int) -> void:
	if state != State.AWAITING_BOARD_DEST:
		return
	var hand_index := _end_turn_hand_index
	_transition_to(State.IDLE)
	var ok := game_manager.try_end_turn(hand_index, col_index)
	if not ok:
		status_updated.emit("Could not end turn.")

func on_add_ladder_pressed() -> void:
	if state != State.CARD_SELECTED:
		return
	var ok := game_manager.try_start_new_ladder(selected_source, selected_index)
	var msg := "New ladder started! Keep playing or end your turn." if ok \
			   else "Only an Ace can start a new ladder."
	_transition_to(State.IDLE, msg)

func on_drag_started_as_end_turn(index: int) -> void:
	_end_turn_hand_index = index
	_transition_to(State.AWAITING_BOARD_DEST)

func on_drag_started_normal(source: GameManager.CardSource, index: int, card: Card) -> void:
	selected_source = source
	selected_index  = index
	selected_card   = card
	_transition_to(State.CARD_SELECTED)

func on_drag_dropped_outside_board() -> void:
	_transition_to(State.AWAITING_BOARD_CARD, "Choose a card from your hand to place on the board.")

func on_escape_pressed() -> void:
	match state:
		State.AWAITING_BOARD_DEST:
			_transition_to(State.AWAITING_BOARD_CARD)
		State.AWAITING_BOARD_CARD:
			_transition_to(State.IDLE)

func cancel_interaction() -> void:
	_transition_to(State.IDLE)

# ── Turn lifecycle ─────────────────────────────────────────────────────────────

func on_turn_started(player: Player) -> void:
	if not player.is_human and not _bot_running:
		_run_bot_turn()

# Called by game.gd after the animation for a move finishes.
func notify_animation_done() -> void:
	animation_finished.emit()

func _run_bot_turn() -> void:
	_bot_running = true
	bot_thinking_started.emit()
	var move_delay: float = SaveData.get_setting("bot_move_delay", 0.5)

	while true:
		var move := BotPlayer.get_next_move(game_manager)
		if move == null:
			break
		move_about_to_play.emit(move)
		await animation_finished
		game_manager.apply_move(move)
		if game_manager.is_game_over:
			_bot_running = false
			bot_thinking_ended.emit()
			return
		if move_delay > 0.0:
			await get_tree().create_timer(move_delay).timeout

	var end_move := BotPlayer.get_end_turn_move(game_manager)
	if end_move != null:
		status_updated.emit(game_manager.current_player().name + " finaliza turno...")
		move_about_to_play.emit(end_move)
		await animation_finished
		_bot_running = false
		game_manager.apply_move(end_move)
		bot_thinking_ended.emit()
		return

	_bot_running = false
	bot_thinking_ended.emit()

# ── State machine ─────────────────────────────────────────────────────────────

func _transition_to(new_state: State, custom_status: String = "") -> void:
	match state:
		State.CARD_SELECTED:
			selection_cleared.emit()
			valid_ladders_changed.emit([])
		State.AWAITING_BOARD_DEST:
			board_destinations_visible.emit(false)
			_end_turn_hand_index = -1

	state = new_state

	var status := custom_status
	match new_state:
		State.IDLE:
			board_destinations_visible.emit(false)
			_end_turn_hand_index = -1
			if status.is_empty():
				status = "Your turn"
		State.CARD_SELECTED:
			valid_ladders_changed.emit(game_manager.playable_ladders_for(selected_card))
			if status.is_empty():
				status = "Choose a ladder to play " + selected_card.label()
		State.AWAITING_BOARD_CARD:
			selection_cleared.emit()
			valid_ladders_changed.emit([])
			_end_turn_hand_index = -1
			if status.is_empty():
				status = "Choose a hand card to place on the board. (End Turn or Esc to cancel.)"
		State.AWAITING_BOARD_DEST:
			board_destinations_visible.emit(true)
			if status.is_empty():
				status = "Choose a board column (+). Click another hand card to change. Esc to cancel."

	if not status.is_empty():
		status_updated.emit(status)
