class_name BotPlayer
extends RefCounted

static func play(gm: GameManager) -> void:
	var player := gm.current_player()
	var moved := true

	while moved:
		moved = false

		# Priority 1: well top (most important — path to victory)
		var well_card := player.well_top()
		if well_card != null:
			var slot := _find_slot(gm, well_card)
			if slot != -1:
				gm.try_play_card(GameManager.CardSource.WELL, 0, slot,
								 _best_joker_value(gm, well_card))
				moved = true
				continue

		# Priority 2: board tops
		for col_i in range(player.board.size()):
			if player.board[col_i].is_empty():
				continue
			var bc: Card = player.board[col_i].back()
			var slot := _find_slot(gm, bc)
			if slot != -1:
				gm.try_play_card(GameManager.CardSource.BOARD, col_i, slot,
								 _best_joker_value(gm, bc))
				moved = true
				break

		if moved:
			continue

		# Priority 3: hand cards
		for hi in range(player.hand.size()):
			var hc := player.hand[hi]
			var slot := _find_slot(gm, hc)
			if slot != -1:
				gm.try_play_card(GameManager.CardSource.HAND, hi, slot,
								 _best_joker_value(gm, hc))
				moved = true
				break

	_end_turn(gm, player)

static func _find_slot(gm: GameManager, card: Card) -> int:
	if card.is_joker:
		for v in range(1, 14):
			var s := gm.ladder_manager.find_valid_ladder(card, v)
			if s != -1:
				return s
		return -1
	return gm.ladder_manager.find_valid_ladder(card)

static func _best_joker_value(gm: GameManager, card: Card) -> int:
	if not card.is_joker:
		return 0
	for v in range(1, 14):
		if gm.ladder_manager.find_valid_ladder(card, v) != -1:
			return v
	return 1

static func _end_turn(gm: GameManager, player: Player) -> void:
	if gm.is_game_over or player.hand.is_empty():
		return
	# Place highest-value card on board (least useful for ladders)
	var worst_i := 0
	for i in range(1, player.hand.size()):
		if player.hand[i].value > player.hand[worst_i].value:
			worst_i = i

	var col := _pick_board_col(player)
	gm.try_end_turn(worst_i, col)

static func _pick_board_col(player: Player) -> int:
	# Prefer reusing a column that's already been emptied (cards moved to ladders)
	for i in range(player.board.size()):
		if player.board[i].is_empty():
			return i
	# All existing columns have cards — create a new one if room allows
	if player.board.size() < Player.MAX_BOARD_COLUMNS:
		return player.board.size()
	# Board is full — overwrite the column whose top card has the highest value
	# (high-value cards are hardest to play on ladders, so least useful there)
	var worst := 0
	for i in range(1, player.board.size()):
		if player.board[i].back().value > player.board[worst].back().value:
			worst = i
	return worst
