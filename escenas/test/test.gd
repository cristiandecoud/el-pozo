extends Node2D

func _ready() -> void:
	# --- Fase 1 ---
	var deck = Deck.build(3)
	print("Deck size: ", deck.size())  # 162
	var p = Player.new("Test", true)
	for i in range(15):
		p.well.append(deck.draw())
	for i in range(5):
		p.hand.append(deck.draw())
	print("Well: ", p.well.size())    # 15
	print("Hand: ", p.hand.size())    # 5
	print("Top:  ", p.well_top().label())

	# --- Fase 2 ---
	var gm = GameManager.new()
	gm.setup()
	print("Current player: ", gm.current_player().name)
	print("Ladders: ", gm.ladder_manager.ladders.size())  # 4+
	gm.begin_turn()
	# Intentar jugar la primera carta de la mano en la primera escalera
	var ok = gm.try_play_card(GameManager.CardSource.HAND, 0, 0)
	print("Play result: ", ok)
