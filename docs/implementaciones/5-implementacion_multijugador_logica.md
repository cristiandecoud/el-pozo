# El Pozo — Multijugador: lógica y tests (Fases 25–30)

Continuación de `4-implementacion_menus.md`. Este documento cubre:

- Infraestructura de tests unitarios (framework propio, sin plugins externos)
- Tests de las reglas del juego (escaleras, victoria, ases, mano, bot)
- Modelo de datos para múltiples jugadores: colores, mazos escalables, `WELL_SIZE` configurable, delay de bots

**El rediseño visual del tablero** para múltiples jugadores se cubre en `6-implementacion_multijugador_ui.md`, que es prerequisito para poder validar visualmente los cambios de esta fase.

---

## Framework de tests

El proyecto **no usa GUT ni ningún plugin externo**. En su lugar hay un framework
propio minimalista en `escenas/test/test_runner.gd` con la escena
`escenas/test/test_runner.tscn`.

### Cómo correr los tests

**Desde el editor Godot:**
- Abrir `escenas/test/test_runner.tscn` → F6 (Run this scene)
- La salida aparece en la consola inferior de Godot

**Desde la terminal (headless, sin UI):**
```bash
/ruta/a/Godot.app/Contents/MacOS/Godot \
  --headless --path /ruta/al/proyecto \
  escenas/test/test_runner.tscn
```

Ver `README.md` en la raíz del proyecto para el comando exacto con la ruta del
binario de Godot instalado en esta máquina.

### API del framework

```gdscript
ok(condition: bool, description: String)   # assert booleano
eq(a, b, description: String)              # assert igualdad
_suite_header(name: String)                # cabecera de suite (agrupa tests)
```

El runner imprime `✓` / `✗` por test y un resumen final `N/M passed`.
Para agregar una nueva suite: implementar `_run_mi_suite()` y llamarla desde
`_ready()`.

### Estado actual de los tests

| Suite                  | Tests | Estado              |
|------------------------|-------|---------------------|
| Deck                   | ~15   | ✓ pasan             |
| Player                 | ~20   | ✓ pasan             |
| LadderManager          | ~25   | ✓ pasan             |
| GameManager            | ~30   | ✓ pasan             |
| Rules (integración)    | ~15   | ✓ pasan             |
| BotPlayer              | 4     | ✓ pasan (Fase 25)   |
| **Total**              | **108** | **108/108**       |

---

## Estado actual del juego

| Componente             | Estado                                         |
|------------------------|------------------------------------------------|
| Jugadores soportados   | 2 (1 humano + hasta 4 bots, pero UI es 1v1)   |
| Mazos                  | Hardcodeado: `Deck.build(3)`                  |
| `WELL_SIZE`            | Hardcodeado: `const WELL_SIZE := 2`           |
| Colores de jugador     | No existen en el modelo de datos               |
| Delay de bots          | No existe — los bots juegan instantáneamente   |

---

## Fase 25 — Tests de BotPlayer ✅ COMPLETADA

**Objetivo:** Agregar una suite de tests para `BotPlayer` al runner existente.
Verificar las 4 conductas críticas del bot.

**Lo que se descubrió al implementar:** Al escribir el test `bot_does_not_play_after_game_over`,
el proceso colgaba indefinidamente. Se identificó un bug real en `bot_player.gd`:
los tres bloques de prioridad asignaban `moved = true` **incondicionalmente** tras
llamar a `try_play_card`, sin chequear el valor de retorno. Cuando `is_game_over = true`,
`try_play_card` devuelve `false` pero la misma carta se volvía a encontrar en la
siguiente iteración → bucle infinito.

**Fix aplicado en `scripts/ai/bot_player.gd`:**

```gdscript
# Antes (bug):
gm.try_play_card(...)
moved = true
continue

# Después (correcto):
if gm.try_play_card(...):
    moved = true
    continue
```

Esto se aplicó en los tres bloques de prioridad (well, board, hand).

**Tests agregados en `escenas/test/test_runner.gd`:**

```gdscript
func _run_bot_tests() -> void:
    _suite_header("BotPlayer")

    # 1. Prioriza el well sobre la mano
    var gm1 := _make_bot_gm([_ace()], [_card(Card.Suit.SPADES, 5)])
    BotPlayer.play(gm1)
    ok(gm1.players[0].well.is_empty(),
       "bot juega el well antes que la mano cuando ambos son válidos")

    # 2. Termina el turno bajando carta si no puede jugar
    var gm2 := _make_bot_gm([], [_card(Card.Suit.CLUBS, 8)])
    BotPlayer.play(gm2)
    var p2 := gm2.players[0]
    ok(not p2.board.is_empty() and not p2.board[0].is_empty(),
       "bot termina el turno bajando carta al board cuando no puede jugar")

    # 3. Juega joker en slot válido
    var gm3 := _make_bot_gm([], [_joker()])
    gm3.ladder_manager.play_card(_ace(), 0)
    for _i in range(5):
        gm3.deck.cards.append(_card(Card.Suit.CLUBS, 3))
    BotPlayer.play(gm3)
    eq(gm3.ladder_manager.ladders[0].size(), 2,
       "bot juega joker como 2 sobre As en la escalera")

    # 4. No actúa si is_game_over = true
    var gm4 := _make_bot_gm([_ace()], [_card(Card.Suit.CLUBS, 5)])
    gm4.is_game_over = true
    var well_size_before := gm4.players[0].well.size()
    BotPlayer.play(gm4)
    eq(gm4.players[0].well.size(), well_size_before,
       "bot no actúa cuando is_game_over es true")
```

**Verificación:** `108/108 tests passed`.

---

## Fases 26–28 — Tests de reglas, Player y bot ✅ YA CUBIERTAS

Las suites de tests que cubren estos temas **ya existen** en `escenas/test/test_runner.gd`
con ~104 tests antes de la Fase 25. No se usó GUT. Las fases 26–28 del plan original
quedan documentadas aquí como referencia de los patrones de test usados, pero no
requieren implementación adicional.

### Patrones de referencia (equivalentes GUT → framework propio)

| GUT                      | Framework propio              |
|--------------------------|-------------------------------|
| `extends GutTest`        | `extends Node2D` (el runner)  |
| `assert_true(x, msg)`    | `ok(x, msg)`                  |
| `assert_eq(a, b, msg)`   | `eq(a, b, msg)`               |
| archivo separado por clase | función `_run_X_tests()` en el runner |

### Helpers compartidos en el runner

```gdscript
static func _card(suit: Card.Suit, value: int) -> Card:
    var c := Card.new()
    c.suit = suit; c.value = value; c.is_joker = false
    return c

static func _joker() -> Card:
    var c := Card.new(); c.is_joker = true; return c

static func _ace() -> Card:
    return _card(Card.Suit.HEARTS, 1)
```

### Referencia — tests equivalentes a Fase 26 (`test_ladder_manager.gd`)

Estos comportamientos están cubiertos en `_run_ladder_manager_tests()`:

- As inicia escalera
- Secuencia requiere valor consecutivo
- Slot incorrecto rechazado
- Rey completa y descarta la escalera
- Joker como valor válido
- `find_valid_ladder` devuelve el slot correcto

### Referencia — tests equivalentes a Fase 26 (`test_game_manager.gd`)

Cubiertos en `_run_game_manager_tests()` y `_run_rules_tests()`:

- Ases se auto-juegan al inicio del turno
- `game_won` se emite al vaciar el pozo
- `is_game_over` bloquea jugadas posteriores
- La mano se rellena mid-turn al vaciarse
- `try_end_turn` coloca carta en el board
- No se puede terminar turno con mano vacía

### Referencia — `test_ladder_manager.gd` (Fase 26, solo para documentación)

```gdscript
# Equivalente en GUT (no implementado — usar el framework propio)
extends GutTest

func test_ace_starts_ladder() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()
    assert_true(lm.can_play_on(_card(Card.Suit.HEARTS, 1), 0),
                "As debe poder iniciar una escalera")
# ...
```

### Referencia — `test_game_manager.gd` (Fase 26, solo para documentación)

El helper `_make_game` construye un `GameManager` en estado controlado sin usar
`setup()` (que aleatoriamente reparte cartas del deck). En el framework propio
esto se llama `_make_bot_gm()` (ver Fase 25).

```gdscript
# Equivalente en GUT (no implementado — usar el framework propio)
extends GutTest

static func _make_game(well_cards: Array = [],
                       hand_cards: Array = []) -> GameManager:
    var gm := GameManager.new()
    gm.deck = Deck.new()
    gm.ladder_manager = LadderManager.new()
    gm.ladder_manager.add_ladder_slot()
    var p := Player.new("Test", true)
    for c in well_cards: p.well.append(c)
    for c in hand_cards: p.hand.append(c)
    gm.players.clear()
    gm.players.append(p)
    gm.current_player_index = 0
    return gm
```

---

## Fase 27 — Tests: Player y tablero personal ✅ YA CUBIERTA

Cubiertos en `_run_player_tests()`:

- `well_top` devuelve la última carta
- `pop_well_top` elimina la carta
- `has_won` cuando el pozo está vacío
- `push_to_board` crea columna y apila
- Límite de columnas del board enforced
- `cards_needed` rellena hasta `MAX_HAND_SIZE`

### Referencia — `test_player.gd` (Fase 27, solo para documentación)

```gdscript
# Equivalente en GUT (no implementado — usar el framework propio)
extends GutTest

func test_well_top_returns_last_card() -> void:
    var p  := Player.new("T", true)
    var c1 := _card(Card.Suit.HEARTS, 3)
    var c2 := _card(Card.Suit.SPADES, 7)
    p.well.append(c1)
    p.well.append(c2)
    assert_eq(p.well_top(), c2,
              "well_top debe devolver la última carta del pozo")
# ...
```

---

## Fase 28 — Tests: comportamiento del bot ✅ YA CUBIERTA (Fase 25)

Ver sección Fase 25 arriba. Los 4 tests de `_run_bot_tests()` cubren exactamente
los mismos escenarios que el plan original de esta fase.

### Referencia — `test_bot_player.gd` (Fase 28, solo para documentación)

```gdscript
# Equivalente en GUT (no implementado — usar el framework propio)
extends GutTest

static func _make_bot_game(well: Array = [],
                            hand: Array = []) -> GameManager:
    # ... idéntico a _make_bot_gm() del runner ...

func test_bot_plays_well_card_before_hand() -> void: ...
func test_bot_ends_turn_when_no_moves_possible() -> void: ...
func test_bot_plays_joker_on_valid_slot() -> void: ...
func test_bot_does_not_play_after_game_over() -> void: ...
```

---

## Fase 29 — Color de jugador en el modelo de datos

```gdscript
extends GutTest

func test_ace_starts_ladder() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()
    assert_true(lm.can_play_on(_card(Card.Suit.HEARTS, 1), 0),
                "As debe poder iniciar una escalera")

func test_sequence_requires_next_value() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()
    lm.play_card(_card(Card.Suit.HEARTS, 1), 0)
    assert_true(lm.can_play_on(_card(Card.Suit.CLUBS, 2), 0),
                "2 sigue al As")
    assert_false(lm.can_play_on(_card(Card.Suit.SPADES, 3), 0),
                 "3 no sigue directamente al As")

func test_wrong_slot_rejected() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()
    lm.add_ladder_slot()
    lm.play_card(_card(Card.Suit.HEARTS, 1), 0)  # slot 0 espera 2
    lm.play_card(_card(Card.Suit.CLUBS,  1), 1)  # slot 1 espera 2
    assert_false(lm.can_play_on(_card(Card.Suit.SPADES, 3), 0))
    assert_false(lm.can_play_on(_card(Card.Suit.SPADES, 3), 1))

func test_king_completes_and_discards_ladder() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()
    for v in range(1, 14):  # As → K
        lm.play_card(_card(Card.Suit.HEARTS, v), 0)
    # La escalera completada debe descartarse (slot vuelve a aceptar As)
    assert_true(lm.can_play_on(_card(Card.Suit.SPADES, 1), 0),
                "Tras completarse, el slot acepta un As nuevo")

func test_joker_as_valid_value() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()
    lm.play_card(_card(Card.Suit.HEARTS, 1), 0)  # slot espera 2
    assert_true(lm.can_play_on(_joker(), 0, 2),
                "Joker como 2 es válido")
    assert_false(lm.can_play_on(_joker(), 0, 3),
                 "Joker como 3 no encaja donde se espera 2")

func test_find_valid_ladder_returns_slot() -> void:
    var lm := LadderManager.new()
    lm.add_ladder_slot()  # slot 0: espera As
    lm.add_ladder_slot()  # slot 1: espera As
    lm.play_card(_card(Card.Suit.HEARTS, 1), 1)  # slot 1 ahora espera 2
    var two := _card(Card.Suit.CLUBS, 2)
    assert_eq(lm.find_valid_ladder(two), 1,
              "find_valid_ladder debe encontrar el slot 1")

static func _card(suit: Card.Suit, value: int) -> Card:
    var c := Card.new(); c.suit = suit; c.value = value; c.is_joker = false; return c
static func _joker() -> Card:
    var c := Card.new(); c.is_joker = true; return c
```

### 26.3 — `tests/unit/test_game_manager.gd`

El helper `_make_game` construye un `GameManager` en estado controlado sin usar
`setup()` (que aleatoriamente reparte cartas del deck):

```gdscript
extends GutTest

# ── Helper ─────────────────────────────────────────────────────────────────────

static func _make_game(well_cards: Array = [],
                       hand_cards: Array = []) -> GameManager:
    var gm := GameManager.new()
    gm.deck = Deck.new()            # deck vacío por defecto
    gm.ladder_manager = LadderManager.new()
    gm.ladder_manager.add_ladder_slot()
    var p := Player.new("Test", true)
    for c in well_cards:
        p.well.append(c)
    for c in hand_cards:
        p.hand.append(c)
    gm.players.clear()
    gm.players.append(p)
    gm.current_player_index = 0
    return gm

# ── Tests ───────────────────────────────────────────────────────────────────────

func test_aces_are_auto_played_on_begin_turn() -> void:
    var ace  := _card(Card.Suit.HEARTS, 1)
    var five := _card(Card.Suit.CLUBS,  5)
    var gm   := _make_game([], [ace, five])
    gm.begin_turn()
    var p := gm.players[0]
    assert_false(p.hand.has(ace),
                 "El As debe salir de la mano al inicio del turno")
    assert_eq(gm.ladder_manager.ladders[0].size(), 1,
              "El As debe estar en la escalera")

func test_win_condition_emits_signal() -> void:
    var ace := _card(Card.Suit.HEARTS, 1)
    var gm  := _make_game([ace], [])
    var won := false
    gm.game_won.connect(func(_p: Player): won = true)
    gm.try_play_card(GameManager.CardSource.WELL, 0, 0)
    assert_true(won,             "game_won debe emitirse al vaciar el pozo")
    assert_true(gm.is_game_over, "is_game_over debe quedar en true")

func test_game_over_blocks_further_plays() -> void:
    var gm := _make_game([], [_card(Card.Suit.HEARTS, 1)])
    gm.is_game_over = true
    assert_false(gm.try_play_card(GameManager.CardSource.HAND, 0, 0),
                 "Después de game_over no se puede jugar")

func test_hand_refills_mid_turn_when_empty() -> void:
    # Llenar el deck con cartas conocidas para el refill automático
    var gm := _make_game([], [_card(Card.Suit.HEARTS, 1)])
    for i in range(5):
        gm.deck.cards.append(_card(Card.Suit.CLUBS, i + 2))
    var p := gm.players[0]
    # Jugar la única carta de la mano (un As) en la escalera
    gm.try_play_card(GameManager.CardSource.HAND, 0, 0)
    assert_eq(p.hand.size(), 5,
              "La mano debe reponerse a 5 al vaciarse mid-turn")

func test_try_end_turn_places_card_on_board() -> void:
    var five := _card(Card.Suit.CLUBS, 5)
    var gm   := _make_game([], [five])
    # El deck necesita cartas para el begin_turn del siguiente turno
    for i in range(5):
        gm.deck.cards.append(_card(Card.Suit.HEARTS, 2))
    gm.try_end_turn(0, 0)
    var p := gm.players[0]
    assert_false(p.hand.has(five),           "La carta salió de la mano")
    assert_false(p.board.is_empty(),          "El board no debe estar vacío")
    assert_true(p.board[0].has(five),         "La carta está en la columna 0")

func test_cannot_end_turn_with_empty_hand() -> void:
    var gm := _make_game([], [])
    assert_false(gm.try_end_turn(0, 0),
                 "No se puede terminar turno con mano vacía")

# ── helpers ─────────────────────────────────────────────────────────────────────

static func _card(suit: Card.Suit, value: int) -> Card:
    var c := Card.new(); c.suit = suit; c.value = value; c.is_joker = false; return c
```

---

## Fase 27 — Tests: Player y tablero personal

```gdscript
# tests/unit/test_player.gd
extends GutTest

func test_well_top_returns_last_card() -> void:
    var p  := Player.new("T", true)
    var c1 := _card(Card.Suit.HEARTS, 3)
    var c2 := _card(Card.Suit.SPADES, 7)
    p.well.append(c1)
    p.well.append(c2)
    assert_eq(p.well_top(), c2,
              "well_top debe devolver la última carta del pozo")

func test_pop_well_top_removes_card() -> void:
    var p := Player.new("T", true)
    p.well.append(_card(Card.Suit.HEARTS, 3))
    p.pop_well_top()
    assert_true(p.well.is_empty())
    assert_null(p.well_top(), "well_top en pozo vacío debe ser null")

func test_has_won_when_well_empty() -> void:
    var p := Player.new("T", true)
    assert_true(p.has_won(), "Pozo vacío → victoria")
    p.well.append(_card(Card.Suit.HEARTS, 5))
    assert_false(p.has_won(), "Con carta en el pozo no ha ganado")

func test_push_to_board_creates_column() -> void:
    var p := Player.new("T", true)
    var c := _card(Card.Suit.HEARTS, 5)
    assert_true(p.push_to_board(c, 0))
    assert_false(p.board.is_empty())
    assert_eq(p.board[0].back(), c)

func test_push_to_board_stacks_on_existing_column() -> void:
    var p  := Player.new("T", true)
    var c1 := _card(Card.Suit.HEARTS, 5)
    var c2 := _card(Card.Suit.SPADES, 9)
    p.push_to_board(c1, 0)
    p.push_to_board(c2, 0)
    assert_eq(p.board[0].size(), 2, "Dos cartas en la columna 0")
    assert_eq(p.board[0].back(), c2, "La carta superior es c2")

func test_board_column_limit_enforced() -> void:
    var p := Player.new("T", true)
    for i in range(Player.MAX_BOARD_COLUMNS):
        p.push_to_board(_card(Card.Suit.HEARTS, i + 1), i)
    # Intentar crear una columna más allá del límite
    var overflow := _card(Card.Suit.CLUBS, 10)
    var result := p.push_to_board(overflow, Player.MAX_BOARD_COLUMNS)
    assert_false(result, "No se puede crear una columna extra")
    assert_eq(p.board.size(), Player.MAX_BOARD_COLUMNS,
              "El número de columnas no debe superar el máximo")

func test_cards_needed_fills_to_max_hand() -> void:
    var p := Player.new("T", true)
    assert_eq(p.cards_needed(), Player.MAX_HAND_SIZE,
              "Con mano vacía, se necesitan MAX_HAND_SIZE cartas")
    p.hand.append(_card(Card.Suit.HEARTS, 3))
    assert_eq(p.cards_needed(), Player.MAX_HAND_SIZE - 1)

static func _card(suit: Card.Suit, value: int) -> Card:
    var c := Card.new(); c.suit = suit; c.value = value; c.is_joker = false; return c
```

---

## Fase 28 — Tests: comportamiento del bot

```gdscript
# tests/unit/test_bot_player.gd
extends GutTest

# helper: GameManager con un bot como jugador actual
static func _make_bot_game(well: Array = [],
                            hand: Array = []) -> GameManager:
    var gm := GameManager.new()
    gm.deck = Deck.new()
    gm.ladder_manager = LadderManager.new()
    gm.ladder_manager.add_ladder_slot()
    var p := Player.new("Bot1", false)
    for c in well: p.well.append(c)
    for c in hand: p.hand.append(c)
    gm.players.clear()
    gm.players.append(p)
    gm.current_player_index = 0
    return gm

func test_bot_plays_well_card_before_hand() -> void:
    var well_ace := _card(Card.Suit.HEARTS, 1)
    var hand_two := _card(Card.Suit.SPADES, 2)
    var gm := _make_bot_game([well_ace], [hand_two])
    # Dar cartas al deck para el refill tras begin_turn del siguiente turno
    for i in range(5): gm.deck.cards.append(_card(Card.Suit.CLUBS, 3))
    BotPlayer.play(gm)
    assert_true(gm.players[0].well.is_empty(),
                "El bot debe haber jugado la carta del pozo")

func test_bot_ends_turn_when_no_moves_possible() -> void:
    # Un 8 no puede ir en ninguna escalera que espera un As
    var eight := _card(Card.Suit.CLUBS, 8)
    var gm    := _make_bot_game([], [eight])
    for i in range(5): gm.deck.cards.append(_card(Card.Suit.HEARTS, 2))
    BotPlayer.play(gm)
    # El bot debió bajar una carta al board para terminar el turno
    var p := gm.players[0]
    assert_false(p.board.is_empty() or p.board[0].is_empty(),
                 "El bot debe bajar la carta al board si no puede jugarla")

func test_bot_plays_joker_on_valid_slot() -> void:
    var joker := _joker()
    var gm    := _make_bot_game([], [joker])
    # Preparar la escalera: slot 0 tiene un As, espera un 2
    gm.ladder_manager.play_card(_card(Card.Suit.HEARTS, 1), 0)
    for i in range(5): gm.deck.cards.append(_card(Card.Suit.CLUBS, 3))
    BotPlayer.play(gm)
    assert_eq(gm.ladder_manager.ladders[0].size(), 2,
              "El joker debe haberse jugado como 2 en la escalera")

func test_bot_does_not_play_after_game_over() -> void:
    var ace := _card(Card.Suit.HEARTS, 1)
    var gm  := _make_bot_game([ace], [_card(Card.Suit.CLUBS, 5)])
    gm.is_game_over = true
    # BotPlayer.play no debe modificar el estado del juego
    var well_before := gm.players[0].well.size()
    BotPlayer.play(gm)
    assert_eq(gm.players[0].well.size(), well_before,
              "El bot no debe jugar si el juego terminó")

static func _card(suit: Card.Suit, value: int) -> Card:
    var c := Card.new(); c.suit = suit; c.value = value; c.is_joker = false; return c
static func _joker() -> Card:
    var c := Card.new(); c.is_joker = true; return c
```

---

## Fase 29 — Color de jugador en el modelo de datos

**Objetivo:** Cada `Player` tiene un `Color` asignado. El humano lo elige en
GameSetup (Fase 31 del doc UI). Los bots toman colores del pool restante.
La sesión guarda el color elegido como string hex.

### 29.1 — Modificar `scripts/data/player.gd`

Agregar un campo `color` con valor por defecto neutro:

```gdscript
var color: Color = Color.WHITE
```

### 29.2 — Pool de colores y deck scaling en `GameManager`

```gdscript
# scripts/logic/game_manager.gd  — constantes y método setup modificados

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
    deck           = Deck.build(_decks_for(player_count))
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
    return 3 + (player_count - 1) / 2   # división entera
```

### 29.3 — Test de deck scaling

Agregar al final de `test_game_manager.gd`:

```gdscript
func test_deck_scaling() -> void:
    assert_eq(GameManager._decks_for(2), 3, "2 jugadores → 3 mazos")
    assert_eq(GameManager._decks_for(3), 4, "3 jugadores → 4 mazos")
    assert_eq(GameManager._decks_for(4), 4, "4 jugadores → 4 mazos")
    assert_eq(GameManager._decks_for(5), 5, "5 jugadores → 5 mazos")
```

### 29.4 — Sesión con color en `SaveData`

```gdscript
# Modificar start_session y agregar get_session_color en save_data.gd

func start_session(player_name: String, player_color: Color, bot_count: int) -> void:
    ensure_player(player_name)
    settings["last_player_name"] = player_name
    save_data()
    session["player_name"]  = player_name
    session["player_color"] = player_color.to_html()
    session["bot_count"]    = bot_count

func get_session_color() -> Color:
    return Color(session.get("player_color", "#F5C518"))
```

### 29.5 — Adaptar `game.gd`

```gdscript
func _ready() -> void:
    var player_name:  String = SaveData.session.get("player_name",  "Jugador")
    var player_color: Color  = SaveData.get_session_color()
    var bot_count:    int    = SaveData.session.get("bot_count", 1)
    game_manager.setup(player_name, player_color, bot_count)
    # ... resto sin cambios ...
```

---

## Fase 30 — Delay de bots y `WELL_SIZE` como setting

### 30.1 — Agregar settings al diccionario inicial de `SaveData`

```gdscript
var settings: Dictionary = {
    "font_size":        14,
    "animation_speed":  1.0,
    "card_theme":       "classic",
    "well_size":        2,        # cartas en el pozo de cada jugador
    "bot_turn_delay":   0.5,      # segundos de pausa entre movimientos del bot
}
```

**Nota:** `well_size` es ahora la fuente de verdad. El `const WELL_SIZE` en
`player.gd` puede eliminarse — `GameManager.setup()` ya lee el setting directamente.

### 30.2 — Aplicar delay en `game.gd`

`_on_turn_started` ya bifurca humano/bot. El `await` lo convierte en una coroutine;
el guard `is_game_over` evita continuar si la partida terminó durante el delay:

```gdscript
func _on_turn_started(player: Player) -> void:
    if player.is_human:
        hud.set_message("Tu turno")
        hud.enable_actions()
        _state = InteractionState.IDLE
    else:
        hud.set_message(player.name + " está jugando...")
        hud.disable_actions()
        var delay: float = SaveData.get_setting("bot_turn_delay", 0.5)
        if delay > 0.0:
            await get_tree().create_timer(delay).timeout
        if not game_manager.is_game_over:
            BotPlayer.play(game_manager)
```

### 30.3 — Eliminar `const WELL_SIZE` de `player.gd`

El campo ya no es necesario como constante en `Player` porque `GameManager.setup()`
lo lee de `SaveData`. Si algún otro código lo referenciaba, actualizar esas
referencias para que lean el setting directamente o reciban el valor como parámetro.

---

## Orden de implementación

```
25 ✅ → Infraestructura de tests + tests de BotPlayer  (escenas/test/test_runner.gd)
        BUG FIX: bot_player.gd — bucle infinito cuando is_game_over = true
26 ✅ → Tests de escaleras y turno                     (ya existían en el runner)
27 ✅ → Tests de Player                                (ya existían en el runner)
28 ✅ → Tests de bot                                   (cubierto en Fase 25)
────── 108/108 tests pasando ──────────────────────────────────────────────────
29    → Player.color + deck scaling + sesión           (player.gd, game_manager.gd, save_data.gd)
30    → well_size y bot_turn_delay settings            (save_data.gd, game.gd, player.gd)
────── correr tests: verificar que siguen pasando ─────────────────────────────
```

Correr los tests después de cada cambio de producción para detectar regresiones.
Ver `README.md` para el comando exacto.

---

## Archivos a crear/modificar

| Archivo                               | Acción                          | Estado  |
|---------------------------------------|---------------------------------|---------|
| `escenas/test/test_runner.gd`         | Agregar suite BotPlayer         | ✅ hecho |
| `scripts/ai/bot_player.gd`            | Fix bucle infinito              | ✅ hecho |
| `scripts/data/player.gd`             | Agregar `color: Color`, quitar `const WELL_SIZE` | pendiente |
| `scripts/data/save_data.gd`           | `well_size`, `bot_turn_delay`, `get_session_color()`, `start_session()` con color | pendiente |
| `scripts/logic/game_manager.gd`       | `setup()` con color y scaling, `_decks_for()` | pendiente |
| `scripts/ui/game.gd`                  | Pasar color a setup, `await` delay bot | pendiente |

---

## Checklist de verificación por fase

- [x] Fase 25: `test_runner.tscn` corre y reporta `108/108 passed`
- [x] Fase 26: Tests de escaleras y turno pasan (suite existente)
- [x] Fase 27: Tests de Player pasan (suite existente)
- [x] Fase 28: Tests de bot pasan (suite agregada en Fase 25)
- [ ] Fase 29: `test_deck_scaling` pasa; con 3 jugadores se crean 4 mazos (verificar en consola)
- [ ] Fase 30: Con `bot_turn_delay=0.5`, los turnos del bot tienen pausa visible; `well_size=15` alarga la partida significativamente
