class_name Player
extends RefCounted

var name: String
var is_human: bool
var player_number: int = 0

# well: index 0 = bottom, last = top (visible)
var well: Array[Card] = []
var hand: Array[Card] = []
# board: array of columns; each column is Array[Card] (last = top/accessible)
var board: Array = []

const MAX_HAND_SIZE := 5
const MAX_BOARD_COLUMNS := 5

func _init(p_name: String, p_is_human: bool) -> void:
	name = p_name
	is_human = p_is_human

func well_top() -> Card:
	return well.back() if not well.is_empty() else null

func pop_well_top() -> Card:
	return well.pop_back() if not well.is_empty() else null

func get_board_columns() -> Array:
	return board

func board_tops() -> Array[Card]:
	var tops: Array[Card] = []
	for col in board:
		if not col.is_empty():
			tops.append(col.back())
	return tops

func board_top(col_index: int) -> Card:
	if col_index < board.size() and not board[col_index].is_empty():
		return board[col_index].back()
	return null

func next_board_col_for_placement() -> int:
	for i in range(board.size()):
		if (board[i] as Array).is_empty():
			return i
	if board.size() < MAX_BOARD_COLUMNS:
		return board.size()
	return -1

func pop_board_top(col_index: int) -> Card:
	if col_index < board.size() and not board[col_index].is_empty():
		return board[col_index].pop_back()
	return null

func push_to_board(card: Card, col_index: int) -> bool:
	if col_index < board.size():
		board[col_index].append(card)
		return true
	if board.size() < MAX_BOARD_COLUMNS:
		board.append([card])
		return true
	return false

func cards_needed() -> int:
	return MAX_HAND_SIZE - hand.size()

func has_won() -> bool:
	return well.is_empty()
