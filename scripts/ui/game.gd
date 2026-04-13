extends Control

enum InteractionState { IDLE, CARD_SELECTED, AWAITING_BOARD_COL }

var game_manager: GameManager
var state: InteractionState = InteractionState.IDLE
var selected_source: GameManager.CardSource
var selected_index: int
var selected_card: Card

const PlayerAreaScene := preload("res://escenas/ui/player_area/player_area.tscn")
const LadderScene     := preload("res://escenas/ui/ladder/ladder.tscn")
const HUDScene        := preload("res://escenas/ui/hud/hud.tscn")

@onready var opponent_row: HBoxContainer      = $Layout/OpponentRow
@onready var human_row: HBoxContainer         = $Layout/HumanRow
@onready var ladders_container: HBoxContainer = $Layout/CentralArea/LaddersContainer
@onready var deck_count: Label                = $Layout/CentralArea/DeckArea/DeckCount
@onready var layout: VBoxContainer            = $Layout

var human_area: PlayerAreaView
var bot_area: PlayerAreaView
var hud: HUDView

func _ready() -> void:
	game_manager = GameManager.new()
	game_manager.state_changed.connect(_refresh_all)
	game_manager.game_won.connect(_on_game_won)
	game_manager.turn_started.connect(_on_turn_started)

	# Instanciar áreas de jugadores
	human_area = PlayerAreaScene.instantiate()
	human_area.show_hand = true
	human_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_area.card_selected.connect(_on_human_card_selected)
	human_row.add_child(human_area)

	bot_area = PlayerAreaScene.instantiate()
	bot_area.show_hand = false
	bot_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opponent_row.add_child(bot_area)

	# HUD al final del Layout (debajo de todo)
	hud = HUDScene.instantiate()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.end_turn_requested.connect(_on_end_turn_pressed)
	layout.add_child(hud)

	game_manager.setup()
	game_manager.begin_turn()

func _refresh_all() -> void:
	human_area.refresh(game_manager.players[0])
	bot_area.refresh(game_manager.players[1])
	_rebuild_ladders()
	deck_count.text = "Mazo: " + str(game_manager.deck.size())
	hud.refresh(game_manager)

func _rebuild_ladders() -> void:
	for child in ladders_container.get_children():
		child.queue_free()
	for i in range(game_manager.ladder_manager.ladders.size()):
		var lv: LadderView = LadderScene.instantiate()
		lv.ladder_data = game_manager.ladder_manager.ladders[i]
		lv.ladder_index = i
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.ladder_clicked.connect(_on_ladder_clicked)
		ladders_container.add_child(lv)

func _on_human_card_selected(source: GameManager.CardSource,
							  index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return

	# En modo fin de turno: click en carta de mano la baja al tablero directamente
	if state == InteractionState.AWAITING_BOARD_COL:
		if source == GameManager.CardSource.HAND:
			var col := game_manager.current_player().board.size()
			_do_end_turn(index, col)
		return

	selected_source = source
	selected_index = index
	selected_card = card
	state = InteractionState.CARD_SELECTED
	hud.set_status("Elegí una escalera para jugar " + card.label())

func _on_ladder_clicked(ladder_index: int) -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var joker_value := 0
	if selected_card.is_joker:
		joker_value = _ask_joker_value()
	var ok := game_manager.try_play_card(
		selected_source, selected_index, ladder_index, joker_value)
	if not ok:
		hud.set_status("No se puede jugar ahí. Elegí otra escalera.")
	else:
		hud.set_status("Jugaste " + selected_card.label() + ". Seguí jugando o terminá el turno.")
	state = InteractionState.IDLE

func _on_end_turn_pressed() -> void:
	if game_manager.current_player().hand.is_empty():
		hud.set_status("No tenés cartas en mano para bajar al tablero.")
		return
	state = InteractionState.AWAITING_BOARD_COL
	hud.set_status("Elegí una carta de tu mano para bajar al tablero.")

func _do_end_turn(hand_index: int, board_col: int) -> void:
	var ok := game_manager.try_end_turn(hand_index, board_col)
	if not ok:
		hud.set_status("No se pudo terminar el turno.")
	state = InteractionState.IDLE

func _ask_joker_value() -> int:
	return 1

func _on_turn_started(player: Player) -> void:
	if not player.is_human:
		hud.set_status("Bot está pensando...")
		await get_tree().create_timer(0.8).timeout
		BotPlayer.play(game_manager)
		_refresh_all()
		hud.set_status("Tu turno")

func _on_game_won(player: Player) -> void:
	hud.set_status("¡" + player.name + " ganó!")
	hud.disable_actions()
