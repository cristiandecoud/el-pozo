# ADR-0001: SaveData como autoload singleton

## Estado

Aceptado

## Contexto

El juego necesita compartir datos entre escenas que no tienen relación
padre-hijo directa:

- **GameSetup** captura nombre del jugador, color y cantidad de bots.
- **Game** necesita esos valores para inicializar `GameManager`.
- **StatsScreen** necesita el historial de partidas del jugador.
- **SettingsScreen** necesita leer y escribir preferencias (tamaño de fuente,
  velocidad de animación, tamaño del pozo, delay de bots).

Además, parte de esos datos debe persistir entre sesiones (stats, settings) y
parte solo dura lo que dura la partida en curso (player_color, bot_count).

## Decisión

Registrar `SaveData` como **autoload singleton** en `project.godot`, exponiéndolo
globalmente a todas las escenas. El nodo maneja tres responsabilidades:

1. **`settings`** — preferencias del usuario, guardadas en `user://save_data.json`.
2. **`players`** — estadísticas por nombre de jugador, guardadas en el mismo archivo.
3. **`session`** — datos transitorios de la partida actual, nunca escritos a disco.

## Opciones consideradas

### Opción A — Autoload singleton (elegida)

- **Pro**: acceso directo desde cualquier escena sin referencias explícitas.
- **Pro**: separa claramente datos persistentes (`settings`, `players`) de
  transitorios (`session`).
- **Pro**: un único punto de lectura/escritura a disco; fácil de mockear en tests.
- **Contra**: estado global — puede dificultar el testeo unitario si se abusa.

### Opción B — Pasar datos como parámetros de escena

Usar `get_node("/root").get_meta(...)` o variables exportadas en la escena raíz
para pasar los valores de GameSetup a Game.

- **Pro**: sin estado global, más explícito.
- **Contra**: acoplamiento frágil entre escenas; dificulta agregar nuevos campos
  sin modificar todas las escenas intermedias.
- **Contra**: no resuelve la persistencia a disco (habría que agregar otro
  mecanismo de todas formas).

### Opción C — Plugin GUT / ResourceSaver

Usar `Resource` de Godot con `ResourceSaver.save()`.

- **Pro**: integra bien con el sistema de recursos de Godot.
- **Contra**: mayor overhead para datos simples tipo clave-valor.
- **Contra**: requiere definir clases Resource adicionales para cada tipo de dato.

## Consecuencias

### Positivas

- GameSetup llama `SaveData.start_session(...)` y Game lee `SaveData.session`
  sin necesidad de referencias cruzadas entre escenas.
- `get_setting(key, default)` permite añadir nuevas preferencias con un valor
  por defecto sin migración de archivos existentes (merge en `load_data()`).
- Las estadísticas de todos los jugadores se acumulan en un único archivo JSON
  legible y portable.

### Negativas

- Los tests de lógica pura (`GameManager`, `BotPlayer`) dependen
  indirectamente de `SaveData` para leer `well_size`. En el test runner se
  acepta esta dependencia porque SaveData es un autoload disponible en runtime.
- `session` no se limpia automáticamente al volver al menú principal; hay que
  llamar a `start_session` explícitamente al iniciar cada partida.

## Notas de implementación

- Archivo de guardado: `user://save_data.json` (ruta estándar de Godot, separada
  del directorio del proyecto).
- `settings.merge(parsed["settings"], true)` al cargar permite agregar nuevas
  claves con valores por defecto sin romper saves existentes.
- `player_color` se guarda en `session` como string hex (`Color.to_html()`) y
  se reconstruye con `Color(hex)` via `get_session_color()`.

## Decisiones relacionadas

- ADR-0002: Framework de tests custom (SaveData disponible en runtime del runner)
