extends Node2D

# ─── Test runner ────────────────────────────────────────────────────────────

var _passed := 0
var _failed := 0
var _suite  := ""

func _ready() -> void:
	print("\n═══════════════════════════════════════════")
	print("  EL POZO — Test Suite")
	print("═══════════════════════════════════════════\n")

	_run_deck_tests()
	_run_player_tests()
	_run_ladder_manager_tests()
	_run_game_manager_tests()
	_run_rules_tests()

	print("\n═══════════════════════════════════════════")
	var total := _passed + _failed
	print("  Resultado: %d/%d passed" % [_passed, total])
	if _failed == 0:
		print("  ✓ Todos los tests pasaron")
	else:
		print("  ✗ %d tests fallaron" % _failed)
	print("═══════════════════════════════════════════\n")

# ─── Assertion helpers ───────────────────────────────────────────────────────

func _suite_header(name: String) -> void:
	_suite = name
	print("▶ " + name)

func ok(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("    ✓ " + description)
	else:
		_failed += 1
		print("    ✗ FAIL: " + description)

func eq(a, b, description: String) -> void:
	if a == b:
		_passed += 1
		print("    ✓ " + description)
	else:
		_failed += 1
		print("    ✗ FAIL: %s  →  got=%s  expected=%s" % [description, str(a), str(b)])

# ─── Card factory helpers ────────────────────────────────────────────────────

func _card(suit: Card.Suit, value: int) -> Card:
	return Card.new(suit, value)

func _ace() -> Card:
	return _card(Card.Suit.SPADES, 1)

func _two() -> Card:
	return _card(Card.Suit.SPADES, 2)

func _king() -> Card:
	return _card(Card.Suit.SPADES, 13)

func _joker() -> Card:
	return _card(Card.Suit.JOKER, 0)

# Build a ladder with cards A through (top_value-1) already placed.
func _ladder_up_to(lm: LadderManager, ladder_idx: int, top_value: int) -> void:
	for v in range(1, top_value):
		var c := _card(Card.Suit.HEARTS, v)
		lm.play_card(c, ladder_idx)

# ─── SUITE 1: Deck ───────────────────────────────────────────────────────────

func _run_deck_tests() -> void:
	_suite_header("Deck")

	# Regla 1: 3 mazos de póker con comodines = 162 cartas
	var d := Deck.build(3)
	eq(d.size(), 162, "build(3) produce 162 cartas")

	# Composición: 3×52 normales + 3×2 jokers
	var jokers := 0
	var normals := 0
	for c in d.cards:
		if c.is_joker:
			jokers += 1
		else:
			normals += 1
	eq(jokers,  6,   "3 mazos contienen 6 comodines")
	eq(normals, 156, "3 mazos contienen 156 cartas normales")

	# draw() devuelve carta y reduce el tamaño
	var before := d.size()
	var drawn := d.draw()
	ok(drawn != null,       "draw() retorna una carta")
	eq(d.size(), before - 1, "draw() reduce el tamaño en 1")

	# draw() en mazo vacío devuelve null
	var empty_deck := Deck.new()
	ok(empty_deck.draw() == null, "draw() en mazo vacío retorna null")

	# draw_many() devuelve exactamente n cartas
	var d2 := Deck.build(1)
	var many := d2.draw_many(5)
	eq(many.size(), 5, "draw_many(5) retorna 5 cartas")
	eq(d2.size(), 54 - 5, "draw_many(5) descuenta 5 del mazo")

	# add_cards() y shuffle no pierden cartas
	var d3 := Deck.build(1)
	var original_size := d3.size()
	var extras: Array[Card] = [_ace(), _two()]
	d3.add_cards(extras)
	eq(d3.size(), original_size + 2, "add_cards() incrementa el tamaño correctamente")

	print()

# ─── SUITE 2: Player ─────────────────────────────────────────────────────────

func _run_player_tests() -> void:
	_suite_header("Player")

	var p := Player.new("Tester", true)

	# Pozo vacío
	ok(p.well_top() == null,  "well_top() en pozo vacío retorna null")
	ok(p.pop_well_top() == null, "pop_well_top() en pozo vacío retorna null")
	ok(p.has_won(),           "has_won() es true con pozo vacío")

	# Llenar pozo y verificar acceso
	for i in range(15):
		p.well.append(_card(Card.Suit.SPADES, (i % 13) + 1))
	var top_before := p.well_top()
	ok(top_before != null,    "well_top() retorna carta cuando pozo tiene cartas")
	ok(!p.has_won(),          "has_won() es false con 15 cartas en el pozo")

	var popped := p.pop_well_top()
	ok(popped == top_before,  "pop_well_top() retorna la misma carta que well_top()")
	eq(p.well.size(), 14,     "pop_well_top() reduce el pozo en 1")

	# Mano y cards_needed()
	eq(p.cards_needed(), 5,   "cards_needed() = 5 cuando mano está vacía")
	p.hand.append(_ace())
	eq(p.cards_needed(), 4,   "cards_needed() = 4 con 1 carta en mano")
	for _i in range(4):
		p.hand.append(_two())
	eq(p.cards_needed(), 0,   "cards_needed() = 0 con 5 cartas en mano")

	# Tablero: nueva columna
	var p2 := Player.new("T2", false)
	ok(p2.push_to_board(_ace(), 0),   "push_to_board crea columna 0 nueva")
	ok(p2.push_to_board(_two(), 1),   "push_to_board crea columna 1 nueva")
	eq(p2.board.size(), 2,             "board tiene 2 columnas tras dos push")

	# Tablero: apilar sobre columna existente
	ok(p2.push_to_board(_card(Card.Suit.HEARTS, 3), 0), "push_to_board apila en columna 0 existente")
	eq(p2.board[0].size(), 2, "columna 0 tiene 2 cartas tras apilar")

	# Tablero: solo se accede al tope
	var tops := p2.board_tops()
	eq(tops.size(), 2, "board_tops() retorna una carta por columna")
	eq(tops[0].value, 3, "tope de columna 0 es la última carta apilada")

	# Tablero: máximo 5 columnas
	var p3 := Player.new("T3", false)
	for i in range(Player.MAX_BOARD_COLUMNS):
		ok(p3.push_to_board(_ace(), i), "puede crear columna %d" % i)
	ok(!p3.push_to_board(_ace(), Player.MAX_BOARD_COLUMNS), "no puede crear columna 6 (máximo 5)")

	# pop_board_top elimina solo el tope
	var p4 := Player.new("T4", false)
	p4.push_to_board(_ace(), 0)
	p4.push_to_board(_two(), 0)
	var popped_top := p4.pop_board_top(0)
	eq(popped_top.value, 2, "pop_board_top retorna la carta del tope")
	eq(p4.board[0].size(), 1, "la columna queda con 1 carta tras pop_board_top")

	print()

# ─── SUITE 3: LadderManager ──────────────────────────────────────────────────

func _run_ladder_manager_tests() -> void:
	_suite_header("LadderManager")

	var lm := LadderManager.new()
	lm.add_ladder_slot()  # index 0
	lm.add_ladder_slot()  # index 1

	# Escalera vacía solo acepta As
	ok(lm.can_play_on(_ace(), 0),  "escalera vacía acepta As (value=1)")
	ok(!lm.can_play_on(_two(), 0), "escalera vacía rechaza 2")
	ok(!lm.can_play_on(_king(), 0),"escalera vacía rechaza K")

	# Secuencia ascendente
	lm.play_card(_ace(), 0)
	ok(lm.can_play_on(_two(), 0),  "tras As, acepta 2")
	ok(!lm.can_play_on(_ace(), 0), "tras As, rechaza otro As")
	ok(!lm.can_play_on(_card(Card.Suit.CLUBS, 3), 0), "tras As, rechaza 3")

	lm.play_card(_two(), 0)
	ok(lm.can_play_on(_card(Card.Suit.DIAMONDS, 3), 0), "tras 2, acepta 3")

	# find_valid_ladder devuelve índice correcto
	var lm2 := LadderManager.new()
	lm2.add_ladder_slot()
	lm2.add_ladder_slot()
	var idx := lm2.find_valid_ladder(_ace())
	ok(idx >= 0, "find_valid_ladder con As encuentra un slot")
	ok(lm2.find_valid_ladder(_two()) == -1, "find_valid_ladder con 2 no encuentra slot vacío")

	# Comodín puede jugar cualquier valor
	var lm3 := LadderManager.new()
	lm3.add_ladder_slot()
	ok(lm3.can_play_on(_joker(), 0, 1),  "comodín con valor 1 abre escalera vacía")
	ok(!lm3.can_play_on(_joker(), 0, 2), "comodín con valor 2 no abre escalera vacía")
	lm3.play_card(_joker(), 0, 1)
	ok(lm3.can_play_on(_two(), 0),        "tras comodín=1, acepta 2")

	# Comodín puede representar cualquier valor en medio de escalera
	var lm4 := LadderManager.new()
	lm4.add_ladder_slot()
	lm4.play_card(_ace(), 0)
	ok(lm4.can_play_on(_joker(), 0, 2),  "comodín puede jugar como 2 sobre As")
	ok(!lm4.can_play_on(_joker(), 0, 5), "comodín como 5 sobre As es inválido (la secuencia necesita 2)")

	# Escalera completa A→K se descarta
	var lm5 := LadderManager.new()
	lm5.add_ladder_slot()
	for v in range(1, 14):
		lm5.play_card(_card(Card.Suit.CLUBS, v), 0)
	ok(lm5.ladders[0].is_empty(), "escalera A→K se vacía (descartada) al completarse")
	ok(lm5.discard_pile.size() == 13, "la pila de descarte tiene las 13 cartas de la escalera")

	# Escalera se puede volver a usar para As después de descartar
	ok(lm5.can_play_on(_ace(), 0), "slot vaciado vuelve a aceptar As")

	# get_discards_for_reshuffle limpia la pila
	var discards := lm5.get_discards_for_reshuffle()
	eq(discards.size(), 13, "get_discards_for_reshuffle retorna 13 cartas")
	eq(lm5.discard_pile.size(), 0, "discard_pile queda vacía tras get_discards_for_reshuffle")

	print()

# ─── SUITE 4: GameManager ────────────────────────────────────────────────────

func _run_game_manager_tests() -> void:
	_suite_header("GameManager")

	# setup() crea el estado inicial correcto
	var gm := _make_gm()
	eq(gm.players.size(), 2,                       "setup() crea 2 jugadores")
	eq(gm.players[0].well.size(), Player.WELL_SIZE, "jugador 0 arranca con pozo de 15")
	eq(gm.players[1].well.size(), Player.WELL_SIZE, "jugador 1 arranca con pozo de 15")
	eq(gm.players[0].hand.size(), Player.MAX_HAND_SIZE, "jugador 0 arranca con 5 cartas en mano")
	eq(gm.players[1].hand.size(), Player.MAX_HAND_SIZE, "jugador 1 arranca con 5 cartas en mano")
	ok(gm.ladder_manager.ladders.size() >= 4,       "setup() crea al menos 4 escaleras")

	# begin_turn() rellena la mano a 5
	var gm2 := _make_controlled_gm()
	var p2 := gm2.current_player()
	p2.hand.clear()
	p2.hand.append(_card(Card.Suit.SPADES, 5))  # solo 1 carta
	# Deck controlado: solo 8s para que begin_turn no auto-juegue Ases del relleno
	gm2.deck.cards.clear()
	for _i in range(10):
		gm2.deck.cards.append(_card(Card.Suit.CLUBS, 8))
	gm2.begin_turn()
	eq(p2.hand.size(), Player.MAX_HAND_SIZE, "begin_turn() rellena mano hasta 5 cartas")

	# begin_turn() juega ases automáticamente
	var gm3 := _make_controlled_gm()
	var p3 := gm3.current_player()
	p3.hand.clear()
	p3.hand.append(_ace())
	p3.hand.append(_ace())
	p3.hand.append(_card(Card.Suit.CLUBS, 7))
	gm3.begin_turn()
	# Los 2 ases deben haber sido jugados automáticamente (+ se rellena la mano)
	for c in p3.hand:
		ok(c.value != 1, "begin_turn() jugó ases: ninguna carta en mano es As")

	# try_play_card desde HAND
	var gm4 := _make_controlled_gm()
	var p4 := gm4.current_player()
	p4.hand.clear()
	p4.hand.append(_ace())
	p4.hand.append(_card(Card.Suit.DIAMONDS, 5))
	var hand_before := p4.hand.size()
	# Escalera vacía acepta As
	var slot := gm4.ladder_manager.find_valid_ladder(_ace())
	if slot == -1:
		gm4.ladder_manager.add_ladder_slot()
		slot = gm4.ladder_manager.ladders.size() - 1
	var ok4 := gm4.try_play_card(GameManager.CardSource.HAND, 0, slot)
	ok(ok4,                                   "try_play_card(HAND, As) retorna true")
	eq(p4.hand.size(), hand_before - 1,        "try_play_card(HAND) quita carta de la mano")

	# try_play_card: jugada inválida retorna false
	var gm5 := _make_controlled_gm()
	var p5 := gm5.current_player()
	p5.hand.clear()
	p5.hand.append(_king())  # K no abre escalera vacía
	var first_slot := 0
	while first_slot < gm5.ladder_manager.ladders.size() and not gm5.ladder_manager.ladders[first_slot].is_empty():
		first_slot += 1
	if first_slot < gm5.ladder_manager.ladders.size():
		var nok := gm5.try_play_card(GameManager.CardSource.HAND, 0, first_slot)
		ok(!nok, "try_play_card con K en escalera vacía retorna false")

	# try_play_card desde WELL
	var gm6 := _make_controlled_gm()
	var p6 := gm6.current_player()
	p6.well.clear()
	p6.well.append(_ace())
	var well_slot := _find_empty_slot(gm6)
	var ok6 := gm6.try_play_card(GameManager.CardSource.WELL, 0, well_slot)
	ok(ok6,                    "try_play_card(WELL, As) retorna true")
	ok(p6.well.is_empty(),     "try_play_card(WELL) consume la carta del pozo")

	# try_play_card desde BOARD
	var gm7 := _make_controlled_gm()
	var p7 := gm7.current_player()
	p7.board.clear()
	p7.board.append([_ace()])  # columna 0 con As
	var board_slot := _find_empty_slot(gm7)
	var ok7 := gm7.try_play_card(GameManager.CardSource.BOARD, 0, board_slot)
	ok(ok7,                       "try_play_card(BOARD, As) retorna true")
	ok(p7.board[0].is_empty(),    "try_play_card(BOARD) consume la carta del tablero")

	# Relleno de mano durante el turno (mano vacía → se rellena)
	var gm8 := _make_controlled_gm()
	var p8 := gm8.current_player()
	p8.hand.clear()
	p8.hand.append(_ace())  # 1 carta
	var sl8 := _find_empty_slot(gm8)
	gm8.try_play_card(GameManager.CardSource.HAND, 0, sl8)
	# La mano quedó vacía → debe haberse rellenado
	ok(p8.hand.size() > 0, "mano vacía durante turno se rellena automáticamente")

	# try_end_turn coloca carta en tablero y avanza el turno
	var gm9 := _make_controlled_gm()
	var p9 := gm9.current_player()
	p9.hand.clear()
	p9.hand.append(_card(Card.Suit.CLUBS, 7))
	var prev_idx := gm9.current_player_index
	var end_ok := gm9.try_end_turn(0, 0)
	ok(end_ok, "try_end_turn retorna true con carta en mano")
	ok(gm9.current_player_index != prev_idx, "try_end_turn avanza al siguiente jugador")

	# try_end_turn sin cartas en mano retorna false
	var gm10 := _make_controlled_gm()
	gm10.current_player().hand.clear()
	ok(!gm10.try_end_turn(0, 0), "try_end_turn sin mano retorna false")

	# Señal game_won cuando el pozo se vacía
	# Usamos Array para que el lambda capture por referencia (bool se captura por valor)
	var gm11 := _make_controlled_gm()
	var p11 := gm11.current_player()
	var won_signals: Array = []
	gm11.game_won.connect(func(w): won_signals.append(w))
	p11.well.clear()
	p11.well.append(_ace())  # 1 carta en pozo
	p11.hand.clear()
	p11.hand.append(_card(Card.Suit.CLUBS, 5))
	var ws := _find_empty_slot(gm11)
	gm11.try_play_card(GameManager.CardSource.WELL, 0, ws)
	ok(won_signals.size() > 0, "señal game_won se emite cuando el pozo queda vacío")

	print()

# ─── SUITE 5: Reglas del juego ───────────────────────────────────────────────

func _run_rules_tests() -> void:
	_suite_header("Reglas")

	# Regla: Escalera A→K completa (13 cartas) se descarta
	var lm := LadderManager.new()
	lm.add_ladder_slot()
	for v in range(1, 14):
		lm.play_card(_card(Card.Suit.SPADES, v), 0)
	ok(lm.ladders[0].is_empty(),   "Regla 4: escalera A→K se descarta al llegar a K")
	eq(lm.discard_pile.size(), 13, "Regla 4: los 13 descartados están en discard_pile")

	# Regla: Escalera no acepta mismo valor dos veces
	var lm2 := LadderManager.new()
	lm2.add_ladder_slot()
	lm2.play_card(_ace(), 0)
	ok(!lm2.can_play_on(_ace(), 0), "Regla 4: no se puede repetir el mismo valor (As sobre As)")

	# Regla: Ases obligatorios al inicio del turno
	var gm := _make_controlled_gm()
	var p := gm.current_player()
	p.hand.clear()
	p.hand.append(_ace())
	p.hand.append(_ace())
	p.hand.append(_card(Card.Suit.DIAMONDS, 9))
	gm.begin_turn()
	var ace_remaining := false
	for c in p.hand:
		if c.value == 1:
			ace_remaining = true
	ok(!ace_remaining, "Regla 5: ases en mano se juegan automáticamente al iniciar turno")

	# Regla: Comodín puede representar cualquier valor As→K
	var lm3 := LadderManager.new()
	lm3.add_ladder_slot()
	for v in range(1, 14):
		ok(lm3.can_play_on(_joker(), 0, v) == (v == 1),
		   "Regla 6: comodín como %d en escalera vacía → %s" % [v, str(v == 1)])

	# Regla: Comodín como cualquier valor en medio de escalera
	var lm4 := LadderManager.new()
	lm4.add_ladder_slot()
	lm4.play_card(_ace(), 0)
	lm4.play_card(_two(), 0)
	# Siguiente debe ser 3 → comodín como 3 debe funcionar
	ok(lm4.can_play_on(_joker(), 0, 3),  "Regla 6: comodín como 3 sobre [A,2] es válido")
	ok(!lm4.can_play_on(_joker(), 0, 5), "Regla 6: comodín como 5 sobre [A,2] es inválido")

	# Regla: Tablero personal máximo 5 columnas
	var p2 := Player.new("R", false)
	for i in range(Player.MAX_BOARD_COLUMNS):
		p2.push_to_board(_ace(), i)
	ok(!p2.push_to_board(_two(), Player.MAX_BOARD_COLUMNS),
	   "Regla 7: tablero no acepta más de 5 columnas")

	# Regla: Solo se accede al tope del tablero (no cartas enterradas)
	var p3 := Player.new("R2", false)
	p3.push_to_board(_ace(), 0)
	p3.push_to_board(_two(), 0)  # apila sobre columna 0
	var tops := p3.board_tops()
	eq(tops.size(), 1,      "Regla 7: board_tops retorna 1 carta por columna")
	eq(tops[0].value, 2,    "Regla 7: el tope es la última carta apilada (2, no el As)")

	# Regla: Inicio de turno → mano se rellena a 5
	var gm2 := _make_controlled_gm()
	var p4 := gm2.current_player()
	p4.hand.clear()
	p4.hand.append(_card(Card.Suit.CLUBS, 8))  # solo 1 carta, sin As
	# Deck controlado: solo 8s para que begin_turn no auto-juegue Ases del relleno
	gm2.deck.cards.clear()
	for _i in range(10):
		gm2.deck.cards.append(_card(Card.Suit.CLUBS, 8))
	gm2.begin_turn()
	eq(p4.hand.size(), Player.MAX_HAND_SIZE, "Regla 8: mano se rellena a 5 al iniciar turno")

	# Regla: Mano se rellena durante el turno si se vacía
	var gm3 := _make_controlled_gm()
	var p5 := gm3.current_player()
	p5.hand.clear()
	p5.hand.append(_ace())
	var sl := _find_empty_slot(gm3)
	gm3.try_play_card(GameManager.CardSource.HAND, 0, sl)
	ok(p5.hand.size() > 0, "Regla 12: mano se rellena automáticamente si se vacía durante el turno")

	# Regla: Fin de turno obliga a bajar carta al tablero
	var gm4 := _make_controlled_gm()
	var p6 := gm4.current_player()
	p6.hand.clear()
	p6.hand.append(_card(Card.Suit.SPADES, 7))
	var board_before := p6.board.size()
	gm4.try_end_turn(0, board_before)
	eq(p6.board.size(), board_before + 1, "Regla 13: fin de turno agrega 1 columna al tablero")

	# Regla: Victoria = pozo vacío
	var p7 := Player.new("Winner", true)
	p7.well.append(_ace())  # agregar carta antes de chequear
	ok(!p7.has_won(), "Regla 2: jugador con 1 carta en pozo no ha ganado")
	p7.well.clear()
	ok(p7.has_won(),  "Regla 2: jugador con pozo vacío ha ganado")

	# Regla: Pozo encadenado — jugar tope revela la siguiente carta
	var gm5 := _make_controlled_gm()
	var p8 := gm5.current_player()
	p8.well.clear()
	p8.well.append(_card(Card.Suit.HEARTS, 3))  # índice 0 (fondo)
	p8.well.append(_ace())                       # índice 1 (tope visible)
	var sl2 := _find_empty_slot(gm5)
	gm5.try_play_card(GameManager.CardSource.WELL, 0, sl2)
	eq(p8.well.size(), 1,        "Regla 11: jugar tope del pozo revela la siguiente carta")
	eq(p8.well_top().value, 3,   "Regla 11: la nueva carta visible es la que estaba debajo")

	# Regla: Mazo vacío → se remezclan los descartados
	var gm6 := _make_controlled_gm()
	# Completar una escalera para generar descartados
	var lm6 := gm6.ladder_manager
	lm6.add_ladder_slot()
	var sl6 := lm6.ladders.size() - 1
	for v in range(1, 14):
		lm6.play_card(_card(Card.Suit.DIAMONDS, v), sl6)
	# Vaciar el mazo
	gm6.deck.cards.clear()
	var p9 := gm6.current_player()
	p9.hand.clear()
	# begin_turn intentará rellenar → debe remezclar descartados
	gm6.begin_turn()
	ok(p9.hand.size() > 0, "Regla 15: mazo vacío → descartados se remezclan para rellenar mano")

	print()

# ─── Helpers de setup ────────────────────────────────────────────────────────

# GameManager con estado controlado (sin aleatoriedad en current_player_index)
func _make_controlled_gm() -> GameManager:
	var gm := GameManager.new()
	gm.setup()
	gm.current_player_index = 0
	return gm

# GameManager standard (usa randomización normal)
func _make_gm() -> GameManager:
	var gm := GameManager.new()
	gm.setup()
	return gm

# Encuentra el primer slot de escalera vacío
func _find_empty_slot(gm: GameManager) -> int:
	for i in range(gm.ladder_manager.ladders.size()):
		if gm.ladder_manager.ladders[i].is_empty():
			return i
	gm.ladder_manager.add_ladder_slot()
	return gm.ladder_manager.ladders.size() - 1
