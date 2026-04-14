# El Pozo — Implementación visual (Fases 8–13)

Continuación de `implementacion.md`. Las fases 1–7 (lógica, UI base, bot, tests) están
completas. Este documento cubre la capa visual: tema, diseño de cartas, estados
interactivos, layout y el diálogo de comodín.

Cada fase es ejecutable de forma independiente y verificable antes de pasar a la siguiente.

---

## Estado actual (resumen)

| Componente       | Estado actual                                      |
|------------------|----------------------------------------------------|
| CardView         | Texto plano sobre PanelContainer gris por defecto  |
| LadderView       | Etiquetas de texto, sin distinción visual          |
| PlayerAreaView   | VBox sin bordes ni colores diferenciadores         |
| HUDView          | Label + Button sin estilo                          |
| Hover/selección  | Ninguno                                            |
| Comodín          | `_ask_joker_value()` hardcodeado → devuelve 1      |
| Fondo de escena  | Gris Godot por defecto                             |

---

## Paleta de colores (referencia para todas las fases)

```
COLOR_TABLE_GREEN   = #2D6A4F   fondo de mesa de cartas
COLOR_CARD_WHITE    = #F8F4E3   fondo de carta (marfil cálido)
COLOR_CARD_BACK     = #1A3A5C   dorso de carta (azul marino)
COLOR_SUIT_RED      = #CC2222   corazones y diamantes
COLOR_SUIT_BLACK    = #111111   picas y tréboles
COLOR_HIGHLIGHT     = #F5C518   carta seleccionada (dorado)
COLOR_VALID_TARGET  = #44BB88   escalera destino válido (verde menta)
COLOR_BORDER        = #C8B88A   borde de carta (dorado suave)
COLOR_HUD_BG        = #1A2530   fondo del HUD (azul muy oscuro)
COLOR_TEXT_LIGHT    = #F0EDE0   texto sobre fondos oscuros
COLOR_TEXT_DARK     = #1A1A1A   texto sobre fondos claros
```

---

## Fase 8 — Tema visual base

**Objetivo:** Establecer paleta de colores y estilos reutilizables en un archivo `.tres`.
Sin este paso los demás estilos quedan dispersos en código y son difíciles de mantener.

### 8.1 — Crear el archivo de tema en el editor

1. En el panel FileSystem del editor: clic derecho en `res://` → `New Folder` → nombrar `temas`
2. Clic derecho en `res://temas/` → `New Resource` → buscar `Theme` → guardar como `juego.tres`
3. Doble clic en `juego.tres` para abrir el Theme Editor
4. Configurar los siguientes tipos y overrides:

**Panel → StyleBox "panel" → StyleBoxFlat:**
```
bg_color            = #F8F4E3
border_width_all    = 2
border_color        = #C8B88A
corner_radius_all   = 6
content_margin_all  = 4
```

**Button → StyleBox "normal" → StyleBoxFlat:**
```
bg_color            = #2D6A4F
border_width_all    = 2
border_color        = #44BB88
corner_radius_all   = 6
```

**Button → StyleBox "hover" → StyleBoxFlat (duplicar normal y cambiar):**
```
bg_color            = #3D8A6F
border_color        = #F5C518
```

**Button → StyleBox "pressed" → StyleBoxFlat:**
```
bg_color            = #1D4A3F
```

**Button → Color "font_color":**  `#F0EDE0`
**Button → Color "font_hover_color":** `#FFFFFF`
**Button → int "font_size":** `16`

**Label → Color "font_color":** `#F0EDE0`
**Label → int "font_size":** `14`

### 8.2 — Aplicar tema a la escena principal

En `escenas/game/game.tscn`:
- Seleccionar el nodo raíz (Control "Game")
- Inspector → Theme → cargar `res://temas/juego.tres`

### 8.3 — Color de fondo global

En `project.godot` (editar manualmente o via Project Settings):
```ini
[rendering]
environment/defaults/default_clear_color=Color(0.176, 0.416, 0.310, 1)
```

Esto equivale al verde `#2D6A4F`. También puede hacerse desde
`Project → Project Settings → Rendering → Environment → Default Clear Color`.

### Cómo probar la Fase 8

1. Abrir Godot, correr la escena `game.tscn` (F5 o el botón Play)
2. **Resultado esperado:**
   - El fondo de pantalla es verde oscuro (como mesa de cartas), no gris
   - El botón "Terminar turno" tiene fondo verde con borde verde menta
   - Al pasar el mouse sobre el botón, su borde se vuelve dorado
   - Las cartas y paneles tienen fondo marfil en lugar de gris por defecto
3. **Error común:** Si el fondo sigue gris, verificar que el nodo raíz de `game.tscn`
   tenga el Theme asignado en el Inspector, no otro nodo hijo.

---

## Fase 9 — Rediseño de CardView

**Objetivo:** Las cartas deben verse como cartas reales: valor arriba-izquierda, palo
grande en el centro, bordes redondeados. Dorso distinto para cartas boca abajo.

### 9.1 — Nueva estructura de nodos en `card.tscn`

Abrir `escenas/ui/card/card.tscn` en el editor y reemplazar la estructura actual:

```
PanelContainer "CardView"
  custom_minimum_size = Vector2(80, 120)
└── MarginContainer
      theme_override_constants/margin_left   = 6
      theme_override_constants/margin_right  = 6
      theme_override_constants/margin_top    = 6
      theme_override_constants/margin_bottom = 6
    └── VBoxContainer
        ├── HBoxContainer "Top"
        │   ├── Label "ValueLabel"
        │   │     theme_override_font_sizes/font_size = 14
        │   │     horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        │   └── Label "SuitSmall"
        │         theme_override_font_sizes/font_size = 14
        │         horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        │         size_flags_horizontal = SIZE_EXPAND_FILL
        └── Label "SuitBig"
              theme_override_font_sizes/font_size = 44
              horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
              vertical_alignment = VERTICAL_ALIGNMENT_CENTER
              size_flags_vertical = SIZE_EXPAND_FILL
```

### 9.2 — Actualizar `scripts/ui/card_view.gd`

Reemplazar el script completo:

```gdscript
class_name CardView
extends PanelContainer

signal card_clicked(card_view: CardView)

@export var card_data: Card = null:
	set(v):
		card_data = v
		_refresh()

@export var face_down: bool = false:
	set(v):
		face_down = v
		_refresh()

var _is_selected: bool = false

@onready var value_label: Label = $MarginContainer/VBoxContainer/Top/ValueLabel
@onready var suit_small: Label  = $MarginContainer/VBoxContainer/Top/SuitSmall
@onready var suit_big: Label    = $MarginContainer/VBoxContainer/SuitBig

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_face_down: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	_refresh()
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	gui_input.connect(_on_gui_input)

func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color("#F8F4E3")
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color("#C8B88A")
	_style_normal.set_corner_radius_all(6)
	_style_normal.set_content_margin_all(6)

	_style_selected = _style_normal.duplicate()
	_style_selected.border_color = Color("#F5C518")
	_style_selected.set_border_width_all(3)

	_style_face_down = _style_normal.duplicate()
	_style_face_down.bg_color = Color("#1A3A5C")
	_style_face_down.border_color = Color("#2A5A8C")

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_style()

func _apply_style() -> void:
	if face_down or card_data == null:
		add_theme_stylebox_override("panel", _style_face_down)
	elif _is_selected:
		add_theme_stylebox_override("panel", _style_selected)
	else:
		add_theme_stylebox_override("panel", _style_normal)

func _refresh() -> void:
	if not is_inside_tree():
		return
	_apply_style()
	if face_down or card_data == null:
		value_label.text = ""
		suit_small.text = ""
		suit_big.text = "?"
		suit_big.add_theme_color_override("font_color", Color("#4A6A8C"))
		return
	value_label.text = card_data.display_value()
	suit_small.text = card_data.suit_symbol()
	suit_big.text = card_data.suit_symbol()
	var is_red := card_data.suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS]
	var color := Color("#CC2222") if is_red else Color("#111111")
	value_label.add_theme_color_override("font_color", color)
	suit_small.add_theme_color_override("font_color", color)
	suit_big.add_theme_color_override("font_color", color)

func _on_hover_enter() -> void:
	if not face_down and card_data != null:
		# Cambiar borde a dorado en hover (alternativa al desplazamiento vertical,
		# que puede romper el layout de HBoxContainer)
		var style := _style_selected.duplicate() if _is_selected else _style_normal.duplicate()
		style.border_color = Color("#F5C518")
		add_theme_stylebox_override("panel", style)

func _on_hover_exit() -> void:
	_apply_style()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	   and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)
```

### Cómo probar la Fase 9

1. Correr el juego
2. **Resultado esperado:**
   - Las cartas del jugador tienen fondo marfil (`#F8F4E3`) con borde dorado suave
   - El valor (A, 2, K, etc.) aparece arriba a la izquierda
   - El símbolo del palo aparece grande en el centro
   - Las cartas de corazones y diamantes tienen texto rojo
   - Las cartas de picas y tréboles tienen texto negro
   - Las 5 cartas del bot son azul marino con "?" en el centro
   - Al pasar el mouse sobre una carta propia, su borde se vuelve dorado
3. **Error común:** Si los nodos `@onready` dan error, verificar que los nombres en
   `card.tscn` coincidan exactamente con los paths del script
   (`$MarginContainer/VBoxContainer/Top/ValueLabel`, etc.)

---

## Fase 10 — Estados visuales interactivos

**Objetivo:** El jugador debe saber en todo momento qué está seleccionado, qué puede
hacer, y cuándo es el turno del bot.

### 10.1 — Carta seleccionada: tracking en `game.gd`

Agregar variable de tracking y método de limpieza al inicio de `scripts/ui/game.gd`:

```gdscript
# Agregar junto a las otras variables de estado:
var _selected_card_view: CardView = null

func _clear_selection() -> void:
	if _selected_card_view != null:
		_selected_card_view.set_selected(false)
		_selected_card_view = null
	_clear_ladder_highlights()
```

Modificar `_on_human_card_selected` para seleccionar visualmente la carta:

```gdscript
func _on_human_card_selected(source: GameManager.CardSource,
							  index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return

	if state == InteractionState.AWAITING_BOARD_COL:
		if source == GameManager.CardSource.HAND:
			var col := game_manager.current_player().board.size()
			_do_end_turn(index, col)
		return

	# Limpiar selección previa
	_clear_selection()

	selected_source = source
	selected_index = index
	selected_card = card
	state = InteractionState.CARD_SELECTED

	# Resaltar la carta seleccionada
	var cv := human_area.get_card_view(source, index)
	if cv != null:
		cv.set_selected(true)
		_selected_card_view = cv

	# Resaltar escaleras válidas
	_highlight_valid_ladders(card)

	hud.set_status("Elegí una escalera para jugar " + card.label())
```

Modificar `_on_ladder_clicked` para limpiar al terminar:

```gdscript
func _on_ladder_clicked(ladder_index: int) -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var joker_value := 0
	if selected_card.is_joker:
		joker_value = _ask_joker_value()
	var ok := game_manager.try_play_card(
		selected_source, selected_index, ladder_index, joker_value)
	_clear_selection()   # ← agregar esta línea
	if not ok:
		hud.set_status("No se puede jugar ahí. Elegí otra escalera.")
	else:
		hud.set_status("Jugaste " + selected_card.label() + ". Seguí jugando o terminá el turno.")
	state = InteractionState.IDLE
```

### 10.2 — Exponer CardView desde PlayerAreaView

Agregar en `scripts/ui/player_area_view.gd`:

```gdscript
func get_card_view(source: GameManager.CardSource, index: int) -> CardView:
	match source:
		GameManager.CardSource.HAND:
			var children := hand_container.get_children()
			if index < children.size():
				return children[index] as CardView
		GameManager.CardSource.BOARD:
			var children := board_container.get_children()
			if index < children.size():
				return children[index] as CardView
		GameManager.CardSource.WELL:
			var children := well_top_slot.get_children()
			if not children.is_empty():
				return children[0] as CardView
	return null
```

### 10.3 — Escaleras válidas resaltadas en `ladder_view.gd`

Agregar estilos y método en `scripts/ui/ladder_view.gd`:

```gdscript
var _style_normal: StyleBoxFlat
var _style_valid: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	gui_input.connect(_on_gui_input)
	refresh()

func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color("#F8F4E3")
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color("#C8B88A")
	_style_normal.set_corner_radius_all(6)

	_style_valid = _style_normal.duplicate()
	_style_valid.bg_color = Color("#D4F0E0")
	_style_valid.border_color = Color("#44BB88")
	_style_valid.set_border_width_all(3)

func set_valid_target(valid: bool) -> void:
	if valid:
		add_theme_stylebox_override("panel", _style_valid)
	else:
		add_theme_stylebox_override("panel", _style_normal)
```

Agregar en `scripts/ui/game.gd`:

```gdscript
func _highlight_valid_ladders(card: Card) -> void:
	for lv in ladders_container.get_children():
		var ladder_view := lv as LadderView
		if ladder_view == null:
			continue
		var can := game_manager.ladder_manager.can_play_on(
			card, ladder_view.ladder_index,
			1 if card.is_joker else 0)
		ladder_view.set_valid_target(can)

func _clear_ladder_highlights() -> void:
	for lv in ladders_container.get_children():
		var ladder_view := lv as LadderView
		if ladder_view != null:
			ladder_view.set_valid_target(false)
```

**Nota para comodines en highlight:** `_highlight_valid_ladders` con joker_value=1 puede
mostrar un highlight incompleto (el comodín puede ir en más lugares). Por ahora es
suficiente para el MVP; se refina junto a la Fase 12.

### 10.4 — Dimming durante turno del bot

Modificar `_on_turn_started` en `scripts/ui/game.gd`:

```gdscript
func _on_turn_started(player: Player) -> void:
	if not player.is_human:
		human_area.modulate = Color(0.5, 0.5, 0.5, 1.0)
		hud.set_status("Bot está pensando...")
		await get_tree().create_timer(0.8).timeout
		BotPlayer.play(game_manager)
		_refresh_all()
		human_area.modulate = Color(1.0, 1.0, 1.0, 1.0)
		hud.set_status("Tu turno")
```

### Cómo probar la Fase 10

1. Correr el juego, esperar a que sea turno del jugador
2. **Prueba de selección:** Hacer clic en una carta de la mano
   - Resultado: la carta muestra borde dorado grueso; las escaleras donde puede jugarse
     se ponen con fondo verde menta
3. **Prueba de escalera inválida:** Con carta seleccionada, hacer clic en una escalera
   en verde (válida) y otra sin verde (inválida)
   - Resultado válida: la carta se juega, los highlights desaparecen
   - Resultado inválida: mensaje de error en el HUD, la selección se limpia
4. **Prueba de turno del bot:** Terminar el turno
   - Resultado: el área del jugador se pone gris/atenuada durante 0.8s, luego vuelve
     al color normal cuando es el turno del jugador de nuevo
5. **Error común:** Si `get_card_view` devuelve null, verificar que `_rebuild_cards`
   en `player_area_view.gd` añade los CardView directamente al container (sin wrappers
   adicionales), o ajustar el path en `get_card_view`.

---

## Fase 11 — Rediseño de LadderView y zona central

**Objetivo:** Las escaleras deben verse como zonas de juego claras con una mini-carta
visual, no como líneas de texto plano.

### 11.1 — Nueva estructura de `ladder.tscn`

Abrir `escenas/ui/ladder/ladder.tscn` y reemplazar la estructura:

```
PanelContainer "LadderView"
  custom_minimum_size = Vector2(90, 150)
└── MarginContainer (margins: 6px all)
    └── VBoxContainer (separation: 4)
        ├── Label "LadderNum"
        │     theme_override_font_sizes/font_size = 10
        │     horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        │     modulate = Color(0.7, 0.7, 0.7, 1)   ← gris suave
        ├── PanelContainer "CardSlot"
        │     custom_minimum_size = Vector2(70, 95)
        │     size_flags_horizontal = SIZE_EXPAND_FILL
        │   └── Label "TopCard"
        │         theme_override_font_sizes/font_size = 22
        │         horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        │         vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        │         anchors_preset = PRESET_FULL_RECT
        └── Label "NextNeeded"
              theme_override_font_sizes/font_size = 11
              horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
```

### 11.2 — Actualizar `scripts/ui/ladder_view.gd`

Reemplazar el script completo:

```gdscript
class_name LadderView
extends PanelContainer

signal ladder_clicked(ladder_index: int)

var ladder_data: Array = []
var ladder_index: int = -1

@onready var ladder_num_label: Label        = $MarginContainer/VBoxContainer/LadderNum
@onready var card_slot_panel: PanelContainer = $MarginContainer/VBoxContainer/CardSlot
@onready var top_card_label: Label          = $MarginContainer/VBoxContainer/CardSlot/TopCard
@onready var next_label: Label              = $MarginContainer/VBoxContainer/NextNeeded

var _style_ladder_normal: StyleBoxFlat
var _style_empty: StyleBoxFlat
var _style_active: StyleBoxFlat
var _style_valid: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	gui_input.connect(_on_gui_input)
	refresh()

func _build_styles() -> void:
	# Estilo del PanelContainer exterior (la escalera en sí)
	_style_ladder_normal = StyleBoxFlat.new()
	_style_ladder_normal.bg_color = Color("#3A7A5F")   # verde más claro que la mesa
	_style_ladder_normal.set_border_width_all(2)
	_style_ladder_normal.border_color = Color("#5AAA8F")
	_style_ladder_normal.set_corner_radius_all(8)

	_style_valid = _style_ladder_normal.duplicate()
	_style_valid.border_color = Color("#44BB88")
	_style_valid.set_border_width_all(3)
	_style_valid.bg_color = Color("#2D8A6F")

	# Estilos del CardSlot interior
	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color("#2A5A4F")
	_style_empty.set_border_width_all(1)
	_style_empty.border_color = Color("#3A7A6F")
	_style_empty.set_corner_radius_all(4)

	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color("#F8F4E3")
	_style_active.set_border_width_all(2)
	_style_active.border_color = Color("#C8B88A")
	_style_active.set_corner_radius_all(4)

	add_theme_stylebox_override("panel", _style_ladder_normal)

func set_valid_target(valid: bool) -> void:
	if valid:
		add_theme_stylebox_override("panel", _style_valid)
	else:
		add_theme_stylebox_override("panel", _style_ladder_normal)

func refresh() -> void:
	if not is_inside_tree():
		return
	ladder_num_label.text = "Escalera " + str(ladder_index + 1)
	if ladder_data.is_empty():
		top_card_label.text = "A"
		top_card_label.add_theme_color_override("font_color", Color("#7ABAAA"))
		next_label.text = "libre"
		card_slot_panel.add_theme_stylebox_override("panel", _style_empty)
	else:
		var top: Card = ladder_data.back()
		top_card_label.text = top.label()
		var is_red := top.suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS]
		var color := Color("#CC2222") if is_red else Color("#111111")
		top_card_label.add_theme_color_override("font_color", color)
		card_slot_panel.add_theme_stylebox_override("panel", _style_active)
		var next_val := top.value + 1
		if next_val > 13:
			next_label.text = "¡Completa!"
			next_label.add_theme_color_override("font_color", Color("#F5C518"))
		else:
			next_label.text = "→ " + _val_display(next_val)
			next_label.remove_theme_color_override("font_color")

func _val_display(v: int) -> String:
	match v:
		1:  return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_:  return str(v)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	   and event.button_index == MOUSE_BUTTON_LEFT:
		ladder_clicked.emit(ladder_index)
```

### 11.3 — Deck visual en `game.tscn`

Reemplazar el DeckArea en `escenas/game/game.tscn`:

```
VBoxContainer "DeckArea"
  custom_minimum_size = Vector2(90, 0)
├── Label "DeckTitle"
│     text = "MAZO"
│     horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
│     theme_override_font_sizes/font_size = 11
│     modulate = Color(0.8, 0.8, 0.8, 1)
├── PanelContainer "DeckCard"
│     custom_minimum_size = Vector2(80, 110)
│   └── Label "DeckCount"
│         anchors_preset = PRESET_FULL_RECT
│         theme_override_font_sizes/font_size = 20
│         horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
│         vertical_alignment = VERTICAL_ALIGNMENT_CENTER
└── Label "DeckSubtitle"
      text = "cartas"
      horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      theme_override_font_sizes/font_size = 10
      modulate = Color(0.6, 0.6, 0.6, 1)
```

El `DeckCard` recibe la StyleBox de dorso de carta (`#1A3A5C`) directamente en el editor,
o en `game.gd` al arrancar:

```gdscript
# En _ready() de game.gd, después de crear el game_manager:
var deck_style := StyleBoxFlat.new()
deck_style.bg_color = Color("#1A3A5C")
deck_style.set_border_width_all(2)
deck_style.border_color = Color("#2A5A8C")
deck_style.set_corner_radius_all(6)
$Layout/CentralArea/DeckArea/DeckCard.add_theme_stylebox_override("panel", deck_style)
```

Actualizar `_refresh_all` en `game.gd` para referenciar el nuevo nodo:

```gdscript
func _refresh_all() -> void:
	human_area.refresh(game_manager.players[0])
	bot_area.refresh(game_manager.players[1])
	_rebuild_ladders()
	$Layout/CentralArea/DeckArea/DeckCard/DeckCount.text = str(game_manager.deck.size())
	hud.refresh(game_manager)
```

### Cómo probar la Fase 11

1. Correr el juego
2. **Resultado esperado:**
   - Cada escalera tiene su número ("Escalera 1", "Escalera 2", etc.)
   - Escaleras vacías: slot interior oscuro con "A" gris y texto "libre"
   - Escaleras con cartas: slot interior marfil con la carta actual (roja/negra según palo)
     y el valor siguiente ("→ 5", "→ J", etc.)
   - Cuando una escalera se completa (llega a K): aparece "¡Completa!" en dorado,
     luego la escalera se resetea a vacía
   - El mazo aparece como un panel azul marino con el número de cartas restantes
3. **Error común:** Si `ladder_num_label` da null pointer, verificar que el path del nodo
   en la escena coincide exactamente con `$MarginContainer/VBoxContainer/LadderNum`.

---

## Fase 12 — Comodín automático

**Objetivo:** El comodín toma automáticamente el valor que corresponde a la escalera
donde se coloca. No se necesita ningún diálogo de selección.

**Razonamiento:** Cada escalera necesita exactamente un valor en cada momento (el
siguiente al tope actual, o As si está vacía). Cuando el jugador elige una escalera
para colocar un comodín, el valor es unívoco — no hay ambigüedad ni elección posible.
Forzar al jugador a elegir el valor en un diálogo sería redundante e interrumpe el flujo.

### 12.1 — Helper para derivar el valor del comodín

En `scripts/ui/game.gd`, agregar:

```gdscript
# Derives the joker value automatically from the ladder's current state:
#   - Empty ladder → 1 (Ace)
#   - Ladder with cards → top card value + 1
# This is unambiguous: each ladder slot needs exactly one specific value.
func _joker_value_for_ladder(ladder_index: int) -> int:
	var ladder: Array = game_manager.ladder_manager.ladders[ladder_index]
	if ladder.is_empty():
		return 1
	return ladder.back().value + 1
```

### 12.2 — Actualizar `_on_ladder_clicked`

Reemplazar el stub `_ask_joker_value()` con la derivación automática:

```gdscript
func _on_ladder_clicked(ladder_index: int) -> void:
	if state != InteractionState.CARD_SELECTED:
		return
	var joker_value := 0
	if selected_card.is_joker:
		joker_value = _joker_value_for_ladder(ladder_index)
	var ok := game_manager.try_play_card(
		selected_source, selected_index, ladder_index, joker_value)
	_clear_selection()
	_clear_ladder_highlights()
	if not ok:
		hud.set_status("Can't play there. Choose another ladder.")
	else:
		hud.set_status("Played " + selected_card.label() + ". Keep playing or end your turn.")
	state = InteractionState.IDLE
```

Eliminar el método `_ask_joker_value()` que ya no se usa.

### 12.3 — Corregir `_highlight_valid_ladders` para comodines

El código actual pasa `joker_value = 1` al chequear escaleras con un comodín,
lo que solo resalta escaleras vacías. La corrección: un comodín es válido en
cualquier escalera que no esté completa (top < 13).

```gdscript
func _highlight_valid_ladders(card: Card) -> void:
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv == null:
			continue
		var can_play: bool
		if card.is_joker:
			# Joker is valid anywhere the auto-derived value fits (any non-complete ladder)
			var auto_value := _joker_value_for_ladder(lv.ladder_index)
			can_play = auto_value <= 13
		else:
			can_play = game_manager.ladder_manager.can_play_on(card, lv.ladder_index)
		lv.set_valid_target(can_play)
```

### Cómo probar la Fase 12

1. Correr el juego y obtener un comodín en la mano (o editar `deck.gd`
   temporalmente para colocar comodines al inicio del array antes de barajar)
2. Seleccionar el comodín
3. **Resultado esperado:** todas las escaleras no completas se resaltan en verde
4. Hacer clic en una escalera que tiene tope 5
5. **Resultado esperado:** el comodín se coloca con valor 6, la escalera muestra
   "Needs: 7" — sin ningún diálogo de por medio
6. Hacer clic en una escalera vacía
7. **Resultado esperado:** el comodín se coloca como As (valor 1), la escalera
   muestra "Needs: 2"

---

## Fase 13 — Mejoras de layout y legibilidad

**Objetivo:** La jerarquía visual debe comunicar la estructura del juego: zona del
oponente arriba (pequeña), escaleras en el centro (prominentes), zona propia abajo
(grande), HUD al pie.

### 13.1 — ColorRect de fondo en `game.tscn`

Como respaldo al color de Project Settings, agregar como primer hijo del nodo raíz:

```
ColorRect "Background"
  layout_mode = 1  (anchors)
  anchors_preset = PRESET_FULL_RECT
  color = #2D6A4F
```

Mover al primer lugar en el árbol de nodos para que quede detrás de todo.

### 13.2 — Separadores y labels de sección en `player_area.tscn`

Reemplazar la estructura de `escenas/ui/player_area/player_area.tscn`:

```
VBoxContainer "PlayerAreaView"
├── HBoxContainer "NameRow"
│   ├── Label "PlayerName"
│   │     theme_override_font_sizes/font_size = 16
│   └── Label "WellCount"
│         theme_override_font_sizes/font_size = 14
│         theme_override_colors/font_color = #F5C518
│         size_flags_horizontal = SIZE_EXPAND_FILL
│         horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
├── HSeparator
├── HBoxContainer "WellAndBoard"
│   ├── VBoxContainer "WellZone"
│   │   ├── Label "WellTitle"
│   │   │     text = "POZO"
│   │   │     theme_override_font_sizes/font_size = 10
│   │   │     modulate = Color(0.7, 0.7, 0.7, 1)
│   │   └── Control "WellTopSlot"
│   │         custom_minimum_size = Vector2(80, 120)
│   ├── VSeparator
│   └── VBoxContainer "BoardZone"
│       ├── Label "BoardTitle"
│       │     text = "TABLERO"
│       │     theme_override_font_sizes/font_size = 10
│       │     modulate = Color(0.7, 0.7, 0.7, 1)
│       └── HBoxContainer "Board"
│             size_flags_horizontal = SIZE_EXPAND_FILL
├── HSeparator
└── VBoxContainer "HandZone"
    ├── Label "HandTitle"
    │     text = "MANO"
    │     theme_override_font_sizes/font_size = 10
    │     modulate = Color(0.7, 0.7, 0.7, 1)
    └── HBoxContainer "Hand"
          separation = 4
```

Actualizar los `@onready` en `scripts/ui/player_area_view.gd` para los nuevos paths:

```gdscript
@onready var name_label: Label       = $NameRow/PlayerName
@onready var well_count: Label       = $NameRow/WellCount
@onready var well_top_slot: Control  = $WellAndBoard/WellZone/WellTopSlot
@onready var board_container: HBoxContainer = $WellAndBoard/BoardZone/Board
@onready var hand_container: HBoxContainer  = $HandZone/Hand
```

Actualizar `refresh` para usar el nuevo label de conteo:

```gdscript
func refresh(player: Player) -> void:
	name_label.text = player.name
	well_count.text = "♦ " + str(player.well.size())
	# ... resto sin cambios
```

### 13.3 — Profundidad de columnas del tablero

Modificar `_rebuild_cards` en `player_area_view.gd` para el caso BOARD. Reemplazar
la llamada `_rebuild_cards(board_container, player.board_tops(), ...)` por un loop
directo en `refresh`:

```gdscript
# En refresh(), reemplazar la línea de board tops:
for child in board_container.get_children():
	child.queue_free()
for i in range(player.board.size()):
	var col: Array = player.board[i]
	if col.is_empty():
		continue
	var cv: CardView = CardScene.instantiate()
	cv.card_data = col.back()
	var idx := i
	cv.card_clicked.connect(
		func(_v): card_selected.emit(GameManager.CardSource.BOARD, idx, col.back()))
	if col.size() > 1:
		var wrapper := VBoxContainer.new()
		wrapper.add_child(cv)
		var count_lbl := Label.new()
		count_lbl.text = "×" + str(col.size())
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_color_override("font_color", Color("#AAAAAA"))
		wrapper.add_child(count_lbl)
		board_container.add_child(wrapper)
	else:
		board_container.add_child(cv)
```

**Nota:** Si `get_card_view(BOARD, index)` se usa en la Fase 10, actualizar ese método
para que pueda buscar dentro de wrappers VBoxContainer también:

```gdscript
GameManager.CardSource.BOARD:
	var children := board_container.get_children()
	if index < children.size():
		var child := children[index]
		if child is CardView:
			return child as CardView
		# Si está en wrapper
		var grandchildren := child.get_children()
		if not grandchildren.is_empty() and grandchildren[0] is CardView:
			return grandchildren[0] as CardView
```

### 13.4 — HUD mejorado

Reemplazar la estructura de `escenas/ui/hud/hud.tscn`:

```
PanelContainer "HUD"
  custom_minimum_size = Vector2(0, 60)
└── MarginContainer (margins: 8 vertical, 16 horizontal)
    └── HBoxContainer (separation: 16)
        ├── VBoxContainer
        │   size_flags_horizontal = SIZE_EXPAND_FILL
        │   ├── Label "StatusLabel"
        │   │     theme_override_font_sizes/font_size = 15
        │   └── Label "LogLabel"
        │         theme_override_font_sizes/font_size = 11
        │         modulate = Color(0.7, 0.7, 0.7, 1)
        │         autowrap_mode = AUTOWRAP_WORD
        └── Button "EndTurnBtn"
              text = "Terminar turno"
              custom_minimum_size = Vector2(150, 44)
```

Agregar estilo de fondo al HUD en el editor (en el PanelContainer "HUD"):
- Theme Override → StyleBox "panel" → StyleBoxFlat:
  ```
  bg_color = #1A2530
  border_width_top = 2
  border_color = #44BB88
  ```

Actualizar `scripts/ui/hud_view.gd`:

```gdscript
class_name HUDView
extends PanelContainer

signal end_turn_requested()

@onready var status_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/StatusLabel
@onready var log_label: Label    = $MarginContainer/HBoxContainer/VBoxContainer/LogLabel
@onready var end_turn_btn: Button = $MarginContainer/HBoxContainer/EndTurnBtn

var _log_lines: Array[String] = []

func _ready() -> void:
	end_turn_btn.pressed.connect(func(): end_turn_requested.emit())

func set_status(text: String) -> void:
	status_label.text = text

func log_action(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 3:
		_log_lines.pop_front()
	log_label.text = " | ".join(_log_lines)

func disable_actions() -> void:
	end_turn_btn.disabled = true

func refresh(gm: GameManager) -> void:
	var p := gm.current_player()
	end_turn_btn.visible = p.is_human
	end_turn_btn.disabled = false
```

Agregar llamadas a `hud.log_action(...)` en `game.gd` al jugar exitosamente:

```gdscript
# En _on_ladder_clicked, cuando ok == true:
hud.log_action("Jugaste " + selected_card.label())
```

### 13.5 — Indicador de turno activo

Agregar en `scripts/ui/player_area_view.gd`:

```gdscript
func set_active_turn(is_active: bool) -> void:
	if is_active:
		name_label.add_theme_color_override("font_color", Color("#F5C518"))
	else:
		name_label.remove_theme_color_override("font_color")
```

Llamar desde `game.gd` en `_refresh_all`:

```gdscript
func _refresh_all() -> void:
	human_area.refresh(game_manager.players[0])
	bot_area.refresh(game_manager.players[1])
	var is_human_turn := game_manager.current_player().is_human
	human_area.set_active_turn(is_human_turn)
	bot_area.set_active_turn(not is_human_turn)
	# ... resto sin cambios
```

### Cómo probar la Fase 13

1. Correr el juego
2. **Prueba de fondo y layout:**
   - Resultado: fondo verde intenso, zona del bot arriba, escaleras al centro,
     zona del jugador abajo, HUD azul oscuro con borde verde en el pie de pantalla
3. **Prueba de secciones:**
   - Resultado: etiquetas "POZO", "TABLERO", "MANO" en gris suave delimitan las zonas
   - El conteo del pozo aparece en dorado a la derecha del nombre ("♦ 15")
4. **Prueba de profundidad de tablero:**
   - Terminar un turno (coloca una carta en el tablero). Luego terminar otro turno
     colocando en la misma columna
   - Resultado: debajo de la carta del tablero aparece "×2"
5. **Prueba de log:**
   - Jugar 4 cartas seguidas
   - Resultado: el HUD muestra las últimas 3 jugadas separadas por " | "
6. **Prueba de indicador de turno:**
   - Resultado: el nombre del jugador cuyo turno es aparece en dorado;
     el oponente en blanco/gris
7. **Error común:** Si los paths de `@onready` dan error después de reestructurar
   `player_area.tscn`, verificar que los nombres de nodo en la escena coincidan
   exactamente con los strings en el script.

---

## Orden de implementación recomendado

```
8  → Tema base             sin tocar código (editor + project.godot)
9  → CardView rediseño     card.tscn + card_view.gd
10 → Estados interactivos  card_view.gd + ladder_view.gd + game.gd
11 → LadderView rediseño   ladder.tscn + ladder_view.gd
12 → Diálogo de comodín    joker_dialog.tscn + joker_dialog.gd + game.gd
13 → Layout y legibilidad  player_area.tscn + player_area_view.gd + hud.tscn + hud_view.gd
```

Las fases 9 y 10 comparten cambios en `card_view.gd` — conviene implementarlas juntas.
Las fases 11 y 10 comparten cambios en `ladder_view.gd` — ídem.

El test runner (Fases 1–7) no se ve afectado: trabaja a nivel de lógica pura, sin UI.
Correrlo después de cada fase confirma que no se rompió nada en la capa de reglas.

---

## Archivos a crear / modificar

| Archivo | Acción |
|---------|--------|
| `res://temas/juego.tres` | **Crear** en el editor |
| `project.godot` | Modificar: color de fondo global |
| `escenas/ui/card/card.tscn` | Modificar: nueva estructura de nodos |
| `scripts/ui/card_view.gd` | Modificar: hover, selección, StyleBoxes |
| `escenas/ui/ladder/ladder.tscn` | Modificar: mini-carta interior, nuevo layout |
| `scripts/ui/ladder_view.gd` | Modificar: estilos, `set_valid_target`, `_val_display` |
| `escenas/ui/player_area/player_area.tscn` | Modificar: separadores, labels de zona |
| `scripts/ui/player_area_view.gd` | Modificar: nuevos paths, profundidad, `get_card_view`, `set_active_turn` |
| `escenas/ui/hud/hud.tscn` | Modificar: fondo oscuro, log label |
| `scripts/ui/hud_view.gd` | Modificar: log funcional, nuevos paths |
| `escenas/ui/joker_dialog/joker_dialog.tscn` | **Crear** |
| `scripts/ui/joker_dialog.gd` | **Crear** |
| `scripts/ui/game.gd` | Modificar: selection tracking, highlights, dimming, async joker, log, set_active_turn |

---

## Checklist de verificación final

- [ ] **Fase 8:**  Fondo verde de mesa; botón "Terminar turno" con estilo verde/dorado
- [ ] **Fase 9:**  Cartas con fondo marfil y borde; palo rojo/negro; dorso azul marino
- [ ] **Fase 10:** Carta seleccionada → borde dorado; escaleras válidas → fondo verde menta; bot → área atenuada
- [ ] **Fase 11:** Escaleras como mini-cartas; slot vacío vs. activo visualmente distintos; deck como panel azul con conteo
- [ ] **Fase 12:** Comodín → diálogo de 13 botones → carta colocada con valor elegido
- [ ] **Fase 13:** Zonas etiquetadas; profundidad "×N" en tablero; HUD con log; nombre activo en dorado
