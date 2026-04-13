class_name GameManager
extends RefCounted

signal turn_started(player: Player)
signal turn_ended(player: Player)
signal game_won(player: Player)
signal state_changed()

enum CardSource { HAND, WELL, BOARD }

var deck: Deck
var ladder_manager: LadderManager
var players: Array[Player] = []
var current_player_index: int = 0

const INITIAL_LADDERS := 4

func setup() -> void:
	deck = Deck.build(3)
	ladder_manager = LadderManager.new()
	for _i in range(INITIAL_LADDERS):
		ladder_manager.add_ladder_slot()

	players.clear()
	players.append(Player.new("You", true))
	players.append(Player.new("Bot", false))

	for player in players:
		for _i in range(Player.WELL_SIZE):
			player.well.append(deck.draw())
		for _i in range(Player.MAX_HAND_SIZE):
			player.hand.append(deck.draw())

	current_player_index = randi() % players.size()

func current_player() -> Player:
	return players[current_player_index]

func begin_turn() -> void:
	var p := current_player()
	_refill_hand(p)
	_play_mandatory_aces(p)
	turn_started.emit(p)
	state_changed.emit()

func _refill_hand(player: Player) -> void:
	var needed := player.cards_needed()
	if needed <= 0:
		return
	var drawn := deck.draw_many(needed)
	player.hand.append_array(drawn)
	if player.hand.size() < Player.MAX_HAND_SIZE:
		# Deck ran out — reshuffle discards and try again
		_reshuffle_from_discards()
		player.hand.append_array(deck.draw_many(player.cards_needed()))

func _reshuffle_from_discards() -> void:
	var discards := ladder_manager.get_discards_for_reshuffle()
	if not discards.is_empty():
		deck.add_cards(discards)

func _play_mandatory_aces(player: Player) -> void:
	var i := 0
	while i < player.hand.size():
		var card := player.hand[i]
		if card.value == 1:  # Ace
			var slot := ladder_manager.find_valid_ladder(card)
			if slot == -1:
				ladder_manager.add_ladder_slot()
				slot = ladder_manager.ladders.size() - 1
			player.hand.remove_at(i)
			ladder_manager.play_card(card, slot)
		else:
			i += 1

func try_play_card(source: CardSource, source_index: int,
				   ladder_index: int, joker_as_value: int = 0) -> bool:
	var player := current_player()
	var card: Card = null

	match source:
		CardSource.HAND:
			if source_index < player.hand.size():
				card = player.hand[source_index]
		CardSource.WELL:
			card = player.well_top()
		CardSource.BOARD:
			if source_index < player.board.size() and \
			   not player.board[source_index].is_empty():
				card = player.board[source_index].back()

	if card == null:
		return false

	var effective_value := card.value if not card.is_joker else joker_as_value
	if not ladder_manager.can_play_on(card, ladder_index, effective_value):
		return false

	# Remove card from source
	match source:
		CardSource.HAND:
			player.hand.remove_at(source_index)
		CardSource.WELL:
			player.pop_well_top()
		CardSource.BOARD:
			player.pop_board_top(source_index)

	ladder_manager.play_card(card, ladder_index, effective_value)

	# Mid-turn hand refill
	if player.hand.is_empty():
		_refill_hand(player)

	if player.has_won():
		game_won.emit(player)

	state_changed.emit()
	return true

func try_end_turn(hand_card_index: int, board_col: int) -> bool:
	var player := current_player()
	if player.hand.is_empty() or hand_card_index >= player.hand.size():
		return false

	var card := player.hand[hand_card_index]
	player.hand.remove_at(hand_card_index)
	player.push_to_board(card, board_col)

	turn_ended.emit(player)
	state_changed.emit()
	_advance_turn()
	return true

func _advance_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	begin_turn()
