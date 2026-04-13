# El Pozo — Guía de implementación técnica

Documento de referencia para implementar el MVP fase por fase.
Cada fase es independiente y verificable antes de pasar a la siguiente.

---

## Fase 1 — Data Layer

**Borrar primero:** `escenas/nivel_1/` y `escenas/prueba_fisicas/`

### scripts/data/card.gd

```gdscript
class_name Card
extends Resource

enum Suit { SPADES, HEARTS, DIAMONDS, CLUBS, JOKER }

var suit: Suit
var value: int   # 1=Ace, 2-10, 11=J, 12=Q, 13=K, 0=Joker
var is_joker: bool

func _init(s: Suit, v: int) -> void:
    suit = s
    value = v
    is_joker = (s == Suit.JOKER)

func display_value() -> String:
    match value:
        0:  return "JK"
        1:  return "A"
        11: return "J"
        12: return "Q"
        13: return "K"
        _:  return str(value)

func suit_symbol() -> String:
    match suit:
        Suit.SPADES:   return "♠"
        Suit.HEARTS:   return "♥"
        Suit.DIAMONDS: return "♦"
        Suit.CLUBS:    return "♣"
        Suit.JOKER:    return "★"
        _:             return "?"

func label() -> String:
    return display_value() + suit_symbol()
```

### scripts/data/deck.gd

```gdscript
class_name Deck
extends RefCounted

var cards: Array[Card] = []

static func build(num_decks: int = 3) -> Deck:
    var d := Deck.new()
    for _deck in range(num_decks):
        for suit in [Card.Suit.SPADES, Card.Suit.HEARTS,
                     Card.Suit.DIAMONDS, Card.Suit.CLUBS]:
            for value in range(1, 14):
                d.cards.append(Card.new(suit, value))
        d.cards.append(Card.new(Card.Suit.JOKER, 0))
        d.cards.append(Card.new(Card.Suit.JOKER, 0))
    d.shuffle()
    return d

func shuffle() -> void:
    cards.shuffle()

func draw() -> Card:
    if cards.is_empty():
        return null
    return cards.pop_back()

func draw_many(n: int) -> Array[Card]:
    var drawn: Array[Card] = []
    for i in range(n):
        var c := draw()
        if c != null:
            drawn.append(c)
    return drawn

func size() -> int:
    return cards.size()

func add_cards(new_cards: Array[Card]) -> void:
    cards.append_array(new_cards)
    shuffle()
```

### scripts/data/player.gd

```gdscript
class_name Player
extends RefCounted

var name: String
var is_human: bool

# well: index 0 = bottom, last = top (visible)
var well: Array[Card] = []
var hand: Array[Card] = []
# board: array of columns; each column is Array[Card] (last = top/accessible)
var board: Array = []

const MAX_HAND_SIZE := 5
const WELL_SIZE := 15
const MAX_BOARD_COLUMNS := 5

func _init(p_name: String, p_is_human: bool) -> void:
    name = p_name
    is_human = p_is_human

func well_top() -> Card:
    return well.back() if not well.is_empty() else null

func pop_well_top() -> Card:
    return well.pop_back() if not well.is_empty() else null

func board_tops() -> Array[Card]:
    var tops: Array[Card] = []
    for col in board:
        if not col.is_empty():
            tops.append(col.back())
    return tops

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
```

**Verificación fase 1:** Crear escena temporal `test.tscn` con un Node2D y script:
```gdscript
func _ready():
    var deck = Deck.build(3)
    print("Deck size: ", deck.size())  # debe ser 162
    var p = Player.new("Test", true)
    for i in range(15):
        p.well.append(deck.draw())
    for i in range(5):
        p.hand.append(deck.draw())
    print("Well: ", p.well.size())   # 15
    print("Hand: ", p.hand.size())   # 5
    print("Top: ", p.well_top().label())
```

---

## Fase 2 — Game Logic

### scripts/logic/ladder_manager.gd

```gdscript
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
```

### scripts/logic/game_manager.gd

```gdscript
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

const INITIAL_LADDERS := 4

func setup() -> void:
    deck = Deck.build(3)
    ladder_manager = LadderManager.new()
    for _i in range(INITIAL_LADDERS):
        ladder_manager.add_ladder_slot()

    players.clear()
    players.append(Player.new("You", true))
    players.append(Player.new("Bot", false))

    for player in players:
        for _i in range(Player.WELL_SIZE):
            player.well.append(deck.draw())
        for _i in range(Player.MAX_HAND_SIZE):
            player.hand.append(deck.draw())

    current_player_index = randi() % players.size()

func current_player() -> Player:
    return players[current_player_index]

func begin_turn() -> void:
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
        game_won.emit(player)

    state_changed.emit()
    return true

func try_end_turn(hand_card_index: int, board_col: int) -> bool:
    var player := current_player()
    if player.hand.is_empty() or hand_card_index >= player.hand.size():
        return false

    var card := player.hand[hand_card_index]
    player.hand.remove_at(hand_card_index)
    player.push_to_board(card, board_col)

    turn_ended.emit(player)
    state_changed.emit()
    _advance_turn()
    return true

func _advance_turn() -> void:
    current_player_index = (current_player_index + 1) % players.size()
    begin_turn()
```

**Verificación fase 2:** Extender el test de fase 1:
```gdscript
func _ready():
    var gm = GameManager.new()
    gm.setup()
    print("Current player: ", gm.current_player().name)
    print("Ladders: ", gm.ladder_manager.ladders.size())
    gm.begin_turn()
    # Intentar jugar la primera carta de la mano en la primera escalera
    var ok = gm.try_play_card(GameManager.CardSource.HAND, 0, 0)
    print("Play result: ", ok)
```

---

## Fase 3 — Árbol de escenas (en el editor de Godot)

Crear escenas en este orden. Cada una se puede previsualizar antes de conectarla.

### escenas/ui/card/card.tscn

Nodos:
```
PanelContainer  (tamaño: 80×110)
└── VBoxContainer  (alignment: center)
    ├── Label "TopLabel"     (font size: 14, align: left)
    └── Label "CenterLabel"  (font size: 36, align: center)
```
Adjuntar script: `scripts/ui/card_view.gd`

### escenas/ui/ladder/ladder.tscn

Nodos:
```
PanelContainer  (tamaño: 80×140)
└── VBoxContainer
    ├── Label "Title"       texto: "Escalera"
    ├── Label "TopCard"     texto: "—"
    └── Label "NextNeeded"  texto: "Necesita: A"
```
Adjuntar script: `scripts/ui/ladder_view.gd`

### escenas/ui/player_area/player_area.tscn

Nodos:
```
VBoxContainer
├── Label "PlayerName"
├── HBoxContainer "WellAndBoard"
│   ├── VBoxContainer "Well"
│   │   ├── Label "WellCount"
│   │   └── Control "WellTopSlot"  (tamaño mínimo: 80×110)
│   └── HBoxContainer "Board"      (separation: 4)
└── HBoxContainer "Hand"           (separation: 4)
```
Adjuntar script: `scripts/ui/player_area_view.gd`

### escenas/ui/hud/hud.tscn

Nodos:
```
VBoxContainer
├── Label "TurnLabel"         (texto: "Tu turno")
├── RichTextLabel "Log"       (scroll_active: true, tamaño: 400×80)
└── Button "EndTurnBtn"       (texto: "Terminar turno")
```
Adjuntar script: `scripts/ui/hud_view.gd`

### escenas/game/game.tscn

Nodos:
```
Node2D "Game"
└── VBoxContainer "Layout"  (anchors: full rect, separation: 8)
    ├── HBoxContainer "OpponentRow"
    │   └── [PlayerArea instanciada aquí por código]
    ├── HBoxContainer "CentralArea"
    │   ├── VBoxContainer "DeckArea"
    │   │   ├── Label "DeckTitle"  (texto: "Mazo")
    │   │   └── Label "DeckCount"
    │   └── HBoxContainer "LaddersContainer"
    └── HBoxContainer "HumanRow"
        └── [PlayerArea instanciada aquí por código]
└── CanvasLayer "HUD"
    └── [HUD instanciada aquí por código]
```
Adjuntar script: `scripts/ui/game.gd`

Actualizar `project.godot` para que `run/main_scene` apunte a `game.tscn`.

---

## Fase 4 — Scripts de UI

### scripts/ui/card_view.gd

```gdscript
class_name CardView
extends PanelContainer

signal card_clicked(card_view: CardView)

@export var card_data: Card = null:
    set(value):
        card_data = value
        _refresh()

@export var face_down: bool = false:
    set(value):
        face_down = value
        _refresh()

@onready var top_label: Label = $VBoxContainer/TopLabel
@onready var center_label: Label = $VBoxContainer/CenterLabel

func _ready() -> void:
    _refresh()
    gui_input.connect(_on_gui_input)

func _refresh() -> void:
    if not is_inside_tree():
        return
    if face_down or card_data == null:
        top_label.text = ""
        center_label.text = "?"
        return
    top_label.text = card_data.label()
    center_label.text = card_data.suit_symbol()
    var is_red := card_data.suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS]
    var color := Color.RED if is_red else Color(0.1, 0.1, 0.1)
    top_label.add_theme_color_override("font_color", color)
    center_label.add_theme_color_override("font_color", color)

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed \
       and event.button_index == MOUSE_BUTTON_LEFT:
        card_clicked.emit(self)
```

### scripts/ui/ladder_view.gd

```gdscript
class_name LadderView
extends PanelContainer

signal ladder_clicked(ladder_index: int)

var ladder_data: Array = []
var ladder_index: int = -1

@onready var top_card_label: Label = $VBoxContainer/TopCard
@onready var next_label: Label = $VBoxContainer/NextNeeded

func _ready() -> void:
    gui_input.connect(_on_gui_input)
    refresh()

func refresh() -> void:
    if not is_inside_tree():
        return
    if ladder_data.is_empty():
        top_card_label.text = "—"
        next_label.text = "Necesita: A"
    else:
        var top: Card = ladder_data.back()
        top_card_label.text = top.label()
        var next_val := top.value + 1
        if next_val > 13:
            next_label.text = "Completa ✓"
        else:
            var next_display := str(next_val)
            match next_val:
                1:  next_display = "A"
                11: next_display = "J"
                12: next_display = "Q"
                13: next_display = "K"
            next_label.text = "Necesita: " + next_display

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed \
       and event.button_index == MOUSE_BUTTON_LEFT:
        ladder_clicked.emit(ladder_index)
```

### scripts/ui/player_area_view.gd

```gdscript
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
```

### scripts/ui/hud_view.gd

```gdscript
class_name HUDView
extends VBoxContainer

signal end_turn_requested()

@onready var turn_label: Label = $TurnLabel
@onready var log_label: RichTextLabel = $Log
@onready var end_turn_btn: Button = $EndTurnBtn

func _ready() -> void:
    end_turn_btn.pressed.connect(func(): end_turn_requested.emit())

func set_status(text: String) -> void:
    turn_label.text = text

func log_action(text: String) -> void:
    log_label.append_text("• " + text + "\n")

func disable_actions() -> void:
    end_turn_btn.disabled = true

func refresh(gm: GameManager) -> void:
    var p := gm.current_player()
    end_turn_btn.visible = p.is_human
    end_turn_btn.disabled = false
```

---

## Fase 5 — game.gd (el orquestador)

### scripts/ui/game.gd

```gdscript
extends Node2D

enum InteractionState { IDLE, CARD_SELECTED, AWAITING_BOARD_COL }

var game_manager: GameManager
var state: InteractionState = InteractionState.IDLE
var selected_source: GameManager.CardSource
var selected_index: int
var selected_card: Card

const PlayerAreaScene := preload("res://escenas/ui/player_area/player_area.tscn")
const LadderScene     := preload("res://escenas/ui/ladder/ladder.tscn")
const HUDScene        := preload("res://escenas/ui/hud/hud.tscn")

@onready var opponent_row: HBoxContainer = $Layout/OpponentRow
@onready var human_row: HBoxContainer    = $Layout/HumanRow
@onready var ladders_container: HBoxContainer = $Layout/CentralArea/LaddersContainer
@onready var deck_count: Label           = $Layout/CentralArea/DeckArea/DeckCount
@onready var hud_layer: CanvasLayer      = $HUD

var human_area: PlayerAreaView
var bot_area: PlayerAreaView
var hud: HUDView

func _ready() -> void:
    game_manager = GameManager.new()
    game_manager.state_changed.connect(_refresh_all)
    game_manager.game_won.connect(_on_game_won)
    game_manager.turn_started.connect(_on_turn_started)

    # Instantiate player areas
    human_area = PlayerAreaScene.instantiate()
    human_area.show_hand = true
    human_area.card_selected.connect(_on_human_card_selected)
    human_row.add_child(human_area)

    bot_area = PlayerAreaScene.instantiate()
    bot_area.show_hand = false
    opponent_row.add_child(bot_area)

    # Instantiate HUD
    hud = HUDScene.instantiate()
    hud.end_turn_requested.connect(_on_end_turn_pressed)
    hud_layer.add_child(hud)

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
        lv.ladder_clicked.connect(_on_ladder_clicked)
        ladders_container.add_child(lv)

func _on_human_card_selected(source: GameManager.CardSource,
                              index: int, card: Card) -> void:
    if not game_manager.current_player().is_human:
        return
    if state == InteractionState.AWAITING_BOARD_COL:
        # In end-turn mode: clicking a hand card then a board column
        if source == GameManager.CardSource.HAND:
            selected_index = index
            hud.set_status("Ahora elegí la columna del tablero (o creá una nueva)")
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
    selected_index = -1
    hud.set_status("Elegí una carta de tu mano para bajar al tablero.")

# Called from player_area when a board column is clicked during end-turn
# Wire this up: board cards in player_area need a separate signal or
# handle it via board column buttons in player_area_view.
# Simplest MVP: add a "End Turn - pick hand card" popup with an index spinner.
func _do_end_turn(hand_index: int, board_col: int) -> void:
    var ok := game_manager.try_end_turn(hand_index, board_col)
    if not ok:
        hud.set_status("No se pudo terminar el turno.")
    state = InteractionState.IDLE

func _ask_joker_value() -> int:
    # MVP simple: use AcceptDialog with LineEdit
    # For now return 1 — implement as ConfirmationDialog with SpinBox
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
```

---

## Fase 6 — Bot greedy

### scripts/ai/bot_player.gd

```gdscript
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
    if player.hand.is_empty():
        return
    # Place highest-value card on board (least useful for ladders)
    var worst_i := 0
    for i in range(1, player.hand.size()):
        if player.hand[i].value > player.hand[worst_i].value:
            worst_i = i

    var col := _pick_board_col(player)
    gm.try_end_turn(worst_i, col)

static func _pick_board_col(player: Player) -> int:
    if player.board.size() < Player.MAX_BOARD_COLUMNS:
        return player.board.size()  # new column
    # Overwrite column with highest top value
    var worst := 0
    for i in range(1, player.board.size()):
        if player.board[i].back().value > player.board[worst].back().value:
            worst = i
    return worst
```

---

## Fase 7 — Web Export

Sin cambios de código. Solo configuración en el editor.

1. `Editor > Manage Export Templates > Download and Install`
2. `Project > Export > Add... > Web`
3. Configuración del preset:
   - Export Path: `exports/web/index.html`
   - Dejar el resto por defecto
4. Click "Export Project" (no "Export PCK")
5. Servir localmente:
   ```bash
   cd /Users/cdecoud/dev/personal/el-pozo/exports/web
   python3 -m http.server 8080
   ```
6. Abrir `http://localhost:8080` en Chrome

**Nota hosting:** Para publicar en internet, usar GitHub Pages o Itch.io. Ambos soportan los headers requeridos por Godot Web: `Cross-Origin-Opener-Policy: same-origin` y `Cross-Origin-Embedder-Policy: require-corp`.

---

## Checklist de verificación por fase

- [ ] Fase 1: `Deck.build(3).size() == 162` en Output panel
- [ ] Fase 1: Player con 15 cartas en well, 5 en mano
- [ ] Fase 2: Ases se juegan automáticamente al inicio del turno
- [ ] Fase 2: `can_play_on` retorna false para carta incorrecta
- [ ] Fase 2: Escalera se descarta al completar K
- [ ] Fase 3: Cartas renderizan con valor y palo en el editor
- [ ] Fase 4: Click en carta del humano la resalta
- [ ] Fase 5: Humano puede completar un turno manual
- [ ] Fase 5: Estado del tablero se actualiza tras cada jugada
- [ ] Fase 6: Bot juega después de 0.8s automáticamente
- [ ] Fase 6: Bot siempre termina su turno (no loop infinito)
- [ ] Fase 7: Juego corre en `localhost:8080` sin errores de consola
