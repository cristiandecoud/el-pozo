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

const INITIAL_LADDERS := 4

const PLAYER_COLORS: Array[Color] = [
	Color("#F5C518"),   # Dorado  — humano por defecto
	Color("#3B82F6"),   # Azul
	Color("#22C55E"),   # Verde
	Color("#EF4444"),   # Rojo
	Color("#A855F7"),   # Violeta
]

func setup(player_name:  String = "You",
		   player_color: Color  = Color("#F5C518"),
		   bot_count:    int    = 1) -> void:
	var player_count := bot_count + 1
	var well_size: int = SaveData.get_setting("well_size", 2) as int
	deck = Deck.build(_decks_for(player_count))
	ladder_manager = LadderManager.new()
	for _i in range(INITIAL_LADDERS):
		ladder_manager.add_ladder_slot()

	players.clear()
	var human       := Player.new(player_name, true)
	human.color      = player_color
	players.append(human)

	var color_pool := PLAYER_COLORS.duplicate()
	color_pool.erase(player_color)
	for i in range(bot_count):
		var bot   := Player.new("Bot " + str(i + 1), false)
		bot.color  = color_pool[i % color_pool.size()]
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
				   ladder_index: int, joker_as_value: int = 0) -> bool:
	if is_game_over:
		return false
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
		is_game_over = true
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

	turn_ended.emit(player)
	state_changed.emit()
	_advance_turn()
	return true

func _advance_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	begin_turn()
