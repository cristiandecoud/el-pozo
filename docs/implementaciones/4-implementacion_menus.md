# El Pozo — Implementación de menús y UI global (Fases 18–24)

Continuación de `implementacion_ux.md`. Las fases 1–17 cubren lógica, UI de juego y
experiencia interactiva. Este documento cubre la capa de navegación: menú principal,
configuración, estadísticas por jugador, pantalla de fin de partida y menú de pausa.

**Plataforma objetivo:** Web primero. El código usa anchors y size_flags de Godot
para ser responsivo; nada está hardcodeado en píxeles de viewport.

---

## Estado actual

| Componente              | Estado actual                                      |
|-------------------------|----------------------------------------------------|
| Menú principal          | No existe — el juego arranca directo en la mesa    |
| Configuración           | No existe                                          |
| Estadísticas            | No existen                                         |
| Pantalla de fin         | Solo un mensaje en el HUD                          |
| Pausa                   | No existe                                          |
| Persistencia            | No existe                                          |

---

## Arquitectura general

### Flujo de navegación

```
MainMenu
├── "Nueva partida"  → GameSetup → game.tscn → GameOver → (MainMenu | GameSetup)
├── "Estadísticas"   → StatsScreen → MainMenu
└── "Configuración"  → SettingsScreen → MainMenu

Dentro del juego:
└── Pausa (overlay CanvasLayer) → Resume | Configuración | Menú principal
```

### Transición de escenas

Cambios de escena completos con:
```gdscript
get_tree().change_scene_to_file("res://escenas/ui/main_menu/main_menu.tscn")
```

Overlays (pausa) con `CanvasLayer` + `get_tree().paused = true` / `false`.

### AutoLoad: `SaveData`

Un único singleton cargado al inicio gestiona tanto la configuración como las
estadísticas. Se registra en `project.godot` como AutoLoad con nombre `SaveData`.

```
res://scripts/data/save_data.gd  →  AutoLoad: "SaveData"
```

Archivo en disco: `user://save_data.json` (un solo JSON, fácil de migrar).

---

## Fase 18 — Capa de persistencia (`SaveData`)

**Objetivo:** Antes de construir cualquier pantalla, tener un singleton que lea y
escriba datos en disco. Todo lo demás lo usa.

### 18.1 — Estructura de `save_data.json`

```json
{
  "settings": {
    "font_size": 14,
    "animation_speed": 1.0,
    "card_theme": "classic"
  },
  "players": {
    "Cristian": {
      "games_played": 0,
      "wins": 0,
      "losses": 0,
      "cards_played": 0,
      "fastest_win_turns": 0
    }
  }
}
```

`fastest_win_turns = 0` significa "sin registro". Se guarda el menor número de
turnos en que el jugador ganó una partida.

### 18.2 — `scripts/data/save_data.gd`

```gdscript
extends Node

const SAVE_PATH := "user://save_data.json"

var settings: Dictionary = {
    "font_size": 14,
    "animation_speed": 1.0,
    "card_theme": "classic"
}
var players: Dictionary = {}  # name → stats dict

func _ready() -> void:
    load_data()

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        save_data()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var parsed := JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        if parsed.has("settings"):
            settings.merge(parsed["settings"], true)
        if parsed.has("players"):
            players = parsed["players"]

func save_data() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify({
        "settings": settings,
        "players": players
    }, "\t"))
    file.close()

# ── Settings ──────────────────────────────────────────────────────────────────

func get_setting(key: String, default_val: Variant = null) -> Variant:
    return settings.get(key, default_val)

func set_setting(key: String, value: Variant) -> void:
    settings[key] = value
    save_data()

# ── Estadísticas de jugador ───────────────────────────────────────────────────

func ensure_player(name: String) -> void:
    if not players.has(name):
        players[name] = {
            "games_played": 0,
            "wins": 0,
            "losses": 0,
            "cards_played": 0,
            "fastest_win_turns": 0
        }
        save_data()

func record_win(name: String, turns: int) -> void:
    ensure_player(name)
    players[name]["games_played"] += 1
    players[name]["wins"] += 1
    var fastest: int = players[name]["fastest_win_turns"]
    if fastest == 0 or turns < fastest:
        players[name]["fastest_win_turns"] = turns
    save_data()

func record_loss(name: String) -> void:
    ensure_player(name)
    players[name]["games_played"] += 1
    players[name]["losses"] += 1
    save_data()

func record_cards_played(name: String, count: int) -> void:
    ensure_player(name)
    players[name]["cards_played"] += count
    save_data()

func get_player_stats(name: String) -> Dictionary:
    ensure_player(name)
    return players[name]

func all_player_names() -> Array:
    return players.keys()
```

### 18.3 — Registrar como AutoLoad

En `project.godot`:
```
[autoload]
SaveData="*res://scripts/data/save_data.gd"
```

O en el editor: Project → Project Settings → AutoLoad → agregar `save_data.gd`
con nombre `SaveData`.

### Verificación

En cualquier script GDScript, `SaveData.get_setting("font_size")` devuelve `14`.
Modificar y relanzar el proyecto: el valor persiste.

---

## Fase 19 — Menú principal

**Objetivo:** Primera pantalla que ve el jugador. Acceso a nueva partida,
estadísticas y configuración. Estética consistente con la mesa de cartas.

### 19.1 — Escena: `escenas/ui/main_menu/main_menu.tscn`

```
Control "MainMenu"  (anchors: full rect)
└── ColorRect "Background"          color: #2D6A4F, full rect
└── VBoxContainer "Content"         centrado horizontal y vertical
    ├── Label "Title"               "EL POZO", font_size=52, color=#F5C518
    ├── Label "Subtitle"            "Juego de cartas", font_size=16, color=#888888
    ├── VSeparator                  (separación visual)
    ├── Button "PlayBtn"            "Nueva partida"
    ├── Button "StatsBtn"           "Estadísticas"
    ├── Button "SettingsBtn"        "Configuración"
    └── Label "VersionLabel"        "v0.1", font_size=11, color=#555555
```

`Content` usa `size_flags_horizontal = SHRINK_CENTER` y
`size_flags_vertical = SHRINK_CENTER` para quedar centrado en cualquier resolución.

### 19.2 — `scripts/ui/main_menu.gd`

```gdscript
extends Control

@onready var play_btn: Button     = $Content/PlayBtn
@onready var stats_btn: Button    = $Content/StatsBtn
@onready var settings_btn: Button = $Content/SettingsBtn

func _ready() -> void:
    play_btn.pressed.connect(func():
        get_tree().change_scene_to_file(
            "res://escenas/ui/game_setup/game_setup.tscn"))
    stats_btn.pressed.connect(func():
        get_tree().change_scene_to_file(
            "res://escenas/ui/stats/stats_screen.tscn"))
    settings_btn.pressed.connect(func():
        get_tree().change_scene_to_file(
            "res://escenas/ui/settings/settings_screen.tscn"))
```

### 19.3 — Cambiar escena de inicio

En `project.godot`:
```
[application]
run/main_scene="res://escenas/ui/main_menu/main_menu.tscn"
```

### Verificación

Al correr el juego: fondo verde, título dorado, tres botones funcionales.
"Nueva partida" lleva a GameSetup (aunque no exista aún: Godot mostrará error hasta
que se cree en Fase 21). "Estadísticas" y "Configuración" ídem.

---

## Fase 20 — Pantalla de configuración

**Objetivo:** Ajustar tamaño de fuente, velocidad de animaciones y tema de cartas.
Las opciones de audio aparecen como placeholders deshabilitados.

### 20.1 — Escena: `escenas/ui/settings/settings_screen.tscn`

```
Control "SettingsScreen"  (anchors: full rect)
└── ColorRect "Background"            color: #2D6A4F
└── VBoxContainer "Panel"             centrado, ancho máximo 480px
    ├── Label "Title"                 "Configuración", font_size=28
    ├── HSeparator
    │
    ├── Label "DisplayTitle"          "PANTALLA", font_size=11, color=#888888
    ├── HBoxContainer "FontSizeRow"
    │   ├── Label                     "Tamaño de fuente"
    │   └── HSlider "FontSlider"      min=11, max=20, step=1, value=14
    ├── HBoxContainer "SpeedRow"
    │   ├── Label                     "Velocidad de animación"
    │   └── HSlider "SpeedSlider"     min=0.5, max=2.0, step=0.25, value=1.0
    ├── HBoxContainer "ThemeRow"
    │   ├── Label                     "Tema de cartas"
    │   └── OptionButton "ThemeOpt"   opciones: "Clásico" (más adelante: más temas)
    │
    ├── HSeparator
    ├── Label "AudioTitle"            "AUDIO — Próximamente", font_size=11, color=#555555
    ├── HBoxContainer "MusicRow"      (deshabilitado)
    │   ├── Label                     "Música"
    │   └── HSlider "MusicSlider"     disabled=true, value=1.0
    ├── HBoxContainer "SFXRow"        (deshabilitado)
    │   ├── Label                     "Efectos"
    │   └── HSlider "SFXSlider"       disabled=true, value=1.0
    │
    ├── HSeparator
    └── HBoxContainer "Buttons"
        ├── Button "SaveBtn"          "Guardar"
        └── Button "BackBtn"          "Volver"
```

### 20.2 — `scripts/ui/settings_screen.gd`

```gdscript
extends Control

@onready var font_slider: HSlider     = $Panel/FontSizeRow/FontSlider
@onready var speed_slider: HSlider    = $Panel/SpeedRow/SpeedSlider
@onready var theme_opt: OptionButton  = $Panel/ThemeRow/ThemeOpt
@onready var save_btn: Button         = $Panel/Buttons/SaveBtn
@onready var back_btn: Button         = $Panel/Buttons/BackBtn

func _ready() -> void:
    font_slider.value  = SaveData.get_setting("font_size", 14)
    speed_slider.value = SaveData.get_setting("animation_speed", 1.0)

    theme_opt.clear()
    theme_opt.add_item("Clásico")        # index 0
    # Futuros temas se agregan aquí

    save_btn.pressed.connect(_on_save)
    back_btn.pressed.connect(_go_back)

func _on_save() -> void:
    SaveData.set_setting("font_size", int(font_slider.value))
    SaveData.set_setting("animation_speed", speed_slider.value)
    SaveData.set_setting("card_theme", "classic")  # expandir cuando haya más temas
    _go_back()

func _go_back() -> void:
    get_tree().change_scene_to_file(
        "res://escenas/ui/main_menu/main_menu.tscn")
```

**Nota sobre font_size:** La aplicación del tamaño de fuente al Theme global se
implementa en la Fase 24 (integración final), cuando todas las escenas existan.
Por ahora, el valor se guarda correctamente pero no se aplica en tiempo real.

### Verificación

Abrir configuración → mover sliders → guardar → volver → relanzar → los sliders
recuperan los valores guardados.

---

## Fase 21 — Pantalla de configuración de partida

**Objetivo:** Antes de empezar, el jugador elige su nombre y cuántos bots quiere
enfrentar. Cuando llegue el momento, aquí también se configurarán las ranuras de
jugadores humanos adicionales.

### 21.1 — Escena: `escenas/ui/game_setup/game_setup.tscn`

```
Control "GameSetup"  (anchors: full rect)
└── ColorRect "Background"            color: #2D6A4F
└── VBoxContainer "Panel"             centrado, ancho máximo 420px
    ├── Label "Title"                 "Nueva partida", font_size=28
    ├── HSeparator
    │
    ├── Label "NameLabel"             "Tu nombre"
    ├── LineEdit "NameInput"          placeholder: "Jugador", max_length=20
    │
    ├── Label "BotsLabel"             "Bots rivales"
    ├── HBoxContainer "BotsRow"
    │   ├── Button "BotMinus"         "−"
    │   ├── Label "BotsCount"         "1"
    │   └── Button "BotPlus"          "+"
    │
    ├── HSeparator
    └── HBoxContainer "Buttons"
        ├── Button "StartBtn"         "Comenzar"
        └── Button "BackBtn"          "Volver"
```

`BotsCount` muestra un valor entre 1 y 4 (máximo 4 bots → 5 jugadores total,
preparado para la futura versión multijugador donde los bots se reemplazan por humanos).

### 21.2 — `scripts/ui/game_setup.gd`

```gdscript
extends Control

const MIN_BOTS := 1
const MAX_BOTS := 4

var _bot_count: int = 1

@onready var name_input: LineEdit = $Panel/NameInput
@onready var bots_count: Label    = $Panel/BotsRow/BotsCount
@onready var bot_minus: Button    = $Panel/BotsRow/BotMinus
@onready var bot_plus: Button     = $Panel/BotsRow/BotPlus
@onready var start_btn: Button    = $Panel/Buttons/StartBtn
@onready var back_btn: Button     = $Panel/Buttons/BackBtn

func _ready() -> void:
    name_input.text = SaveData.get_setting("last_player_name", "")
    _update_bots_ui()

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

func _update_bots_ui() -> void:
    bots_count.text = str(_bot_count)
    bot_minus.disabled = _bot_count <= MIN_BOTS
    bot_plus.disabled  = _bot_count >= MAX_BOTS

func _on_start() -> void:
    var player_name := name_input.text.strip_edges()
    if player_name.is_empty():
        player_name = "Jugador"
    SaveData.set_setting("last_player_name", player_name)
    SaveData.ensure_player(player_name)
    # Pasar configuración al juego usando un singleton o variable global temporal.
    # Opción simple: guardar en SaveData como settings de sesión (no persisten):
    SaveData.settings["session_player_name"] = player_name
    SaveData.settings["session_bot_count"]   = _bot_count
    get_tree().change_scene_to_file("res://escenas/game/game.tscn")
```

### 21.3 — Adaptar `game.gd` para leer la configuración de sesión

En `_ready()` de `game.gd`, reemplazar la creación hardcodeada de jugadores:

```gdscript
func _ready() -> void:
    var player_name: String = SaveData.get_setting("session_player_name", "Jugador")
    var bot_count: int      = SaveData.get_setting("session_bot_count", 1)
    # Pasar estos valores a GameManager.setup()
    game_manager.setup(player_name, bot_count)
```

Actualizar `GameManager.setup()` para aceptar nombre y cantidad de bots:

```gdscript
func setup(player_name: String = "You", bot_count: int = 1) -> void:
    deck = Deck.build(3)
    ladder_manager = LadderManager.new()
    for _i in range(INITIAL_LADDERS):
        ladder_manager.add_ladder_slot()
    players.clear()
    players.append(Player.new(player_name, true))
    for i in range(bot_count):
        players.append(Player.new("Bot " + str(i + 1), false))
    for player in players:
        for _i in range(Player.WELL_SIZE):
            player.well.append(deck.draw())
        for _i in range(Player.MAX_HAND_SIZE):
            player.hand.append(deck.draw())
    current_player_index = randi() % players.size()
```

**Nota:** Con múltiples bots, `BotPlayer.play()` se llamará secuencialmente para
cada bot en `_on_turn_started()`. El flujo de turnos ya soporta N jugadores porque
`_advance_turn()` usa módulo sobre `players.size()`.

### Verificación

Abrir GameSetup → escribir nombre → elegir 2 bots → Comenzar → el juego arranca
con el nombre correcto en el HUD. El nombre persiste al volver a GameSetup.

---

## Fase 22 — Menú de pausa (overlay)

**Objetivo:** El jugador puede pausar en cualquier momento durante la partida.
Overlay semitransparente sobre el juego, sin cambiar de escena.

### 22.1 — Escena: `escenas/ui/pause_menu/pause_menu.tscn`

```
CanvasLayer "PauseMenu"
└── ColorRect "Overlay"              color: #00000088 (semitransparente), full rect
└── PanelContainer "Panel"           centrado, ancho 300px
    └── VBoxContainer (margins: 24px)
        ├── Label "Title"            "Pausa", font_size=28, centrado
        ├── HSeparator
        ├── Button "ResumeBtn"       "Continuar"
        ├── Button "RestartBtn"      "Reiniciar partida"
        ├── Button "SettingsBtn"     "Configuración"
        └── Button "MainMenuBtn"     "Menú principal"
```

### 22.2 — `scripts/ui/pause_menu.gd`

```gdscript
class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var resume_btn: Button    = $Panel/VBoxContainer/ResumeBtn
@onready var restart_btn: Button   = $Panel/VBoxContainer/RestartBtn
@onready var settings_btn: Button  = $Panel/VBoxContainer/SettingsBtn
@onready var main_menu_btn: Button = $Panel/VBoxContainer/MainMenuBtn

func _ready() -> void:
    resume_btn.pressed.connect(func(): resume_requested.emit())
    restart_btn.pressed.connect(func(): restart_requested.emit())
    main_menu_btn.pressed.connect(func(): main_menu_requested.emit())
    settings_btn.pressed.connect(func():
        # Abrir settings sin salir del juego: instanciar SettingsScreen como overlay
        # (Fase 24 detalla la integración completa)
        pass)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        resume_requested.emit()
```

### 22.3 — Integrar en `game.gd`

```gdscript
const PauseMenuScene := preload("res://escenas/ui/pause_menu/pause_menu.tscn")
var _pause_menu: PauseMenu = null

# Activar con Escape o un botón de pausa en el HUD:
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _toggle_pause()

func _toggle_pause() -> void:
    if _pause_menu != null:
        _unpause()
        return
    get_tree().paused = true
    _pause_menu = PauseMenuScene.instantiate()
    _pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_pause_menu)
    _pause_menu.resume_requested.connect(_unpause)
    _pause_menu.restart_requested.connect(_restart_game)
    _pause_menu.main_menu_requested.connect(func():
        get_tree().paused = false
        get_tree().change_scene_to_file(
            "res://escenas/ui/main_menu/main_menu.tscn"))

func _unpause() -> void:
    get_tree().paused = false
    if _pause_menu != null:
        _pause_menu.queue_free()
        _pause_menu = null

func _restart_game() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://escenas/game/game.tscn")
```

Agregar un botón de pausa al HUD (icono "≡" o "⏸") que llame `_toggle_pause()` en
`game.gd`. El `HUDView` emite una señal `pause_requested` que `game.gd` conecta.

**Nota sobre `process_mode`:** El overlay necesita `PROCESS_MODE_ALWAYS` para recibir
input mientras el árbol está pausado.

### Verificación

Durante la partida: Escape → aparece overlay semitransparente → "Continuar" lo cierra
→ el estado del juego se preserva exactamente. "Reiniciar" vuelve al juego desde cero.
"Menú principal" lleva al menú sin pausar el árbol permanentemente.

---

## Fase 23 — Pantalla de fin de partida

**Objetivo:** Reemplazar el mensaje del HUD con una pantalla dedicada que muestre
el ganador, un resumen de la partida y opciones claras para continuar.

### 23.1 — Escena: `escenas/ui/game_over/game_over.tscn`

```
CanvasLayer "GameOver"
└── ColorRect "Overlay"              color: #00000099, full rect
└── PanelContainer "Panel"           centrado, ancho 360px
    └── VBoxContainer (margins: 24px)
        ├── Label "ResultLabel"       "¡Ganaste!" o "El Bot ganó"  font_size=36
        ├── Label "WinnerName"        nombre del ganador, font_size=20, color=#F5C518
        ├── HSeparator
        ├── Label "TurnsLabel"        "Turnos jugados: 12"
        ├── Label "CardsLabel"        "Cartas jugadas: 47"
        ├── HSeparator
        ├── Button "PlayAgainBtn"     "Jugar de nuevo"
        └── Button "MainMenuBtn"     "Menú principal"
```

### 23.2 — `scripts/ui/game_over.gd`

```gdscript
class_name GameOver
extends CanvasLayer

@onready var result_label: Label    = $Panel/VBoxContainer/ResultLabel
@onready var winner_name: Label     = $Panel/VBoxContainer/WinnerName
@onready var turns_label: Label     = $Panel/VBoxContainer/TurnsLabel
@onready var cards_label: Label     = $Panel/VBoxContainer/CardsLabel
@onready var play_again_btn: Button = $Panel/VBoxContainer/PlayAgainBtn
@onready var main_menu_btn: Button  = $Panel/VBoxContainer/MainMenuBtn

func setup(winner: Player, human_name: String, turns: int, cards: int) -> void:
    if winner.is_human:
        result_label.text = "¡Ganaste!"
        result_label.add_theme_color_override("font_color", Color("#F5C518"))
    else:
        result_label.text = "¡Perdiste!"
        result_label.add_theme_color_override("font_color", Color("#CC2222"))
    winner_name.text = winner.name
    turns_label.text = "Turnos jugados: " + str(turns)
    cards_label.text = "Cartas jugadas: " + str(cards)

    play_again_btn.pressed.connect(func():
        get_tree().change_scene_to_file("res://escenas/game/game.tscn"))
    main_menu_btn.pressed.connect(func():
        get_tree().change_scene_to_file(
            "res://escenas/ui/main_menu/main_menu.tscn"))
```

### 23.3 — Integrar en `game.gd`

```gdscript
const GameOverScene := preload("res://escenas/ui/game_over/game_over.tscn")
var _turn_count: int = 0
var _cards_played: int = 0

# En _ready():
game_manager.turn_ended.connect(func(_p): _turn_count += 1)

# En try_play_card exitoso, incrementar _cards_played.
# La forma más limpia: conectar state_changed y comparar conteo,
# o trackear desde _on_ladder_clicked.

func _on_game_won(player: Player) -> void:
    # Guardar estadísticas
    var human := game_manager.players[0]
    if player.is_human:
        SaveData.record_win(human.name, _turn_count)
    else:
        SaveData.record_loss(human.name)
    SaveData.record_cards_played(human.name, _cards_played)
    # Mostrar pantalla de fin
    var go: GameOver = GameOverScene.instantiate()
    add_child(go)
    go.setup(player, human.name, _turn_count, _cards_played)
    hud.disable_actions()
```

### Verificación

Terminar una partida (ganar o perder) → aparece el overlay de fin de partida con los
datos correctos → "Jugar de nuevo" reinicia sin pasar por GameSetup → "Menú principal"
lleva al menú. Las estadísticas se guardan en disco.

---

## Fase 24 — Pantalla de estadísticas

**Objetivo:** Mostrar el historial de todos los jugadores que han jugado en el dispositivo.

### 24.1 — Escena: `escenas/ui/stats/stats_screen.tscn`

```
Control "StatsScreen"  (anchors: full rect)
└── ColorRect "Background"            color: #2D6A4F
└── VBoxContainer "Layout"            full rect con márgenes 24px
    ├── HBoxContainer "Header"
    │   ├── Label "Title"             "Estadísticas", font_size=28
    │   └── Button "BackBtn"          "← Volver", align right
    ├── HSeparator
    └── ScrollContainer "Scroll"      size_flags_vertical: EXPAND_FILL
        └── VBoxContainer "PlayerList"   (rellenado en código)
```

### 24.2 — `scripts/ui/stats_screen.gd`

```gdscript
extends Control

const PlayerCardScene := preload("res://escenas/ui/stats/player_stat_card.tscn")

@onready var player_list: VBoxContainer = $Layout/Scroll/PlayerList
@onready var back_btn: Button           = $Layout/Header/BackBtn

func _ready() -> void:
    back_btn.pressed.connect(func():
        get_tree().change_scene_to_file(
            "res://escenas/ui/main_menu/main_menu.tscn"))
    _populate()

func _populate() -> void:
    for child in player_list.get_children():
        child.queue_free()
    var names := SaveData.all_player_names()
    if names.is_empty():
        var lbl := Label.new()
        lbl.text = "Aún no hay partidas registradas."
        lbl.add_theme_color_override("font_color", Color("#888888"))
        player_list.add_child(lbl)
        return
    # Ordenar por victorias descendente
    names.sort_custom(func(a, b):
        return SaveData.get_player_stats(a)["wins"] > \
               SaveData.get_player_stats(b)["wins"])
    for name in names:
        var card: PlayerStatCard = PlayerCardScene.instantiate()
        card.setup(name, SaveData.get_player_stats(name))
        player_list.add_child(card)
```

### 24.3 — Sub-escena: `player_stat_card.tscn`

Una tarjeta por jugador:

```
PanelContainer "PlayerStatCard"
└── HBoxContainer (margins: 12px)
    ├── VBoxContainer (size_flags_h: EXPAND)
    │   ├── Label "NameLabel"       bold, font_size=18
    │   └── Label "GamesLabel"      "12 partidas · 75% victorias", font_size=12
    └── VBoxContainer (align right)
        ├── Label "WinsLabel"       "8 victorias", color=#44BB88
        ├── Label "LossesLabel"     "4 derrotas", color=#CC2222
        └── Label "FastestLabel"    "Mejor: 6 turnos", color=#F5C518
```

```gdscript
class_name PlayerStatCard
extends PanelContainer

func setup(player_name: String, stats: Dictionary) -> void:
    $HBox/Info/NameLabel.text = player_name
    var played: int = stats.get("games_played", 0)
    var wins: int   = stats.get("wins", 0)
    var pct: int    = 0 if played == 0 else int(100.0 * wins / played)
    $HBox/Info/GamesLabel.text = str(played) + " partidas · " + str(pct) + "% victorias"
    $HBox/Numbers/WinsLabel.text   = str(wins) + " victorias"
    $HBox/Numbers/LossesLabel.text = str(stats.get("losses", 0)) + " derrotas"
    var fastest: int = stats.get("fastest_win_turns", 0)
    $HBox/Numbers/FastestLabel.text = \
        "Mejor: " + (str(fastest) + " turnos" if fastest > 0 else "—")
```

### Verificación

Después de jugar algunas partidas, abrir Estadísticas → aparece una tarjeta por
jugador con sus datos reales, ordenadas por victorias. El ScrollContainer permite
desplazarse si hay muchos jugadores.

---

## Orden de implementación recomendado

```
18 → SaveData (AutoLoad)          sin UI — fundación para todo lo demás
19 → Main Menu                    primera pantalla visible al lanzar
20 → Settings Screen              independiente, no bloquea nada
21 → Game Setup                   conecta Main Menu con el juego
22 → Pause Menu                   mejora in-game, fácil de añadir
23 → Game Over                    cierra el loop completo de una partida
24 → Stats Screen                 cosmético, requiere datos de fase 23
```

---

## Consideraciones de responsividad (web → mobile)

- **Nunca usar posiciones absolutas** en los contenedores de menú. Siempre anchors
  `full rect` + `VBoxContainer`/`HBoxContainer` con `SIZE_SHRINK_CENTER`.
- **Touch targets:** botones con `custom_minimum_size` de al menos `Vector2(120, 44)`.
  En mobile los sliders de settings necesitan `min_size` más alto.
- **Font size dinámica:** cuando se implemente la aplicación del setting, cambiar el
  `font_size` del `Theme` global y emitir una señal desde `SaveData` para que las
  vistas activas se actualicen sin reiniciar la escena.
- **Orientación:** para mobile, probar tanto portrait como landscape. El layout
  centrado con `VBoxContainer` funciona en ambas orientaciones sin cambios.

---

## Archivos a crear/modificar

| Archivo | Acción |
|---------|--------|
| `scripts/data/save_data.gd` | Crear (AutoLoad) |
| `project.godot` | Modificar: AutoLoad + main_scene |
| `escenas/ui/main_menu/main_menu.tscn` | Crear |
| `scripts/ui/main_menu.gd` | Crear |
| `escenas/ui/settings/settings_screen.tscn` | Crear |
| `scripts/ui/settings_screen.gd` | Crear |
| `escenas/ui/game_setup/game_setup.tscn` | Crear |
| `scripts/ui/game_setup.gd` | Crear |
| `escenas/ui/pause_menu/pause_menu.tscn` | Crear |
| `scripts/ui/pause_menu.gd` | Crear |
| `escenas/ui/game_over/game_over.tscn` | Crear |
| `scripts/ui/game_over.gd` | Crear |
| `escenas/ui/stats/stats_screen.tscn` | Crear |
| `scripts/ui/stats_screen.gd` | Crear |
| `escenas/ui/stats/player_stat_card.tscn` | Crear |
| `scripts/ui/player_stat_card.gd` | Crear |
| `scripts/logic/game_manager.gd` | Modificar: setup() acepta nombre y bot_count |
| `scripts/ui/game.gd` | Modificar: leer sesión, mostrar GameOver, pausa |
| `scripts/ui/hud_view.gd` | Modificar: agregar botón/señal de pausa |

---

## Checklist de verificación por fase

- [ ] Fase 18: `SaveData.get_setting("font_size")` devuelve 14; persiste tras relanzar
- [ ] Fase 19: Menú principal visible al lanzar; tres botones navegan correctamente
- [ ] Fase 20: Settings guarda y recupera valores; sliders de audio visibles pero deshabilitados
- [ ] Fase 21: Nombre del jugador aparece en el HUD; múltiples bots funcionan en secuencia
- [ ] Fase 22: Escape pausa; overlay semitransparente; Continuar preserva el estado
- [ ] Fase 23: Pantalla de fin reemplaza al mensaje del HUD; estadísticas se guardan en disco
- [ ] Fase 24: Lista de jugadores con victorias/derrotas/mejor partida; scroll funciona
