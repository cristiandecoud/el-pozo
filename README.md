# El Pozo

Juego de cartas para 2–5 jugadores implementado en Godot 4 (GDScript).
Las reglas completas están en [docs/reglas.md](docs/reglas.md).

---

## Requisitos

- [Godot 4.x](https://godotengine.org/download) (probado con Godot 4.3+)
- No hay dependencias externas ni plugins

---

## Correr el juego

### Desde el editor Godot

1. Abrir el proyecto: `File → Open Project` → seleccionar esta carpeta
2. Presionar **F5** (Run Project) o el botón ▶ en la barra superior

### Desde la terminal

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /ruta/al/proyecto
```

> En macOS con App Translocation (si copiaste Godot sin moverlo a Aplicaciones),
> la ruta puede ser más larga. Ver sección de troubleshooting abajo.

---

## Correr los tests

El proyecto usa un **framework de tests propio** (sin plugins externos).
El runner está en `escenas/test/test_runner.gd` con la escena
`escenas/test/test_runner.tscn`.

### Desde el editor Godot

1. En el panel de archivos, abrir `escenas/test/test_runner.tscn`
2. Presionar **F6** (Run This Scene)
3. La salida aparece en la consola inferior

### Desde la terminal (headless, sin UI — recomendado para CI)

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /ruta/al/proyecto \
  escenas/test/test_runner.tscn
```

La salida es texto plano en stdout. El proceso termina con código 0.

**Ejemplo de salida exitosa:**

```
═══════════════════════════════════════════
  EL POZO — Test Suite
═══════════════════════════════════════════

▶ Deck
    ✓ build crea la cantidad correcta de cartas
    ...
▶ BotPlayer
    ✓ bot juega el well antes que la mano cuando ambos son válidos
    ...

═══════════════════════════════════════════
  Resultado: 108/108 passed
  ✓ Todos los tests pasaron
═══════════════════════════════════════════
```

### Troubleshooting — macOS App Translocation

Si Godot no está en `/Applications/` sino en Descargas o similar, macOS lo
ejecuta desde una ruta temporal. Para encontrar la ruta correcta:

```bash
# Mientras Godot esté abierto:
ps aux | grep -i godot | grep -v grep
```

Copiar la ruta que aparece (algo como
`/private/var/folders/.../Godot.app/Contents/MacOS/Godot`).

La solución permanente es mover `Godot.app` a `/Applications/`.

---

## Estructura del proyecto

```
el-pozo/
├── docs/
│   ├── reglas.md                          # Reglas del juego
│   ├── plan_mvp.md                        # Plan de features del MVP
│   ├── glosario.md                        # Términos del dominio
│   └── implementaciones/
│       ├── 1-implementacion.md            # Fases 1–7: lógica base
│       ├── 2-implementacion_visual.md     # Fases 8–13: UI visual
│       ├── 3-implementacion_ux.md         # Fases 14–17: UX e interacción
│       ├── 4-implementacion_menus.md      # Fases 18–24: menús y persistencia
│       ├── 5-implementacion_multijugador_logica.md  # Fases 25–30: lógica multijugador y tests
│       └── 6-implementacion_multijugador_ui.md      # Fases 31–36: UI multijugador
├── escenas/
│   ├── test/
│   │   ├── test_runner.tscn               # Escena del test runner
│   │   └── test_runner.gd                 # Suites de tests (108 tests)
│   └── ...
├── scripts/
│   ├── ai/
│   │   └── bot_player.gd                  # IA del bot
│   ├── data/
│   │   ├── card.gd
│   │   ├── deck.gd
│   │   ├── player.gd
│   │   └── save_data.gd                   # Singleton: settings y sesión
│   ├── logic/
│   │   ├── game_manager.gd
│   │   └── ladder_manager.gd
│   └── ui/
│       └── game.gd
└── temas/                                 # Temas visuales de Godot
```

---

## Agregar tests nuevos

1. Abrir `escenas/test/test_runner.gd`
2. Agregar una función `_run_mi_suite()` con las llamadas a `ok()` y `eq()`
3. Llamarla desde `_ready()` antes del bloque de resumen final

```gdscript
# Ejemplo de test nuevo
func _run_mi_suite() -> void:
    _suite_header("MiClase")

    var obj := MiClase.new()
    ok(obj.alguna_condicion(), "descripción del test")
    eq(obj.algun_valor(), 42, "descripción del test de igualdad")

    print()  # línea en blanco entre suites
```

Los helpers de cartas disponibles en el runner:

```gdscript
_card(suit: Card.Suit, value: int) -> Card
_joker() -> Card
_ace() -> Card   # atajo para _card(Card.Suit.HEARTS, 1)
```

---

## Documentación de implementación

Los documentos en `docs/implementaciones/` describen el plan y el estado actual
de cada fase. Leer en orden numérico para entender la evolución del proyecto.

El estado de cada fase está indicado con ✅ (completada) o pendiente en los
documentos correspondientes.
