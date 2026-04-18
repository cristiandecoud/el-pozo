# El Pozo — Multijugador: UI y tablero (Fases 31–36)

Continuación de `5-implementacion_multijugador_logica.md`. Este documento cubre el
rediseño visual del tablero para soportar hasta 5 jugadores: selector de color en
GameSetup, layout adaptativo, widget compacto para rivales, overlay de board al
hacer hover/click, acento de color por jugador, delay configurable y validación
progresiva (3 → 4 → 5 jugadores).

**Prerequisitos:** Fases 25–30 completas (`Player.color`, deck scaling, `bot_turn_delay`).

---

## Estado actual

| Componente              | Estado                                                  |
|-------------------------|---------------------------------------------------------|
| Layout                  | 2 jugadores fijos (humano abajo, rival arriba)          |
| Board rival             | `PlayerAreaView` completo — no escala a más de 1 rival  |
| Colores de jugador      | En el modelo (Fase 29) pero sin uso en UI               |
| Selector de color       | No existe en GameSetup                                  |
| Delay de bots           | Configurado en lógica (Fase 30) pero sin slider visible |

---

## Arquitectura del nuevo layout

El tablero para N jugadores se divide en tres zonas verticales:

```
┌──────────────────────────────────────────────────────┐
│  RIVALS ROW  (HBoxContainer, compacto, ~140px alto)  │
├──────────────────────────────────────────────────────┤
│                                                      │
│        LADDERS AREA  (escaleras compartidas)         │
│                       EXPAND_FILL                    │
│                                                      │
├──────────────────────────────────────────────────────┤
│   HUMAN AREA  (PlayerAreaView completo, ~260px alto) │
└──────────────────────────────────────────────────────┘
```

- **2 jugadores:** 1 rival en la fila superior (layout actual, sin cambios visuales
  significativos)
- **3 jugadores:** 2 `RivalAreaView` compactos en la fila superior
- **4 jugadores:** 3 rivales
- **5 jugadores:** 4 rivales (si el ancho es muy ajustado, pasar a grid 2×2)

Los `RivalAreaView` muestran: nombre, carta visible del pozo, tops de columnas del
board, y cantidad de cartas en mano. Al hacer hover o click aparece un overlay
flotante con el board completo.

---

## Fase 31 — Selector de color en GameSetup

**Objetivo:** El jugador elige su color antes de iniciar. Se guarda en la sesión
(Fase 29) y llega a `GameManager.setup()`.

### 31.1 — Modificar `escenas/ui/game_setup/game_setup.tscn`

Agregar una fila de color entre el nombre y los bots:

```
VBoxContainer "Panel"
├── Label "NameLabel"           "Tu nombre"
├── LineEdit "NameInput"
├── Label "ColorLabel"          "Tu color"
├── HBoxContainer "ColorRow"
│   ├── Button "ColorBtn0"      fondo #F5C518, 44×44
│   ├── Button "ColorBtn1"      fondo #3B82F6
│   ├── Button "ColorBtn2"      fondo #22C55E
│   ├── Button "ColorBtn3"      fondo #EF4444
│   └── Button "ColorBtn4"      fondo #A855F7
├── Label "BotsLabel"           "Bots rivales"
└── HBoxContainer "BotsRow"     (sin cambios)
```

Cada `ColorBtn`: `flat = true`, `custom_minimum_size = Vector2(44, 44)`,
sin texto. El estilo visual (borde seleccionado) se aplica desde código.

### 31.2 — Modificar `scripts/ui/game_setup.gd`

```gdscript
extends Control

const MIN_BOTS := 1
const MAX_BOTS := 4

const PLAYER_COLORS: Array[Color] = [
    Color("#F5C518"),  # Dorado
    Color("#3B82F6"),  # Azul
    Color("#22C55E"),  # Verde
    Color("#EF4444"),  # Rojo
    Color("#A855F7"),  # Violeta
]

var _bot_count:       int   = 1
var _selected_color:  Color = PLAYER_COLORS[0]

@onready var name_input:  LineEdit      = $Panel/NameInput
@onready var color_row:   HBoxContainer = $Panel/ColorRow
@onready var bots_count:  Label         = $Panel/BotsRow/BotsCount
@onready var bot_minus:   Button        = $Panel/BotsRow/BotMinus
@onready var bot_plus:    Button        = $Panel/BotsRow/BotPlus
@onready var start_btn:   Button        = $Panel/Buttons/StartBtn
@onready var back_btn:    Button        = $Panel/Buttons/BackBtn

func _ready() -> void:
    name_input.text = SaveData.get_setting("last_player_name", "") as String
    _update_bots_ui()
    _setup_color_buttons()

    bot_minus.pressed.connect(func():
        _bot_count = max(MIN_BOTS, _bot_count - 1)
        _update_bots_ui())
    bot_plus.pressed.connect(func():
        _bot_count = min(MAX_BOTS, _bot_count + 1)
        _update_bots_ui())
    start_btn.pressed.connect(_on_start)
    back_btn.pressed.connect(func():
        get_tree().change_scene_to_file(
            "res://escenas/ui/main_menu/main_menu.tscn"))

func _setup_color_buttons() -> void:
    for i in range(color_row.get_child_count()):
        var btn: Button = color_row.get_child(i)
        var col: Color  = PLAYER_COLORS[i]
        btn.pressed.connect(func(): _select_color(col))
    _select_color(PLAYER_COLORS[0])

func _select_color(col: Color) -> void:
    _selected_color = col
    for i in range(color_row.get_child_count()):
        var btn:   Button       = color_row.get_child(i)
        var style: StyleBoxFlat = StyleBoxFlat.new()
        style.bg_color          = PLAYER_COLORS[i]
        if PLAYER_COLORS[i].is_equal_approx(col):
            style.border_color = Color.WHITE
            style.set_border_width_all(3)
        btn.add_theme_stylebox_override("normal",  style)
        btn.add_theme_stylebox_override("hover",   style)
        btn.add_theme_stylebox_override("pressed", style)

func _update_bots_ui() -> void:
    bots_count.text    = str(_bot_count)
    bot_minus.disabled = _bot_count <= MIN_BOTS
    bot_plus.disabled  = _bot_count >= MAX_BOTS

func _on_start() -> void:
    var player_name := name_input.text.strip_edges()
    if player_name.is_empty():
        player_name = "Jugador"
    SaveData.start_session(player_name, _selected_color, _bot_count)
    get_tree().change_scene_to_file("res://escenas/game/game.tscn")
```

### Verificación

GameSetup muestra 5 círculos/botones de color. Click en uno → borde blanco lo
resalta. Iniciar partida → el nombre del jugador humano aparece con su color en el
HUD (una vez que la Fase 35 esté lista).

---

## Fase 32 — Widget compacto de rival (`RivalAreaView`)

**Objetivo:** Widget reutilizable que muestra el estado de un rival en poco espacio.
Se instancia N−1 veces. Es un componente puramente de lectura — no tiene interacción
con las escaleras.

### 32.1 — Escena: `escenas/game/rival_area/rival_area.tscn`

```
PanelContainer "RivalArea"       custom_minimum_size: Vector2(160, 120)
└── VBoxContainer "VBox"         (margins: 8, separation: 4)
    ├── HBoxContainer "Header"
    │   ├── ColorRect "ColorBar"     size: Vector2(4, 16), color = player.color
    │   └── Label "NameLabel"        font_size=13, size_flags_h=EXPAND
    ├── HBoxContainer "WellRow"
    │   ├── Label "WellIcon"         "⬟", font_size=11, color=#888888
    │   └── Label "WellCard"         carta visible del pozo, font_size=13
    ├── Label "HandCount"            "Mano: 4", font_size=11, color=#888888
    └── HBoxContainer "BoardTops"   (tops de columnas, construido en código)
```

### 32.2 — `scripts/ui/rival_area_view.gd`

```gdscript
class_name RivalAreaView
extends PanelContainer

signal inspect_requested(player: Player)

var _player: Player

@onready var color_bar:  ColorRect     = $VBox/Header/ColorBar
@onready var name_label: Label         = $VBox/Header/NameLabel
@onready var well_card:  Label         = $VBox/WellRow/WellCard
@onready var hand_count: Label         = $VBox/HandCount
@onready var board_tops: HBoxContainer = $VBox/BoardTops

func setup(player: Player) -> void:
    _player = player
    mouse_entered.connect(func(): inspect_requested.emit(_player))
    gui_input.connect(_on_gui_input)
    refresh()

func refresh() -> void:
    color_bar.color   = _player.color
    name_label.text   = _player.name
    name_label.add_theme_color_override("font_color", _player.color)
    var top           := _player.well_top()
    if top == null:
        well_card.text = "GANÓ"
    else:
        well_card.text = top.display_value() + " " + _suit_icon(top.suit)
    hand_count.text   = "Mano: " + str(_player.hand.size())
    _rebuild_board_tops()

func set_active(active: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#1a1a1a")
    if active:
        style.border_color = _player.color
        style.set_border_width_all(2)
    add_theme_stylebox_override("panel", style)

func _rebuild_board_tops() -> void:
    for child in board_tops.get_children():
        child.queue_free()
    for col in _player.board:
        if col.is_empty():
            continue
        var lbl := Label.new()
        lbl.text = col.back().display_value()
        lbl.add_theme_font_size_override("font_size", 11)
        lbl.custom_minimum_size = Vector2(24, 0)
        board_tops.add_child(lbl)

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        inspect_requested.emit(_player)

static func _suit_icon(suit: Card.Suit) -> String:
    match suit:
        Card.Suit.HEARTS:   return "♥"
        Card.Suit.DIAMONDS: return "♦"
        Card.Suit.CLUBS:    return "♣"
        Card.Suit.SPADES:   return "♠"
    return ""
```

### Verificación

Instanciar manualmente en una escena de prueba con un `Player` de datos hardcodeados.
El widget muestra nombre, pozo y tops de columnas correctamente.

---

## Fase 33 — Overlay de board rival

**Objetivo:** Hover o click en un `RivalAreaView` → overlay flotante con el board
completo del rival. Se cierra al hacer click en el fondo o presionar Escape.

### 33.1 — Escena: `escenas/game/rival_board_overlay/rival_board_overlay.tscn`

```
CanvasLayer "RivalBoardOverlay"   layer: 10
└── ColorRect "Shield"            color: #00000055, full rect
└── PanelContainer "Panel"        anchor: center, offset: ±380/±260
    └── VBoxContainer "VBox"      (margins: 16, separation: 8)
        ├── HBoxContainer "Header"
        │   ├── ColorRect "ColorBar"   size: Vector2(4, 20)
        │   ├── Label "PlayerName"     font_size=18, size_flags_h=EXPAND
        │   └── Label "HintLabel"      "Haz click para cerrar", font_size=11, color=#888888
        ├── HSeparator
        └── ScrollContainer "Scroll"   size_flags_v=EXPAND_FILL, custom_minimum_size=Vector2(0,160)
            └── HBoxContainer "BoardDisplay"   (columnas, construidas en código)
```

### 33.2 — `scripts/ui/rival_board_overlay.gd`

```gdscript
class_name RivalBoardOverlay
extends CanvasLayer

@onready var shield:        ColorRect     = $Shield
@onready var color_bar:     ColorRect     = $Panel/VBox/Header/ColorBar
@onready var player_name:   Label         = $Panel/VBox/Header/PlayerName
@onready var board_display: HBoxContainer = $Panel/VBox/Scroll/BoardDisplay

func setup(player: Player) -> void:
    color_bar.color  = player.color
    player_name.text = player.name
    player_name.add_theme_color_override("font_color", player.color)
    _build_board(player)
    shield.gui_input.connect(func(e: InputEvent):
        if e is InputEventMouseButton and e.pressed:
            queue_free())

func _build_board(player: Player) -> void:
    for child in board_display.get_children():
        child.queue_free()
    if player.board.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "(tablero vacío)"
        empty_lbl.add_theme_color_override("font_color", Color("#888888"))
        board_display.add_child(empty_lbl)
        return
    for col in player.board:
        if col.is_empty():
            continue
        var col_box := VBoxContainer.new()
        col_box.custom_minimum_size = Vector2(52, 0)
        for card in col:
            var lbl := Label.new()
            lbl.text = card.display_value() + _suit_icon(card.suit)
            lbl.add_theme_font_size_override("font_size", 14)
            col_box.add_child(lbl)
        board_display.add_child(col_box)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        queue_free()

static func _suit_icon(suit: Card.Suit) -> String:
    match suit:
        Card.Suit.HEARTS:   return "♥"
        Card.Suit.DIAMONDS: return "♦"
        Card.Suit.CLUBS:    return "♣"
        Card.Suit.SPADES:   return "♠"
    return ""
```

### 33.3 — Integrar en `game.gd`

```gdscript
const RivalBoardOverlayScene := preload(
    "res://escenas/game/rival_board_overlay/rival_board_overlay.tscn")

var _rival_overlay: RivalBoardOverlay = null

func _show_rival_board(player: Player) -> void:
    if _rival_overlay != null:
        _rival_overlay.queue_free()
    _rival_overlay = RivalBoardOverlayScene.instantiate()
    add_child(_rival_overlay)
    _rival_overlay.setup(player)
    _rival_overlay.tree_exited.connect(func(): _rival_overlay = null)
```

Conectar `inspect_requested` de cada `RivalAreaView` a `_show_rival_board` al
construir la fila de rivales (Fase 34).

### Verificación

Hover sobre un rival → overlay aparece con nombre, color y columnas del board.
Click en el fondo oscuro o Escape → se cierra sin afectar el estado del juego.

---

## Fase 34 — Layout adaptativo (validación con 3 jugadores)

**Objetivo:** Refactorizar `game.tscn` para la nueva estructura de tres zonas y
llenar la fila de rivales dinámicamente. Validar primero con 3 jugadores (1 humano
+ 2 bots) antes de escalar.

### 34.1 — Nueva estructura de `escenas/game/game.tscn`

```
Control "Game"  (full rect)
└── VBoxContainer "MainLayout"   full rect, separation=0
    ├── HBoxContainer "RivalsRow"
    │   separation=8, custom_minimum_size=Vector2(0,140)
    │   size_flags_vertical=SHRINK_BEGIN
    │   (se llena desde código)
    ├── HSeparator
    ├── HBoxContainer "LaddersArea"
    │   size_flags_vertical=EXPAND_FILL
    │   separation=8, alignment=CENTER
    │   (se llena desde código — LadderView × N_ladders)
    ├── HSeparator
    └── PlayerAreaView "HumanArea"
        size_flags_vertical=SHRINK_END
        (el jugador humano — sin cambios respecto al código actual)
```

**Cambios respecto al layout anterior:**
- El `PlayerAreaView` del rival que estaba hardcodeado arriba desaparece
- `RivalsRow` se llena desde `_build_rival_views()` tras `game_manager.setup()`
- `LaddersArea` ya existía; solo se mueve dentro del nuevo `VBoxContainer`

### 34.2 — Modificar `scripts/ui/game.gd`

```gdscript
const RivalAreaScene := preload(
    "res://escenas/game/rival_area/rival_area.tscn")

@onready var rivals_row:  HBoxContainer = $MainLayout/RivalsRow
@onready var human_area:  PlayerAreaView = $MainLayout/HumanArea
@onready var ladders_area: HBoxContainer = $MainLayout/LaddersArea

var _rival_views: Dictionary = {}  # Player → RivalAreaView

func _ready() -> void:
    # setup existente:
    var player_name:  String = SaveData.session.get("player_name",  "Jugador")
    var player_color: Color  = SaveData.get_session_color()
    var bot_count:    int    = SaveData.session.get("bot_count", 1)
    game_manager.setup(player_name, player_color, bot_count)

    _build_rival_views()
    _build_ladder_views()
    human_area.setup(game_manager.players[0])  # siempre el índice 0

    # señales existentes:
    game_manager.turn_started.connect(_on_turn_started)
    game_manager.turn_ended.connect(func(p): _turn_count += 1)
    game_manager.game_won.connect(_on_game_won)
    game_manager.state_changed.connect(_on_state_changed)

    game_manager.begin_turn()

func _build_rival_views() -> void:
    for child in rivals_row.get_children():
        child.queue_free()
    _rival_views.clear()
    for player in game_manager.players:
        if player.is_human:
            continue
        var view: RivalAreaView = RivalAreaScene.instantiate()
        rivals_row.add_child(view)
        view.setup(player)
        view.inspect_requested.connect(_show_rival_board)
        _rival_views[player] = view

func _on_state_changed() -> void:
    human_area.refresh(game_manager.players[0])
    for player in _rival_views:
        (_rival_views[player] as RivalAreaView).refresh()
    # actualizar overlay si está abierto
    if _rival_overlay != null:
        _rival_overlay.queue_free()

func _on_turn_started(player: Player) -> void:
    # quitar highlight activo de todos
    human_area.set_active(false)
    for p in _rival_views:
        (_rival_views[p] as RivalAreaView).set_active(false)

    if player.is_human:
        human_area.set_active(true)
        hud.set_message("Tu turno")
        hud.enable_actions()
        _state = InteractionState.IDLE
    else:
        if _rival_views.has(player):
            (_rival_views[player] as RivalAreaView).set_active(true)
        hud.set_message(player.name + " está jugando...")
        hud.disable_actions()
        var delay: float = SaveData.get_setting("bot_turn_delay", 0.5)
        if delay > 0.0:
            await get_tree().create_timer(delay).timeout
        if not game_manager.is_game_over:
            BotPlayer.play(game_manager)
```

**Nota sobre `_build_ladder_views()`:** Esta función ya existe o es equivalente al
código que instancia los `LadderView` en la versión actual. Solo verificar que los
views se agregan a `ladders_area` en lugar de cualquier nodo anterior.

### 34.3 — Agregar `set_active()` a `PlayerAreaView`

Para el highlight del área del jugador humano cuando es su turno:

```gdscript
# En player_area_view.gd
func set_active(active: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#1a1a2e")
    if active and _player != null:
        style.border_color = _player.color
        style.set_border_width_all(2)
    add_theme_stylebox_override("panel", style)
```

### Verificación con 3 jugadores

1. GameSetup → 2 bots → Comenzar
2. Fila superior muestra 2 `RivalAreaView` compactos con nombre y color
3. Ladders en el centro, área del humano abajo
4. Los turnos rotan entre los 3 jugadores correctamente
5. Hover en un rival → overlay con su board
6. Un bot ganando → pantalla de GameOver correcta

---

## Fase 35 — Color de jugador aplicado en la UI

**Objetivo:** Usar `player.color` como acento visual en todas las áreas: borde del
well card, nombre, y highlight del turno activo. Las bases de `set_active()` se
pusieron en la Fase 34; aquí se completan los detalles.

### 35.1 — Color en `PlayerAreaView`

En el método `refresh(player)` o `setup(player)`, aplicar el color al nombre:

```gdscript
func refresh(player: Player) -> void:
    _player = player
    name_label.text = player.name
    name_label.add_theme_color_override("font_color", player.color)
    # ... resto del refresh existente ...
```

### 35.2 — Color en el well card

El `CardView` del well top puede recibir un color de acento del jugador para su borde:

```gdscript
# En card_view.gd — método nuevo:
func set_accent_color(col: Color) -> void:
    _style_normal.border_color = col
    _style_normal.set_border_width_all(2)
    add_theme_stylebox_override("panel", _style_normal)
```

Llamarlo desde `PlayerAreaView.refresh()` al actualizar el well card view.

### 35.3 — Color en el HUD

Mostrar el nombre del jugador activo con su color en el mensaje del HUD:

```gdscript
# En hud_view.gd:
func set_message_colored(text: String, col: Color) -> void:
    message_label.text = text
    message_label.add_theme_color_override("font_color", col)
```

Llamarlo desde `_on_turn_started` en `game.gd`:

```gdscript
hud.set_message_colored("Tu turno", game_manager.players[0].color)
# o para bot:
hud.set_message_colored(player.name + " está jugando...", player.color)
```

### Verificación

- Cada área de jugador muestra su nombre en su color
- El jugador activo tiene un borde de su color alrededor de su área
- El mensaje del HUD usa el color del jugador activo

---

## Fase 36 — Slider de delay en Settings + validación 4 y 5 jugadores

### 36.1 — Agregar slider a `escenas/ui/settings/settings_screen.tscn`

Agregar después de la fila de velocidad de animación:

```
├── Label "GameplayTitle"        "PARTIDA", font_size=11, color=#888888
├── HBoxContainer "WellSizeRow"
│   ├── Label                    "Tamaño del pozo (cartas)"
│   ├── HSlider "WellSlider"     min=2, max=20, step=1, value=2
│   └── Label "WellValue"        "2"
├── HBoxContainer "BotDelayRow"
│   ├── Label                    "Pausa entre movimientos del bot"
│   ├── HSlider "BotDelaySlider" min=0.0, max=2.0, step=0.1, value=0.5
│   └── Label "BotDelayValue"    "0.5s"
```

### 36.2 — Modificar `scripts/ui/settings_screen.gd`

```gdscript
@onready var well_slider:      HSlider = $Panel/WellSizeRow/WellSlider
@onready var well_value:       Label   = $Panel/WellSizeRow/WellValue
@onready var bot_delay_slider: HSlider = $Panel/BotDelayRow/BotDelaySlider
@onready var bot_delay_value:  Label   = $Panel/BotDelayRow/BotDelayValue

func _ready() -> void:
    # ... código existente ...
    well_slider.value = SaveData.get_setting("well_size", 2)
    well_slider.value_changed.connect(func(v):
        well_value.text = str(int(v)))
    well_value.text = str(int(well_slider.value))

    bot_delay_slider.value = SaveData.get_setting("bot_turn_delay", 0.5)
    bot_delay_slider.value_changed.connect(func(v):
        bot_delay_value.text = "%.1fs" % v)
    bot_delay_value.text = "%.1fs" % bot_delay_slider.value

func _on_save() -> void:
    # ... código existente ...
    SaveData.set_setting("well_size",       int(well_slider.value))
    SaveData.set_setting("bot_turn_delay",  bot_delay_slider.value)
    _go_back()
```

### 36.3 — Validación con 4 jugadores

Con el layout de la Fase 34, agregar un 3er bot ya funciona: se crea un tercer
`RivalAreaView` en `RivalsRow`. Verificar:

1. GameSetup → 3 bots → Comenzar
2. Fila superior muestra 3 `RivalAreaView` (anchos ~1280/3 ≈ 420px cada uno)
3. Turnos rotan entre los 4 jugadores
4. Deck de 4 mazos (216 cartas) → la partida dura significativamente más
5. Cualquier jugador ganando (humano o bot) dispara GameOver correctamente

### 36.4 — Validación con 5 jugadores

Con 4 rivales en la fila, cada `RivalAreaView` tiene ~280px (en 1280px). Si el
resultado es demasiado apretado, reducir el `custom_minimum_size` a
`Vector2(120, 110)` y el `font_size` de `NameLabel` a 11.

**Ajuste opcional para viewports angostos:** Si hay 4 o más rivales, convertir
`RivalsRow` en un `GridContainer` de 2 columnas:

```gdscript
func _build_rival_views() -> void:
    for child in rivals_row.get_children():
        child.queue_free()
    _rival_views.clear()

    var rival_count := game_manager.players.size() - 1
    var container: Container
    if rival_count > 3:
        var grid   := GridContainer.new()
        grid.columns = 2
        rivals_row.add_child(grid)
        container = grid
    else:
        container = rivals_row

    for player in game_manager.players:
        if player.is_human:
            continue
        var view: RivalAreaView = RivalAreaScene.instantiate()
        container.add_child(view)
        view.setup(player)
        view.inspect_requested.connect(_show_rival_board)
        _rival_views[player] = view
```

Verificar:
1. GameSetup → 4 bots → Comenzar
2. Grid 2×2 de rivales visible
3. Deck de 5 mazos (270 cartas)
4. Todos los turnos y la victoria funcionan correctamente

---

## Orden de implementación recomendado

```
31 → Color selector en GameSetup           (no rompe gameplay existente)
32 → RivalAreaView                         (widget aislado, testeable solo)
33 → RivalBoardOverlay                     (depende de 32)
34 → Layout adaptativo — validar 3 jugs.   (depende de 32, 33; refactor importante)
35 → Color en UI                           (depende de 29 doc anterior + 32, 34)
36 → Sliders en Settings + validar 4 y 5  (depende de todo lo anterior)
```

La Fase 34 es el cambio más riesgoso porque refactoriza `game.tscn` y `game.gd`.
Correr los tests de GUT (Fases 25–28) después de este cambio para detectar
regresiones en la lógica.

---

## Archivos a crear/modificar

| Archivo                                                     | Acción                                       |
|-------------------------------------------------------------|----------------------------------------------|
| `escenas/ui/game_setup/game_setup.tscn`                     | Modificar: agregar `ColorRow`                |
| `scripts/ui/game_setup.gd`                                  | Modificar: color picker                      |
| `escenas/game/rival_area/rival_area.tscn`                   | Crear                                        |
| `scripts/ui/rival_area_view.gd`                             | Crear                                        |
| `escenas/game/rival_board_overlay/rival_board_overlay.tscn` | Crear                                        |
| `scripts/ui/rival_board_overlay.gd`                         | Crear                                        |
| `escenas/game/game.tscn`                                    | Modificar: nueva estructura `MainLayout`     |
| `scripts/ui/game.gd`                                        | Modificar: `_build_rival_views`, overlay, highlight |
| `scripts/ui/player_area_view.gd`                            | Modificar: `set_active()`, color en nombre   |
| `scripts/ui/card_view.gd`                                   | Modificar: `set_accent_color()`              |
| `scripts/ui/hud_view.gd`                                    | Modificar: `set_message_colored()`           |
| `escenas/ui/settings/settings_screen.tscn`                  | Modificar: filas `WellSizeRow`, `BotDelayRow`|
| `scripts/ui/settings_screen.gd`                             | Modificar: sliders well_size y bot_delay     |

---

## Checklist de verificación por fase

- [ ] Fase 31: 5 botones de color en GameSetup; color elegido llega a `Player.color` en el juego
- [ ] Fase 32: `RivalAreaView` muestra nombre, pozo y tops del board de un bot
- [ ] Fase 33: Hover/click en un rival → overlay; click fuera o Escape → cierra
- [ ] Fase 34: Con 3 jugadores — 2 `RivalAreaView` visibles; turnos rotan; GameOver funciona
- [ ] Fase 35: Cada área muestra el nombre en su color; jugador activo tiene borde de su color
- [ ] Fase 36: Sliders de well_size y bot_delay funcionan; 4 y 5 jugadores corren correctamente
