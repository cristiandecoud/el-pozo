# El Pozo — UX e interactividad (Fases 14–17)

Continuación de `implementacion_visual.md`. Las fases 8–13 (tema, cartas, estados
interactivos, escaleras, comodín automático, HUD) están completas. Este documento
cubre mejoras de jugabilidad e interacción.

---

## Estado actual (resumen)

| Componente | Estado actual |
|---|---|
| Terminar turno | Siempre baja a una nueva columna del board |
| Columnas del board | Solo se ve la carta del tope con indicador ×N |
| Mano del rival | Cartas boca abajo a tamaño completo en el área superior |
| Interacción | Solo click — no hay arrastre |

---

## Prioridad y dependencias

```
14 → Selección de columna al terminar turno   (gameplay correctness, sin deps)
15 → Mano del rival compacta                  (visual, sin deps)
16 → Columnas del board visibles              (visual, sin deps)
17 → Drag & Drop                              (UX avanzado, aprovecha 14 y 16)
```

Las fases 14 y 15 son independientes y simples — implementar primero.
La fase 16 cambia la estructura del board — hacerla antes del drag & drop.
La fase 17 es la más compleja y se implementa al final.

---

## Fase 14 — Selección de columna del board al terminar turno

**Objetivo:** Al presionar "Terminar turno", el jugador elige primero qué carta de
su mano bajar, y luego en qué columna del board colocarla — ya sea una existente o
una nueva. Actualmente siempre se crea una nueva columna.

### Problema actual

En `game.gd`, el flujo de fin de turno hardcodea el índice de columna:

```gdscript
# Siempre nueva columna:
var col := game_manager.current_player().board.size()
_do_end_turn(index, col)
```

### Diseño de la solución

Dividir el estado `AWAITING_BOARD_COL` en dos fases:
- `AWAITING_BOARD_CARD` — el jugador elige qué carta de la mano bajar
- `AWAITING_BOARD_DEST` — el jugador elige en qué columna colocarla

```gdscript
enum InteractionState {
    IDLE,
    CARD_SELECTED,
    AWAITING_BOARD_CARD,   # antes: AWAITING_BOARD_COL
    AWAITING_BOARD_DEST,   # nuevo
}
```

Nueva variable de estado:

```gdscript
var _end_turn_hand_index: int = -1
```

### 14.1 — Actualizar `game.gd`

**`_on_end_turn_pressed`:** cambia el estado al nuevo nombre.

```gdscript
func _on_end_turn_pressed() -> void:
    if game_manager.current_player().hand.is_empty():
        hud.set_status("No hay cartas en mano para bajar.")
        return
    state = InteractionState.AWAITING_BOARD_CARD
    hud.set_status("Elegí una carta de tu mano para bajar al board.")
```

**`_on_human_card_selected`:** bifurca según el estado actual.

```gdscript
func _on_human_card_selected(source: GameManager.CardSource,
                              index: int, card: Card) -> void:
    if not game_manager.current_player().is_human:
        return

    # Paso 1: elegir carta de la mano
    if state == InteractionState.AWAITING_BOARD_CARD:
        if source != GameManager.CardSource.HAND:
            return
        _end_turn_hand_index = index
        state = InteractionState.AWAITING_BOARD_DEST
        _highlight_board_destinations()
        hud.set_status("Ahora elegí dónde colocarla: columna existente o nueva.")
        return

    # Paso 2: elegir columna destino
    if state == InteractionState.AWAITING_BOARD_DEST:
        if source == GameManager.CardSource.BOARD:
            # Colocar en columna existente
            _clear_board_dest_highlights()
            _do_end_turn(_end_turn_hand_index, index)
        return

    # Flujo normal: seleccionar carta para jugar en escalera
    _clear_selection()
    selected_source = source
    selected_index = index
    selected_card = card
    state = InteractionState.CARD_SELECTED
    _selected_card_view = human_area.get_card_view(source, index)
    if _selected_card_view != null:
        _selected_card_view.set_selected(true)
    _highlight_valid_ladders(card)
    hud.set_status("Elegí una escalera para jugar " + card.label())
```

**Nuevas funciones helper:**

```gdscript
# Resalta las columnas del board como destinos válidos para fin de turno.
func _highlight_board_destinations() -> void:
    human_area.show_board_destinations(true)

func _clear_board_dest_highlights() -> void:
    human_area.show_board_destinations(false)
```

**"Nueva columna":** PlayerAreaView emite `board_dest_selected(col_index)` cuando
se hace click en el slot de nueva columna. El índice para nueva columna es
`player.board.size()`. game.gd escucha la señal:

```gdscript
# En _ready(), al conectar human_area:
human_area.board_dest_selected.connect(_on_board_dest_selected)

func _on_board_dest_selected(col_index: int) -> void:
    if state != InteractionState.AWAITING_BOARD_DEST:
        return
    _clear_board_dest_highlights()
    _do_end_turn(_end_turn_hand_index, col_index)
    state = InteractionState.IDLE
```

### 14.2 — Actualizar `player_area_view.gd`

**Nueva señal:**

```gdscript
signal board_dest_selected(col_index: int)
```

**Slot de nueva columna:** agregar a `board_container` un último elemento visual
que indica "nueva columna" (un `PanelContainer` con "+" y borde punteado). Se muestra
siempre pero se activa solo al llamar `show_board_destinations(true)`.

```gdscript
var _new_col_slot: Button = null

func _add_new_col_slot(col_index: int) -> void:
    _new_col_slot = Button.new()
    _new_col_slot.text = "+"
    _new_col_slot.custom_minimum_size = Vector2(60, 180)
    _new_col_slot.pressed.connect(func(): board_dest_selected.emit(col_index))
    board_container.add_child(_new_col_slot)

func show_board_destinations(active: bool) -> void:
    if active:
        # Agregar slot de nueva columna al final
        var next_col := 0
        for i in range(_current_player_board.size()):
            if not _current_player_board[i].is_empty():
                next_col = i + 1
        _add_new_col_slot(next_col)
        # Modular cada columna existente para indicar que es clickeable
        for child in board_container.get_children():
            child.modulate = Color(0.8, 1.0, 0.85, 1.0)
    else:
        # Quitar slot y limpiar highlights
        if _new_col_slot != null:
            _new_col_slot.queue_free()
            _new_col_slot = null
        for child in board_container.get_children():
            child.modulate = Color(1, 1, 1, 1)
```

**Nota:** `_current_player_board` requiere guardar la referencia al board del jugador
actual. Agregar en `refresh()`: `_current_player_board = player.board`.

**Click en columna existente:** cuando está en modo `AWAITING_BOARD_DEST`, el click
en una carta del board debe emitir `board_dest_selected` en lugar de `card_selected`.
Se puede lograr con un booleano `_board_dest_mode` en PlayerAreaView:

```gdscript
var _board_dest_mode: bool = false

func show_board_destinations(active: bool) -> void:
    _board_dest_mode = active
    # ... resto del código

# En la lambda de click de carta del board:
cv.card_clicked.connect(func(_v):
    if _board_dest_mode:
        board_dest_selected.emit(idx)
    else:
        card_selected.emit(GameManager.CardSource.BOARD, idx, col.back())
)
```

### Verificación

- Presionar "Terminar turno" → mensaje pide elegir carta de mano
- Click en carta de mano → columnas del board se resaltan en verde, aparece slot "+"
- Click en columna existente → carta se apila en esa columna, turno finaliza
- Click en "+" → carta va a nueva columna, turno finaliza
- Click fuera (escalera, pozo) durante AWAITING_BOARD_DEST → se ignora

---

## Fase 15 — Mano del rival compacta

**Objetivo:** Las cartas boca abajo del bot ocupan demasiado espacio en el área
superior y no aportan información útil. Reemplazarlas por un indicador compacto.

### Diseño

En lugar de instanciar cartas a tamaño completo, mostrar una sola carta boca abajo
pequeña apilada con un badge de conteo, o directamente solo un contador de cartas.

La opción más limpia: una sola carta boca abajo estilizada (como decoración) con un
Label encima que dice "N cartas". Esto ocupa el ancho de una sola carta.

```
VBoxContainer "HandZone" (para el bot)
├── Label "HandTitle"   → "MANO"
└── Control "HandCompact"  (ancho de una carta, ~180px)
    ├── CardView (face_down=true, mouse_filter=IGNORE)  → decoración
    └── Label "HandCount"  (centrado sobre la carta)    → "8"
```

### 15.1 — Actualizar `player_area_view.gd`

Reemplazar el loop de cartas boca abajo por el display compacto:

```gdscript
# Hand: visible si es humano, compacta si es bot
if show_hand:
    _rebuild_cards(hand_container, player.hand, GameManager.CardSource.HAND)
else:
    for child in hand_container.get_children():
        child.queue_free()

    # Una carta decorativa + contador
    var slot := Control.new()
    slot.custom_minimum_size = Vector2(90, 130)  # mitad del tamaño normal

    var cv := CardScene.instantiate()
    cv.face_down = true
    cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    slot.add_child(cv)

    var count_lbl := Label.new()
    count_lbl.text = str(player.hand.size())
    count_lbl.add_theme_font_size_override("font_size", 28)
    count_lbl.add_theme_color_override("font_color", Color("#F0EDE0"))
    count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    count_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    slot.add_child(count_lbl)

    hand_container.add_child(slot)
```

**Nota:** La carta decorativa es de 90×130 (mitad del tamaño de juego 180×260).
Esto funciona porque el slot es un `Control` con tamaño fijo, no un Container que
fuerza el tamaño de sus hijos.

### 15.2 — Ajustar el área del bot en `game.tscn`

El `OpponentRow` en game.tscn tiene `size_flags_vertical = 3` (EXPAND_FILL), lo
que le da la misma altura que el área del jugador. Para una mano compacta, el bot
no necesita tanto espacio vertical. Cambiar a `size_flags_vertical = 0` (fill sin
expand) para que tome solo su tamaño mínimo.

En `game.gd`, al configurar `bot_area`:

```gdscript
bot_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
```

### Verificación

- Área superior del bot: muestra nombre, well, board y una carta boca abajo con el
  número de cartas en mano
- La carta compacta ocupa ~90×130 px en lugar de 180×260
- El área superior es notablemente más pequeña, liberando espacio para el juego

---

## Fase 16 — Columnas del board completamente visibles

**Objetivo:** Las cartas apiladas en una columna deben verse todas, en abanico
vertical. Solo la carta del tope es interactiva.

### Diseño

Cada columna del board se renderiza como un `Control` de ancho fijo y alto variable.
Las cartas se posicionan con un offset vertical fijo entre ellas. La última carta
queda encima (z_index mayor o simplemente declarada después).

```
Control "BoardColumn"  (custom_minimum_size: carta_w × (carta_h + offset × (N-1)))
├── CardView [0]  position(0, 0),          mouse_filter=IGNORE
├── CardView [1]  position(0, OFFSET),     mouse_filter=IGNORE
├── CardView [2]  position(0, OFFSET×2),   mouse_filter=IGNORE
└── CardView [N-1] position(0, OFFSET×(N-1)), mouse_filter=STOP  ← clickeable
```

`OFFSET = 35` px — suficiente para ver el valor y palo de las cartas inferiores.

### 16.1 — Crear `BoardColumnView` en `player_area_view.gd`

Una función que construye el Control de columna:

```gdscript
const CARD_W := 180
const CARD_H := 260
const STACK_OFFSET := 35

func _build_board_column(col: Array[Card], col_idx: int) -> Control:
    var column_ctrl := Control.new()
    var stack_h := CARD_H + STACK_OFFSET * (col.size() - 1)
    column_ctrl.custom_minimum_size = Vector2(CARD_W, stack_h)

    for i in range(col.size()):
        var cv: CardView = CardScene.instantiate()
        cv.card_data = col[i]
        cv.position = Vector2(0, STACK_OFFSET * i)
        cv.custom_minimum_size = Vector2(CARD_W, CARD_H)

        if i < col.size() - 1:
            # Cartas inferiores: no interactivas
            cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
        else:
            # Carta del tope: clickeable
            var idx := col_idx
            cv.card_clicked.connect(
                func(_v): card_selected.emit(GameManager.CardSource.BOARD, idx, col[idx]))

        column_ctrl.add_child(cv)

    return column_ctrl
```

**Uso en `refresh()`**, reemplazando el código actual del board:

```gdscript
# Board: abanico de cartas por columna
for child in board_container.get_children():
    child.queue_free()
var col_view_idx := 0
for i in range(player.board.size()):
    var col: Array = player.board[i]
    if col.is_empty():
        continue
    var column_ctrl := _build_board_column(col, col_view_idx)
    board_container.add_child(column_ctrl)
    col_view_idx += 1
```

**Actualizar `get_card_view` para BOARD:**

```gdscript
GameManager.CardSource.BOARD:
    var children := board_container.get_children()
    if index < children.size():
        var col_ctrl := children[index]
        # La carta del tope es el último hijo del Control de columna
        var n := col_ctrl.get_child_count()
        if n > 0:
            return col_ctrl.get_child(n - 1) as CardView
```

### 16.2 — Altura del BoardZone

Con columnas visibles, el área del board puede crecer verticalmente si hay muchas
cartas apiladas. Para evitar que el layout explote, limitar la altura del `BoardZone`
con `clip_contents = true` en el Control de columna, o con un scroll container.

Opción simple (sin scroll): el `board_container` (HBoxContainer) tiene
`clip_contents = true`. Las columnas muestran las cartas hasta el límite de espacio
disponible.

Opción completa (con scroll): wrappear el `board_container` en un `ScrollContainer`
horizontal.

Para el MVP, la opción simple es suficiente — las columnas raramente pasan de 5–6
cartas en una partida normal.

### Verificación

- Columna con 1 carta: igual que antes
- Columna con 3 cartas: se ven las 3 en abanico, la del tope interactiva
- Click en carta inferior: no hace nada (MOUSE_FILTER_IGNORE)
- Click en carta del tope: selecciona la carta correctamente
- La profundidad de la pila es visible sin necesitar el indicador ×N (que se puede
  eliminar en esta fase)

---

## Fase 17 — Drag & Drop de cartas

**Objetivo:** El jugador puede arrastrar cartas en lugar de hacer click doble
(carta → destino). El arrastre es una alternativa al click, no un reemplazo — ambas
modalidades coexisten.

### Diseño general

El drag & drop se implementa manualmente (sin usar la API built-in de Godot que es
más limitada para este uso). El flujo:

1. El jugador presiona el botón del mouse sobre una carta
2. Si arrastra más de un umbral (8px), se inicia el drag
3. Una copia "fantasma" de la carta flota bajo el cursor
4. Los destinos válidos se resaltan (igual que en el click)
5. Al soltar sobre un destino válido: se ejecuta la acción
6. Al soltar en otro lugar: se cancela, la carta vuelve a su posición

### 17.1 — Detección de drag en `card_view.gd`

Agregar detección de drag start al script existente:

```gdscript
signal card_drag_started(card_view: CardView)

var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
const DRAG_THRESHOLD := 8.0

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _press_position = event.global_position
                _dragging = false
            else:
                if not _dragging:
                    # Click normal — comportamiento existente
                    card_clicked.emit(self)
                _dragging = false

    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if not _dragging:
            if event.global_position.distance_to(_press_position) > DRAG_THRESHOLD:
                _dragging = true
                card_drag_started.emit(self)
```

**Nota:** Al emitir `card_drag_started`, `card_clicked` ya no se emite en ese ciclo
(la condición `not _dragging` lo evita). Si el usuario presiona y suelta sin mover,
sigue siendo un click normal.

### 17.2 — Orquestación del drag en `game.gd`

Variables de estado del drag:

```gdscript
# Overlay de drag
var _drag_ghost: CardView = null
var _drag_source_view: CardView = null
```

**Conectar la señal al instanciar CardViews:** Las señales `card_drag_started`
deben llegar a `game.gd`. El lugar más natural es dentro de `PlayerAreaView`, que
emite su propia señal `card_drag_started(source, index, card)`. O game.gd puede
escuchar la señal directamente de los CardViews que crea.

Opción más limpia: PlayerAreaView propaga la señal:

```gdscript
# En player_area_view.gd
signal card_drag_started(source: GameManager.CardSource, index: int, card: Card)

# Al crear cada CardView, conectar también card_drag_started:
cv.card_drag_started.connect(
    func(cv_ref): card_drag_started.emit(source, idx, cards[idx]))
```

**En `game.gd`, conectar en `_ready()`:**

```gdscript
human_area.card_drag_started.connect(_on_card_drag_started)
```

**Inicio del drag:**

```gdscript
func _on_card_drag_started(source: GameManager.CardSource,
                            index: int, card: Card) -> void:
    if not game_manager.current_player().is_human:
        return
    # Mismo setup que _on_human_card_selected para selección
    _clear_selection()
    selected_source = source
    selected_index = index
    selected_card = card
    state = InteractionState.CARD_SELECTED

    _drag_source_view = human_area.get_card_view(source, index)
    if _drag_source_view != null:
        _drag_source_view.modulate.a = 0.4  # semitransparente en origen

    # Crear fantasma
    _drag_ghost = CardScene.instantiate()
    _drag_ghost.card_data = card
    _drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _drag_ghost.custom_minimum_size = Vector2(180, 260)
    _drag_ghost.z_index = 100
    add_child(_drag_ghost)
    _drag_ghost.global_position = get_viewport().get_mouse_position() - Vector2(90, 130)

    _highlight_valid_ladders(card)
    set_process_input(true)
```

**Movimiento del fantasma:**

```gdscript
func _input(event: InputEvent) -> void:
    if _drag_ghost == null:
        return
    if event is InputEventMouseMotion:
        _drag_ghost.global_position = get_global_mouse_position() - Vector2(90, 130)
    elif event is InputEventMouseButton \
         and event.button_index == MOUSE_BUTTON_LEFT \
         and not event.pressed:
        _end_drag()

func _end_drag() -> void:
    set_process_input(false)
    if _drag_source_view != null:
        _drag_source_view.modulate.a = 1.0
        _drag_source_view = null
    if _drag_ghost != null:
        _drag_ghost.queue_free()
        _drag_ghost = null

    _try_drop_at_mouse()
    _clear_selection()
    _clear_ladder_highlights()
```

**Detección del destino al soltar:**

```gdscript
func _try_drop_at_mouse() -> void:
    var mouse_pos := get_global_mouse_position()

    # ¿El mouse está sobre alguna escalera?
    for child in ladders_container.get_children():
        var lv := child as LadderView
        if lv == null:
            continue
        if lv.get_global_rect().has_point(mouse_pos):
            _on_ladder_clicked(lv.ladder_index)
            return

    # Cancelado: sin acción
    state = InteractionState.IDLE
    hud.set_status("Arrastrá sobre una escalera para jugar.")
```

**Nota sobre `get_global_rect()`:** Devuelve el rect global de un Control. Funciona
para LadderView (VBoxContainer) porque cubre toda su área visual.

### 17.3 — Drag para fin de turno (Fase 14 + 17)

Si se implementó la Fase 14, el drag también puede usarse para bajar cartas al board:

- Arrastrar una carta de la mano sobre una columna del board durante fin de turno
- O arrastrar en cualquier momento y soltar sobre el board (Godot puede interpretar
  esto como "quiero terminar el turno y bajar aquí")

Para simplificar, el drag de fin de turno solo se activa si el jugador ya presionó
"Terminar turno" (estado `AWAITING_BOARD_CARD`):

```gdscript
func _try_drop_at_mouse() -> void:
    var mouse_pos := get_global_mouse_position()

    # Drop en escalera (estado CARD_SELECTED)
    if state == InteractionState.CARD_SELECTED:
        for child in ladders_container.get_children():
            var lv := child as LadderView
            if lv != null and lv.get_global_rect().has_point(mouse_pos):
                _on_ladder_clicked(lv.ladder_index)
                return

    # Drop en columna del board (estado AWAITING_BOARD_DEST)
    if state == InteractionState.AWAITING_BOARD_DEST:
        var col_idx := 0
        for child in human_area.board_container.get_children():
            if child.get_global_rect().has_point(mouse_pos):
                _on_board_dest_selected(col_idx)
                return
            col_idx += 1
        # Drop en área de board pero fuera de columnas → nueva columna
        if human_area.board_container.get_global_rect().has_point(mouse_pos):
            _on_board_dest_selected(game_manager.current_player().board.size())
            return

    state = InteractionState.IDLE
    hud.set_status("Arrastrá sobre un destino válido.")
```

### 17.4 — Cancelación del drag

Si el usuario presiona Escape durante el drag, cancelar:

```gdscript
func _input(event: InputEvent) -> void:
    if _drag_ghost == null:
        return
    # ... motion y release existentes ...
    elif event is InputEventKey and event.keycode == KEY_ESCAPE:
        _cancel_drag()

func _cancel_drag() -> void:
    set_process_input(false)
    if _drag_source_view != null:
        _drag_source_view.modulate.a = 1.0
        _drag_source_view = null
    if _drag_ghost != null:
        _drag_ghost.queue_free()
        _drag_ghost = null
    _clear_selection()
    _clear_ladder_highlights()
    state = InteractionState.IDLE
    hud.set_status("Tu turno.")
```

### Verificación

- Click normal sobre carta → comportamiento existente sin cambios
- Presionar y mover más de 8px → carta original semitransparente, fantasma sigue el mouse
- Arrastrar sobre escalera válida (resaltada en verde) → carta se juega al soltar
- Arrastrar sobre escalera inválida → se cancela, mensaje de error
- Arrastrar fuera de cualquier destino → se cancela sin acción
- Escape durante drag → cancela, carta vuelve a estado normal

---

## Archivos a crear/modificar

| Archivo | Fase | Acción |
|---------|------|--------|
| `scripts/ui/game.gd` | 14, 17 | Nuevo estado, drag logic, _try_drop_at_mouse |
| `scripts/ui/player_area_view.gd` | 14, 15, 16, 17 | board_dest_mode, compact hand, board column fan, card_drag_started |
| `scripts/ui/card_view.gd` | 17 | Detección de drag, señal card_drag_started |

No se crean escenas nuevas.

---

## Orden de implementación recomendado

```
15 → Mano rival compacta      (30 min — solo player_area_view.gd)
14 → Selección de columna     (1–2 h — game.gd + player_area_view.gd)
16 → Board en abanico         (1–2 h — player_area_view.gd)
17 → Drag & drop              (2–3 h — card_view.gd + game.gd)
```

Cada fase es verificable de forma independiente. El test runner (lógica pura) no
se ve afectado en ninguna de las fases.

---

## Checklist de verificación

- [ ] Fase 14: al terminar turno, aparece elección de columna; click en columna existente apila correctamente
- [ ] Fase 15: área del bot es notablemente más pequeña; muestra número de cartas en mano
- [ ] Fase 16: columnas con múltiples cartas muestran el abanico completo; solo la del tope es clickeable
- [ ] Fase 17: arrastre funciona como alternativa al click; click sigue funcionando igual que antes
