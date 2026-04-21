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
var is_game_over: bool = false
var cards_played: int = 0
var turn_count: int = 0

const INITIAL_LADDERS := 4

func setup(player_name: String = "You",
		   bot_count:   int    = 1) -> void:
	var player_count := bot_count + 1
	var well_size: int = SaveData.get_setting("well_size", 2) as int
	deck = Deck.build(_decks_for(player_count))
	ladder_manager = LadderManager.new()
	for _i in range(INITIAL_LADDERS):
		ladder_manager.add_ladder_slot()

	cards_played = 0
	turn_count   = 0
	players.clear()
	var human          := Player.new(player_name, true)
	human.player_number = 1
	players.append(human)

	for i in range(bot_count):
		var bot            := Player.new("Bot " + str(i + 1), false)
		bot.player_number   = i + 2
		players.append(bot)

	for player in players:
		for _i in range(well_size):
			player.well.append(deck.draw())
		for _i in range(Player.MAX_HAND_SIZE):
			player.hand.append(deck.draw())

	current_player_index = randi() % players.size()

# Fórmula: 2 jugadores → 3 mazos; +1 mazo cada 2 jugadores adicionales
# 2→3  3→4  4→4  5→5
static func _decks_for(player_count: int) -> int:
	return 3 + ((player_count - 1) >> 1)  # >>1 equivale a /2 entera: 2→3 3→4 4→4 5→5

func current_player() -> Player:
	return players[current_player_index]

func human_player() -> Player:
	return players[0]

func bot_players() -> Array[Player]:
	var bots: Array[Player] = []
	for p in players:
		if not p.is_human:
			bots.append(p)
	return bots

func deck_size() -> int:
	return deck.size()

func ladder_count() -> int:
	return ladder_manager.ladders.size()

func ladder_at(index: int) -> Array:
	return ladder_manager.ladders[index]

func card_at(source: CardSource, source_index: int) -> Card:
	var player := current_player()
	match source:
		CardSource.HAND:
			if source_index >= 0 and source_index < player.hand.size():
				return player.hand[source_index]
		CardSource.WELL:
			return player.well_top()
		CardSource.BOARD:
			if source_index >= 0 and source_index < player.board.size() and \
			   not player.board[source_index].is_empty():
				return player.board[source_index].back()
	return null

func playable_ladders_for(card: Card) -> Array[int]:
	var valid: Array[int] = []
	if card == null:
		return valid
	for i in range(ladder_manager.ladders.size()):
		if ladder_manager.can_play_on(card, i, _effective_value_for(card, i)):
			valid.append(i)
	return valid

func can_start_new_ladder(card: Card) -> bool:
	return card != null and (card.value == 1 or card.is_joker)

func preferred_ladder_for(card: Card) -> int:
	var valid := playable_ladders_for(card)
	return valid[0] if not valid.is_empty() else -1

func begin_turn() -> void:
	if is_game_over:
		return
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
				   ladder_index: int) -> bool:
	if is_game_over:
		return false
	var player := current_player()
	var card := card_at(source, source_index)
	if card == null:
		return false

	var effective_value := _effective_value_for(card, ladder_index)
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
	cards_played += 1

	# Mid-turn hand refill
	if player.hand.is_empty():
		_refill_hand(player)

	if player.has_won():
		is_game_over = true
		SaveData.record_game_result(players[0].name, player.is_human, turn_count, cards_played)
		game_won.emit(player)
		state_changed.emit()
		return true

	state_changed.emit()
	return true

func try_end_turn(hand_card_index: int, board_col: int) -> bool:
	if is_game_over:
		return false
	var player := current_player()
	if player.hand.is_empty() or hand_card_index >= player.hand.size():
		return false

	var card := player.hand[hand_card_index]
	player.hand.remove_at(hand_card_index)
	if not player.push_to_board(card, board_col):
		player.hand.insert(hand_card_index, card)  # devolver la carta si no hay lugar
		return false

	turn_count += 1
	turn_ended.emit(player)
	state_changed.emit()
	_advance_turn()
	return true

func _advance_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	begin_turn()

func run_bot_turn() -> void:
	if is_game_over or current_player().is_human:
		return
	BotPlayer.play(self)

func try_start_new_ladder(source: CardSource, source_index: int) -> bool:
	var card := card_at(source, source_index)
	if not can_start_new_ladder(card):
		return false
	ladder_manager.add_ladder_slot()
	var new_idx := ladder_manager.ladders.size() - 1
	if not try_play_card(source, source_index, new_idx):
		ladder_manager.ladders.remove_at(new_idx)
		return false
	return true

func _effective_value_for(card: Card, ladder_index: int) -> int:
	if card == null:
		return 0
	if not card.is_joker:
		return card.value
	return ladder_manager.joker_value_for(ladder_index)
