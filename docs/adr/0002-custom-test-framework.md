# ADR-0002: Framework de tests custom en lugar de GUT

## Estado

Aceptado

## Contexto

El proyecto necesita tests automatizados para la lógica del juego (`GameManager`,
`Player`, `LadderManager`, `BotPlayer`, etc.). Godot no incluye un framework de
tests en su distribución estándar; las opciones más comunes son instalar el
plugin GUT o escribir un runner propio.

## Decisión

Implementar un **framework de tests mínimo y propio** en
`escenas/test/test_runner.gd`, ejecutable en modo headless sin dependencias
externas.

API pública del runner:

```gdscript
func ok(condition: bool, desc: String) -> void   # assert booleano
func eq(a: Variant, b: Variant, desc: String) -> void  # assert igualdad
func _suite_header(name: String) -> void          # agrupa tests con nombre
```

Los helpers de construcción de datos de test (`_card`, `_joker`, `_ace`) viven
en el mismo archivo.

Ejecución headless:

```bash
Godot --headless --path /ruta/al/proyecto escenas/test/test_runner.tscn
```

## Opciones consideradas

### Opción A — Framework custom (elegida)

- **Pro**: cero dependencias externas; no requiere instalar ni versionar plugins.
- **Pro**: el runner es una escena Godot normal — se ejecuta con el mismo binario
  que el juego, sin toolchain adicional.
- **Pro**: API mínima suficiente para el 100 % de los casos de uso actuales.
- **Pro**: fácil de leer y modificar por cualquier contribuidor sin conocer GUT.
- **Contra**: hay que mantener el runner manualmente si se necesitan features
  avanzadas (setup/teardown, parametrización, cobertura).

### Opción B — Plugin GUT (Godot Unit Testing)

- **Pro**: framework maduro con muchas features (mocks, parametrización,
  cobertura, integración con CI via gdunit4-action).
- **Contra**: requiere instalar y versionar el plugin en `addons/`.
- **Contra**: introduce una dependencia de terceros que puede romperse con
  actualizaciones de Godot.
- **Contra**: overhead de configuración para un proyecto con tests relativamente
  simples y bien acotados.

### Opción C — Tests dentro del propio código de juego

Usar `assert()` de GDScript directamente en los scripts de lógica.

- **Contra**: los asserts de producción no dan reportes legibles ni se pueden
  correr de forma selectiva.
- **Contra**: mezcla código de producción con código de test.

## Consecuencias

### Positivas

- CI puede ejecutar `Godot --headless ... test_runner.tscn` sin setup adicional.
- Agregar un nuevo suite es tan simple como definir una función
  `_run_X_tests()` y llamarla desde `_ready()`.
- El resultado es legible en consola con marcadores `✓` / `✗` y un resumen
  `N/N passed`.

### Negativas

- Sin soporte nativo de mocks: los tests dependen de los autoloads reales
  (`SaveData`), lo que los convierte en tests de integración ligeros.
- Si el proyecto crece significativamente, puede ser necesario migrar a GUT
  para features como setup/teardown por suite o cobertura de código.

## Notas de implementación

- El conteo total de tests se imprime al final: `Resultado: N/N passed`.
- El runner termina con `get_tree().quit(1)` si hay fallos, facilitando la
  detección de errores en CI.
- Los tests están organizados en suites nombradas; actualmente hay 7 suites
  con 113 tests en total.

## Decisiones relacionadas

- ADR-0001: SaveData singleton (disponible como autoload en el runtime del runner)
