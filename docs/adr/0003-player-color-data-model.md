# ADR-0003: Player.color en el modelo de datos

## Estado

Aceptado

## Contexto

El juego necesita distinguir visualmente a cada jugador (humano y bots) tanto
en el tablero como en futuros widgets de rivales. El color elegido por el
jugador humano se captura en GameSetup y debe fluir hasta la lógica del juego y
la UI sin que cada capa tenga que buscarlo por separado.

## Decisión

Agregar `var color: Color = Color.WHITE` directamente en la clase `Player`
(modelo de datos puro). `GameManager.setup()` asigna el color del humano desde
la sesión y distribuye colores del pool `PLAYER_COLORS` a los bots.

```gdscript
# player.gd
var color: Color = Color.WHITE

# game_manager.gd
const PLAYER_COLORS: Array[Color] = [
    Color("#F5C518"),   # Dorado  — humano por defecto
    Color("#3B82F6"),   # Azul
    Color("#22C55E"),   # Verde
    Color("#EF4444"),   # Rojo
    Color("#A855F7"),   # Violeta
]

var color_pool := PLAYER_COLORS.duplicate()
color_pool.erase(player_color)          # evitar que un bot repita el color del humano
for i in range(bot_count):
    bot.color = color_pool[i % color_pool.size()]
```

## Opciones consideradas

### Opción A — Color en el modelo de datos `Player` (elegida)

- **Pro**: cualquier sistema que tenga acceso a un `Player` tiene acceso a su
  color sin dependencias adicionales.
- **Pro**: el modelo es autocontenido; la UI solo necesita leer `player.color`.
- **Pro**: simplifica los tests — el color viaja junto al jugador en toda la
  pipeline lógica.
- **Contra**: `Player` es un modelo de datos puro y `Color` es un tipo visual;
  mezcla leve de responsabilidades.

### Opción B — Color solo en la UI (nodos VisualPlayer / RivalAreaView)

Mantener `Player` sin color y resolver el mapeo jugador→color en la capa de
presentación.

- **Pro**: separación estricta entre lógica y presentación.
- **Contra**: cada widget de UI necesita mantener su propio mapeo
  `player_index → color`, generando duplicación.
- **Contra**: cuando la lógica emite señales (`turn_started`, `game_won`) con
  un `Player`, la UI no puede colorear el mensaje sin hacer una búsqueda extra.

### Opción C — Color en `SaveData.session`

Guardar solo el color del humano en sesión y derivar los colores de bots en
cada escena que los necesite.

- **Contra**: los bots no tienen un color estable entre escenas.
- **Contra**: duplica la lógica de asignación de colores en múltiples puntos.

## Consecuencias

### Positivas

- Las señales `turn_started(player)` y `game_won(player)` llevan el color
  implícitamente — la UI puede usarlo directamente.
- El pool `PLAYER_COLORS` en `GameManager` garantiza que ningún bot repite el
  color del humano.
- Fácil de extender: añadir un `avatar` o `icon` al modelo sigue el mismo
  patrón.

### Negativas

- `Color` es un tipo de Godot con dependencia del engine; dificulta exportar
  `Player` a un contexto puro de GDScript sin Godot (poco probable en este
  proyecto).
- El valor por defecto `Color.WHITE` puede ser confuso si un `Player` se
  construye sin asignar color explícitamente.

## Notas de implementación

- El color del humano se persiste entre pantallas via `SaveData.session["player_color"]`
  como string hex y se reconstruye con `SaveData.get_session_color()`.
- Los colores de bots no se persisten — se reasignan en cada `setup()`.

## Decisiones relacionadas

- ADR-0001: SaveData singleton (almacena el color elegido por el humano en sesión)
