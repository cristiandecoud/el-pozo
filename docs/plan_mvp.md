# El Pozo — Plan de trabajo MVP

## Objetivo
Tener un juego jugable en el browser (web export) con 1 humano vs 1 bot, cartas con texto placeholder, loop completo funcionando.

## Decisiones tomadas
- **Jugadores:** 1 humano vs 1 bot greedy (IA simple)
- **Visuals:** Cartas con texto (sin arte), foco en mecánica
- **Código:** Inglés (variables, funciones, comentarios)
- **Target:** Web (HTML5) → mobile después del MVP

---

## Roadmap por semanas

### Semana 1 — Datos y lógica del juego
**Fases 1 y 2**

Construir los modelos de datos y el motor de reglas. Sin UI, sin Godot editor. Todo se testea imprimiendo al Output panel.

Qué tenés al final:
- Mazo armado, mezclado, repartido correctamente
- Pozo personal de 15 cartas por jugador
- Escaleras que validan movimientos (As → K)
- Ases obligatorios funcionando
- Loop de turno completo (robar, jugar, terminar turno)
- Condición de victoria

### Semana 2 — Primera pantalla con cartas
**Fase 3 + card.tscn + ladder.tscn**

Armar el árbol de escenas en el editor de Godot. Las cartas se muestran como cajas con texto (ej: "A♠", "7♥").

Qué tenés al final:
- Tablero visible con 2 áreas de jugador y área central
- Cartas renderizando con valor y palo
- Escaleras mostrando su estado actual

### Semana 3 — Tablero completo visible
**Fase 4 — Scripts de UI**

Conectar los scripts de UI a los datos del juego. El tablero muestra el estado real del juego.

Qué tenés al final:
- Pozo de cada jugador con la carta visible
- Mano del humano visible, mano del bot tapada
- Tablero personal de cada jugador visible
- Escaleras actualizadas

### Semana 4 — Turno del humano jugable
**Fase 5 — game.gd**

El jugador humano puede hacer un turno completo interactuando con la UI.

Flujo de interacción:
1. Click en carta (mano / pozo / tablero personal)
2. Click en escalera → carta se juega
3. Click en "End Turn" → click en carta de mano → click en columna del tablero
4. Turno pasa al bot (que no hace nada todavía)

Qué tenés al final:
- El humano puede jugar un turno completo
- El estado del tablero se actualiza correctamente

### Semana 5 — Loop completo humano vs bot
**Fase 6 — Bot**

El bot juega automáticamente después de un delay de 0.5s. Estrategia greedy: prioriza vaciar su propio pozo.

Qué tenés al final:
- Partida completa jugable de principio a fin
- El bot toma decisiones razonables
- La pantalla de victoria aparece cuando alguien gana

### Semana 6 — Web export + bugs
**Fase 7 — Export**

Configurar el export a HTML5 y testear en el browser. Sin cambios de código.

Qué tenés al final:
- Juego corriendo en Chrome/Firefox via `localhost:8080`
- MVP completo

---

## Estructura de archivos final

```
el-pozo/
├── docs/
│   ├── reglas.md
│   ├── plan_mvp.md          ← este archivo
│   └── implementacion.md    ← guía técnica detallada
├── escenas/
│   ├── game/game.tscn
│   ├── ui/
│   │   ├── card/card.tscn
│   │   ├── ladder/ladder.tscn
│   │   ├── player_area/player_area.tscn
│   │   └── hud/hud.tscn
│   └── menu/menu.tscn
└── scripts/
    ├── data/
    │   ├── card.gd
    │   ├── deck.gd
    │   └── player.gd
    ├── logic/
    │   ├── game_manager.gd
    │   └── ladder_manager.gd
    ├── ui/
    │   ├── card_view.gd
    │   ├── ladder_view.gd
    │   ├── player_area_view.gd
    │   └── hud_view.gd
    └── ai/
        └── bot_player.gd
```

---

## Analogías Godot ↔ Web (para orientarte)

| Godot | Web |
|---|---|
| Scene (.tscn) | Componente (HTML + CSS + JS) |
| Node | Elemento del DOM |
| Script (.gd) | Clase JS attached al elemento |
| `_ready()` | `connectedCallback` / `componentDidMount` |
| `signal` | CustomEvent / EventEmitter |
| `RefCounted` | Objeto JS (garbage collected automático) |
| `Node` | Elemento DOM (hay que `queue_free()` al borrar) |
| `@onready var x = $NodoHijo` | `querySelector` en `connectedCallback` |

**Importante:** No vas a usar `_process()`. Este juego es event-driven, no frame-driven.

---

## Gotchas para un dev web

1. **Null safety:** Siempre `array.is_empty()` antes de `array.back()`. GDScript no tira excepciones — retorna null silenciosamente.
2. **Instanciar escenas:** `preload("res://path.tscn").instantiate()` + `add_child(instancia)` = import + new + appendChild
3. **`@onready`:** Se evalúa después de `_ready()`. Nunca acceder desde `_init()`.
4. **Signals vs callbacks:** Preferir signals entre nodos hermanos. `signal.connect(callable)` = `addEventListener`.
5. **Borrar nodos:** Usar `node.queue_free()`, nunca simplemente `= null`.
