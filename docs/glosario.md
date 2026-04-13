# El Pozo — Glosario

Términos del dominio del juego y su equivalente en código.

---

## Términos del juego

### Pozo personal (`well`)
Las 15 cartas iniciales de cada jugador, apiladas boca abajo. Solo la carta superior está visible. El objetivo del juego es vaciarlo. En código: `Player.well: Array[Card]`.

### Carta superior del pozo (`well_top`)
La última carta del pozo, la única visible y jugable en cada momento. En código: `Player.well_top() -> Card`.

### Mano (`hand`)
Las cartas privadas de un jugador, máximo 5. Solo ese jugador puede verlas. En código: `Player.hand: Array[Card]`.

### Tablero personal (`board`)
Zona pública de cada jugador. Hasta 5 columnas de cartas apiladas. Solo la carta superior de cada columna está disponible para jugar. En código: `Player.board: Array` (array de columnas; cada columna es `Array[Card]`).

### Columna (`column` / `col`)
Una de las hasta 5 pilas del tablero personal. Las cartas se van apilando. Solo se accede a la última (`back()`). En código: `Player.board[col_index]: Array[Card]`.

### Carta superior del tablero (`board_top`)
La carta accesible de una columna del tablero personal. En código: `Player.board_tops() -> Array[Card]`.

### Escalera (`ladder`)
Secuencia ascendente de cartas centrales compartidas por todos: As → 2 → ... → K. Cuando llega a K se descarta y el slot queda libre para un nuevo As. En código: `LadderManager.ladders: Array` (cada escalera es `Array[Card]`).

### Slot de escalera (`ladder slot`)
Un espacio para una escalera. Empieza vacío (necesita un As para comenzar). En código: un elemento de `LadderManager.ladders`.

### Mazo central (`deck`)
La pila de cartas boca abajo de donde se roba. Cuando se agota, se reconstruye con los descartes. En código: `Deck`.

### Descarte (`discard_pile`)
Las cartas de escaleras completadas (llegaron a K). Se usan para reconstruir el mazo cuando se agota. En código: `LadderManager.discard_pile: Array[Card]`.

### Comodín (`joker`)
Carta especial que puede representar cualquier valor (As a K). Su valor se define al jugarlo y es válido solo en ese contexto. En código: `Card.is_joker: bool`, `Card.Suit.JOKER`.

### As (`ace`)
Carta de valor 1. Obligatorio jugarlo al inicio del turno si está en mano. Inicia una escalera nueva o continúa la primera posición disponible. En código: `card.value == 1`.

### Reposición (`refill`)
Robar cartas del mazo hasta completar 5 en mano. Ocurre al inicio del turno y también durante el turno si la mano se vacía. En código: `GameManager._refill_hand()`.

### As obligatorio (`mandatory ace`)
Regla que fuerza al jugador a jugar todos los ases de su mano al inicio del turno antes de cualquier otra acción. En código: `GameManager._play_mandatory_aces()`.

### Fin de turno (`end turn`)
Acción de bajar una carta de la mano al tablero personal. Termina el turno del jugador. Siempre obligatorio, incluso si no se jugó nada en las escaleras. En código: `GameManager.try_end_turn()`.

---

## Términos de código

### `Card`
Recurso que representa una carta. Tiene `suit` (palo), `value` (1–13 o 0 para comodín) e `is_joker`. Archivo: `scripts/data/card.gd`.

### `Card.Suit`
Enum con los palos: `SPADES` (♠), `HEARTS` (♥), `DIAMONDS` (♦), `CLUBS` (♣), `JOKER` (★).

### `Deck`
Clase que maneja el mazo central. Construye 162 cartas (3 mazos × 54), permite robar (`draw`) y añadir cartas (`add_cards`). Archivo: `scripts/data/deck.gd`.

### `Player`
Clase que representa el estado de un jugador: pozo, mano, tablero. Contiene las constantes `WELL_SIZE = 15`, `MAX_HAND_SIZE = 5`, `MAX_BOARD_COLUMNS = 5`. Archivo: `scripts/data/player.gd`.

### `LadderManager`
Gestiona todas las escaleras centrales y el descarte. Valida si una carta puede jugarse (`can_play_on`) y detecta escaleras completas. Archivo: `scripts/logic/ladder_manager.gd`.

### `GameManager`
Orquestador principal de la partida: setup, turnos, validaciones, señales de estado. Archivo: `scripts/logic/game_manager.gd`.

### `CardSource`
Enum en `GameManager` que indica de dónde viene una carta al jugarla: `HAND`, `WELL`, o `BOARD`.

### `BotPlayer`
Lógica de IA greedy. Juega priorizando: pozo personal > tablero personal > mano. Archivo: `scripts/ai/bot_player.gd`.

### `CardView`
Nodo UI que representa visualmente una carta. Emite `card_clicked`. Archivo: `scripts/ui/card_view.gd`.

### `LadderView`
Nodo UI que representa una escalera central. Muestra la carta superior y el valor que necesita. Emite `ladder_clicked`. Archivo: `scripts/ui/ladder_view.gd`.

### `PlayerAreaView`
Nodo UI con el área completa de un jugador: pozo, tablero y mano. Emite `card_selected`. Archivo: `scripts/ui/player_area_view.gd`.

### `HUDView`
Nodo UI con el log de acciones, estado del turno y botón de fin de turno. Emite `end_turn_requested`. Archivo: `scripts/ui/hud_view.gd`.

---

## Constantes clave

| Constante | Valor | Significado |
|---|---|---|
| `Player.WELL_SIZE` | 15 | Cartas iniciales en el pozo |
| `Player.MAX_HAND_SIZE` | 5 | Máximo de cartas en mano |
| `Player.MAX_BOARD_COLUMNS` | 5 | Columnas máximas en el tablero personal |
| `GameManager.INITIAL_LADDERS` | 4 | Slots de escalera al inicio |
| Deck con 3 mazos | 162 | 3 × (52 cartas + 2 comodines) |
