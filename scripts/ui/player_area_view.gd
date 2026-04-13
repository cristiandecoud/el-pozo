class_name PlayerAreaView
extends VBoxContainer

signal card_selected(source: GameManager.CardSource, index: int, card: Card)

var show_hand: bool = true

@onready var name_label: Label = $PlayerName
@onready var well_count: Label = $WellAndBoard/Well/WellCount
@onready var well_top_slot: Control = $WellAndBoard/Well/WellTopSlot
@onready var board_container: HBoxContainer = $WellAndBoard/Board
@onready var hand_container: HBoxContainer = $Hand

const CardScene := preload("res://escenas/ui/card/card.tscn")

func refresh(player: Player) -> void:
	name_label.text = player.name + " — Pozo: " + str(player.well.size())

	# Well top
	for child in well_top_slot.get_children():
		child.queue_free()
	if player.well_top() != null:
		var cv: CardView = CardScene.instantiate()
		cv.card_data = player.well_top()
		cv.card_clicked.connect(
			func(_v): card_selected.emit(GameManager.CardSource.WELL, 0,
										 player.well_top()))
		well_top_slot.add_child(cv)

	# Board tops
	_rebuild_cards(board_container, player.board_tops(),
				   GameManager.CardSource.BOARD)

	# Hand
	if show_hand:
		_rebuild_cards(hand_container, player.hand,
					   GameManager.CardSource.HAND)
	else:
		for child in hand_container.get_children():
			child.queue_free()
		for _i in range(player.hand.size()):
			var cv: CardView = CardScene.instantiate()
			cv.face_down = true
			hand_container.add_child(cv)

func _rebuild_cards(container: HBoxContainer, cards: Array[Card],
					source: GameManager.CardSource) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in range(cards.size()):
		var cv: CardView = CardScene.instantiate()
		cv.card_data = cards[i]
		var idx := i
		cv.card_clicked.connect(
			func(_v): card_selected.emit(source, idx, cards[idx]))
		container.add_child(cv)
