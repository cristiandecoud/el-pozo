class_name BotPlayer
extends RefCounted

# Returns the next valid move according to priority (well → board → hand),
# or null if no more moves are available. Does NOT modify game state.
static func get_next_move(gm: GameManager) -> CardMoveEvent:
	var player := gm.current_player()
	var player_index := gm.current_player_index

	# Priority 1: well top
	var well_card := player.well_top()
	if well_card != null:
		var slot := gm.preferred_ladder_for(well_card)
		if slot != -1:
			return _make_event(player_index, GameManager.CardSource.WELL, 0, slot, well_card)

	# Priority 2: board tops
	for col_i in range(player.board.size()):
		if player.board[col_i].is_empty():
			continue
		var bc: Card = player.board[col_i].back()
		var slot := gm.preferred_ladder_for(bc)
		if slot != -1:
			return _make_event(player_index, GameManager.CardSource.BOARD, col_i, slot, bc)

	# Priority 3: hand cards
	for hi in range(player.hand.size()):
		var hc := player.hand[hi]
		var slot := gm.preferred_ladder_for(hc)
		if slot != -1:
			return _make_event(player_index, GameManager.CardSource.HAND, hi, slot, hc)

	return null

# Returns the end-of-turn move (place worst hand card on board), or null if hand empty.
# Does NOT modify game state.
static func get_end_turn_move(gm: GameManager) -> CardMoveEvent:
	var player := gm.current_player()
	if gm.is_game_over or player.hand.is_empty():
		return null

	var worst_i := 0
	for i in range(1, player.hand.size()):
		if player.hand[i].value > player.hand[worst_i].value:
			worst_i = i

	var col := _pick_board_col(player)
	var ev := CardMoveEvent.new()
	ev.player_index = gm.current_player_index
	ev.source       = GameManager.CardSource.HAND
	ev.source_index = worst_i
	ev.dest_type    = CardMoveEvent.DestType.BOARD
	ev.dest_index   = col
	ev.card         = player.hand[worst_i]
	return ev

static func _make_event(player_index: int, source: GameManager.CardSource,
		source_index: int, ladder_index: int, card: Card) -> CardMoveEvent:
	var ev := CardMoveEvent.new()
	ev.player_index = player_index
	ev.source       = source
	ev.source_index = source_index
	ev.dest_type    = CardMoveEvent.DestType.LADDER
	ev.dest_index   = ladder_index
	ev.card         = card
	return ev

static func _pick_board_col(player: Player) -> int:
	for i in range(player.board.size()):
		if player.board[i].is_empty():
			return i
	if player.board.size() < Player.MAX_BOARD_COLUMNS:
		return player.board.size()
	var worst := 0
	for i in range(1, player.board.size()):
		if player.board[i].back().value > player.board[worst].back().value:
			worst = i
	return worst
