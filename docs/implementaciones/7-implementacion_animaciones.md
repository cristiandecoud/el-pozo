# 7 — Animaciones y tracking de movimientos

## Objetivo

Hacer que cada movimiento de carta sea visible como animación física (vuelo de A a B), que los turnos del bot se ejecuten paso a paso con delays configurables, y dejar el sistema listo para multijugador mediante un modelo universal de eventos de movimiento.

## Problema de arquitectura actual

`BotPlayer.play()` ejecuta todos los movimientos en un loop síncrono. No hay forma de pausar entre ellos ni animarlos individualmente. La solución: separar *decisión* de *ejecución*, movimiento por movimiento.

---

## Fase 1 — `CardMoveEvent`: el lenguaje universal de movimientos

**Archivo nuevo:** `scripts/data/card_move_event.gd`

```gdscript
class_name CardMoveEvent
extends RefCounted

enum DestType { LADDER, BOARD }

var player_index: int
var source:       GameManager.CardSource  # HAND / WELL / BOARD
var source_index: int
var dest_type:    DestType
var dest_index:   int
var card:         Card
```

Este objeto describe cualquier movimiento — humano o bot. En el futuro, para multijugador, es lo que viaja por la red. No contiene lógica, solo datos.

---

## Fase 2 — Refactor de `BotPlayer`: decisión sin ejecución

Reemplazar el loop de `play()` por dos métodos que deciden pero **no modifican el estado del juego**:

```gdscript
# Devuelve el próximo movimiento válido según prioridad, o null si no hay más.
static func get_next_move(gm: GameManager) -> CardMoveEvent

# Devuelve el movimiento de fin de turno (carta → board), o null si mano vacía.
static func get_end_turn_move(gm: GameManager) -> CardMoveEvent
```

La lógica de prioridades (well → board tops → hand) queda idéntica. El cambio es que en vez de llamar `gm.try_play_card()`, construye y retorna un `CardMoveEvent`.

**Agregar a `GameManager`:**

```gdscript
# Aplica un move ya decidido, sin re-validar lógica de negocio.
func apply_move(event: CardMoveEvent) -> void
```

`apply_move` ejecuta lo mismo que `try_play_card` / `try_end_turn` pero recibe un evento ya planeado. También emite `card_move_happened`.

---

## Fase 3 — Infraestructura de animación

### `CardAnimator` — nuevo nodo hijo de `game.gd`

**Archivo nuevo:** `scripts/ui/card_animator.gd`

```gdscript
class_name CardAnimator
extends Node

# Vuela una ghost CardView de src_pos a dst_pos. Awaitable.
func animate_move(card: Card, src_pos: Vector2, dst_pos: Vector2,
                  duration: float) -> void
```

Internamente: instancia un `CardView`, lo posiciona en `src_pos` con `z_index` alto, hace tween de posición hasta `dst_pos` con easing, luego `queue_free()`.

### Nuevo método en `PlayerAreaView`

```gdscript
# Posición global del centro de una carta (origen de la animación).
func get_card_global_pos(source: GameManager.CardSource, index: int) -> Vector2
```

Usa la lógica existente de `get_card_view()` para encontrar el nodo y devolver su `global_position`.

### Destino en `LadderView`

`LadderView` ya expone `get_global_rect()`. El destino de la animación es el centro de esa rect.

---

## Fase 4 — `TurnController`: ejecución paso a paso (async)

`_run_bot_turn()` pasa de "esperar una sola vez y ejecutar todo" a un loop awaitable.

**Señales nuevas en `TurnController`:**

```gdscript
signal move_about_to_play(event: CardMoveEvent)
signal animation_finished
```

**Pseudocódigo del nuevo loop:**

```
bot_thinking_started.emit()
highlight jugador activo

loop:
    move = BotPlayer.get_next_move(gm)
    si no hay: break

    move_about_to_play.emit(move)     # game.gd arranca animación
    await animation_finished          # game.gd emite cuando termina el tween
    gm.apply_move(move)
    partial_refresh(move)             # refrescar solo zonas afectadas
    await delay(bot_move_delay)

end_move = BotPlayer.get_end_turn_move(gm)
si end_move != null:
    status_updated.emit("Bot X finaliza turno...")
    move_about_to_play.emit(end_move)
    await animation_finished
    gm.apply_move(end_move)           # internamente llama try_end_turn

bot_thinking_ended.emit()
```

`partial_refresh(move)` actualiza solo las vistas del jugador afectado y la escalera de destino, sin redibujar todo.

---

## Fase 5 — Highlighting del jugador activo y fin de turno

- **Jugador activo:** `set_active_turn(true)` ya existe en `PlayerAreaView`. Mantenerlo activo durante toda la ejecución del bot (hoy se pierde al hacer `_refresh_all()`).
- **Pre-vuelo:** antes de animar el vuelo, hacer un breve scale-up (0.15s) sobre la carta de origen para indicar que va a moverse.
- **Fin de turno:** cuando el bot coloca carta en el board, el HUD muestra *"Bot X finaliza turno"* y la zona del board del rival se resalta brevemente (modulate verde suave).

---

## Fase 6 — Settings

Agregar dos controles en `settings_screen.tscn` (misma sección de juego):

| Setting key            | Descripción                          | Rango       | Default |
|------------------------|--------------------------------------|-------------|---------|
| `bot_move_delay`       | Pausa entre cada movimiento del bot  | 0.1 – 1.5s  | 0.5s    |
| `move_animation_duration` | Duración del vuelo de la carta    | 0.1 – 1.0s  | 0.4s    |

El `bot_turn_delay` existente se reemplaza por `bot_move_delay` (semántica más precisa).

Agregar a `save_data.gd`:
```gdscript
"bot_move_delay":          0.5,
"move_animation_duration": 0.4,
```

---

## Tracking para multijugador (queda listo, no se usa aún)

`GameManager` agrega:
```gdscript
signal card_move_happened(event: CardMoveEvent)
```

Emitido dentro de `apply_move()` y también para los movimientos del humano (`try_play_card`, `try_end_turn`). En el futuro este signal es lo que el servidor/cliente recibe y retransmite.

---

## Orden de implementación

| # | Tarea                                                      | Estimación |
|---|------------------------------------------------------------|------------|
| 1 | `CardMoveEvent` (solo data, sin lógica)                    | 15 min     |
| 2 | `GameManager.apply_move()` + signal `card_move_happened`   | 30 min     |
| 3 | Refactor `BotPlayer` a intent-based                        | 45 min     |
| 4 | `CardAnimator` + `get_card_global_pos` en `PlayerAreaView` | 1h         |
| 5 | `TurnController` loop async                                | 45 min     |
| 6 | Highlighting + mensajes HUD                                | 30 min     |
| 7 | Settings (`bot_move_delay`, `move_animation_duration`)     | 20 min     |

**Total estimado:** ~4 horas
