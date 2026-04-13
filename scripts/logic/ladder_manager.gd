class_name LadderManager
extends RefCounted

# Each ladder is Array[Card]. Empty array = free slot (needs Ace to start).
var ladders: Array = []
var discard_pile: Array[Card] = []

func can_play_on(card: Card, ladder_index: int, joker_as_value: int = 0) -> bool:
	var effective_value := card.value if not card.is_joker else joker_as_value
	var ladder: Array = ladders[ladder_index]
	if ladder.is_empty():
		return effective_value == 1
	return effective_value == _top_value(ladder) + 1

func find_valid_ladder(card: Card, joker_as_value: int = 0) -> int:
	for i in range(ladders.size()):
		if can_play_on(card, i, joker_as_value):
			return i
	return -1

func play_card(card: Card, ladder_index: int, joker_as_value: int = 0) -> void:
	if card.is_joker:
		card.value = joker_as_value  # lock joker value into ladder context
	ladders[ladder_index].append(card)
	if _is_complete(ladders[ladder_index]):
		discard_pile.append_array(ladders[ladder_index])
		ladders[ladder_index] = []

func add_ladder_slot() -> void:
	ladders.append([])

func get_discards_for_reshuffle() -> Array[Card]:
	var result: Array[Card] = discard_pile.duplicate()
	discard_pile.clear()
	return result

func _top_value(ladder: Array) -> int:
	return ladder.back().value

func _is_complete(ladder: Array) -> bool:
	return not ladder.is_empty() and _top_value(ladder) == 13
