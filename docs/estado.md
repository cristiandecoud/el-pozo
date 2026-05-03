# El Pozo — Estado del proyecto

> Última actualización: 2026-05-03

Este documento es la fuente de verdad sobre qué está hecho, qué está en progreso y qué falta. Los documentos de implementación en `/implementaciones/` describen *cómo* se hizo; este dice *qué está listo*.

---

## ✅ Implementado y estable

### Núcleo (datos + lógica)
- `Card`, `Deck`, `Player` — modelo de datos completo
- `LadderManager` — validación y gestión de escaleras
- `GameManager` — orquestador: setup, turnos, señales, `apply_move()`
- `CardMoveEvent` — descriptor universal de movimientos (listo para multijugador)
- `SaveData` (AutoLoad) — persistencia en `user://save_data.json`

### IA
- `BotPlayer` — greedy con prioridad well → board tops → hand
- Refactorizado a intent-based: `get_next_move()` / `get_end_turn_move()`
- 108 tests pasando (framework custom, sin GUT)

### UI — Pantallas
- Menú principal (`main_menu.tscn`)
- Configuración de partida (`game_setup.tscn`) — incluye selector de color
- Pantalla de configuración (`settings_screen.tscn`) — fuente, delays, tamaño de pozo
- Menú de pausa (`pause_menu.tscn`)
- Pantalla de fin de partida (`game_over.tscn`)

### UI — Partida
- `PlayerAreaView` — zona del jugador humano (pozo, tablero, mano)
- `LadderView` — escalera central con resaltado de objetivo válido
- `HUDView` — barra de acciones, log, botón de fin de turno
- `RivalAreaView` — vista compacta de rivales (nombre, pozo, mano, tops de tablero)
- `RivalBoardOverlay` — overlay con tablero completo al hacer click en rival
- Layout adaptativo para 2–5 jugadores (fila de rivales + zona central + zona humano)

### Animaciones y turnos
- `CardAnimator` — vuelo físico de carta (ghost CardView, tween, `animate_move()`)
- `TurnController` — loop async: animación → `apply_move()` → delay → siguiente
- Highlighting del jugador activo durante todo el turno del bot
- Settings: `bot_move_delay` (0.1–1.5s), `move_animation_duration` (0.1–1.0s)

### Infraestructura
- `CardPresentation` — ViewModel que separa los datos de renderizado de `Card` (face_up / face_down / empty)
- Señal `card_move_happened` en `GameManager` (tracking listo para multijugador)

---

## 🔄 En progreso (sin commitear)

### Visual polish — zonas del jugador (`player_area.tscn`, `player_area_view.gd`)
- `WellPanel`: PanelContainer con fondo `#1C1408` y borde ámbar `#C8851A`
- `BoardZone`: PanelContainer con fondo `#0D1520` y borde azul `#3A6A9A`
- Crea separación visual clara entre pozo y tablero

### Visual polish — escaleras (`ladder_view.gd`)
- Fondo oscuro propio (`#0A1E1E`, borde `#2A6060`) dibujado con `_draw()`
- Efecto de apilamiento: sombras detrás de la carta tapa cuando la escalera tiene 2+ cartas

---

## ❌ Pendiente / no prioritario ahora

| Item | Nota |
|------|------|
| Pantalla de estadísticas | `stats_screen.tscn`, `player_stat_card.tscn` y sus scripts no existen |
| Web export | Solo configuración del editor (Project → Export), sin código |

---

## 🔧 Backlog de pulido

Ideas de mejora identificadas pero no planificadas:

- **Drag & drop**: documentado en implementación 3 (Fase 17) pero no confirmado si está implementado
- **Fan view de columnas**: mostrar cartas apiladas con offset en el tablero personal
- **Efectos de sonido**: sliders en settings están presentes pero deshabilitados ("Próximamente")
- **Tema de cartas**: dropdown en settings solo tiene "Clásico" por ahora
- **Touch targets mobile**: revisar tamaño mínimo 44px en pantallas táctiles
- **Joker UI**: la derivación automática del valor del comodín está documentada; verificar flujo visual

---

## Referencia rápida de documentos

| Documento | Contenido |
|-----------|-----------|
| `reglas.md` | Reglas completas del juego |
| `glosario.md` | Términos del dominio y clases de código |
| `ui_design_brief.md` | Paleta de colores, layout y componentes UI |
| `plan_mvp.md` | Roadmap original de 6 semanas |
| `implementaciones/1-7` | Guías de implementación por fases |
| `adr/` | Decisiones arquitectónicas (SaveData, tests, Player.color) |
