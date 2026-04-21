# El Pozo — Brief de diseño de interfaz

## El juego

**El Pozo** es un juego de cartas multijugador (2–5 jugadores) para web y mobile.
El objetivo es ser el primero en vaciar el **pozo personal** (15 cartas).

### Reglas esenciales

- Cada jugador tiene: **pozo personal** (15 cartas, solo la tapa es visible), **mano** (5 cartas privadas) y **tablero personal** (hasta 5 columnas de cartas públicas).
- En el centro hay **escaleras compartidas**: secuencias ascendentes As → K. Cualquier jugador puede jugar cartas sobre ellas. Al llegar a K, la escalera se descarta.
- En su turno, el jugador juega cartas desde su mano, pozo o tablero hacia las escaleras, en cualquier orden y cantidad. Al terminar el turno **debe bajar una carta de la mano al tablero personal**.
- **Gana** el primero que vacíe su pozo.

---

## Paleta y estética actual

| Rol | Color |
|-----|-------|
| Fondo de juego | `#1a1a2e` (azul muy oscuro) |
| Fondo de menús | `#2D6A4F` (verde mesa) |
| Título / acento dorado | `#F5C518` |
| Carta normal (fondo) | `#F8F4E3` (crema) |
| Borde del pozo (zona clave) | `#E8A020` (ámbar) |
| Carta boca abajo (bot) | `#1A3A5C` (azul marino) |
| Turno activo del humano | `#F5C518` en el nombre |
| Separadores / texto secundario | `#888888` |
| Victoria | `#44BB88` |
| Derrota / advertencia | `#CC2222` |

El estilo es **sobrio y funcional**: sin ilustraciones, cartas con texto ("A♠", "7♥"), tipografía clara. Las cartas son rectángulos con borde redondeado. No hay animaciones complejas.

---

## Pantallas a diseñar

### 1. Menú principal

Pantalla de inicio al abrir el juego.

**Elementos:**
- Título "EL POZO" grande y centrado (dorado, ~52px)
- Subtítulo "Juego de cartas" (gris, pequeño)
- Tres botones: **Nueva partida**, **Estadísticas**, **Configuración**
- Versión en esquina (muy pequeño, gris oscuro)

**Fondo:** verde mesa (`#2D6A4F`). Layout centrado vertical y horizontalmente.

---

### 2. Configuración de partida

Se accede desde "Nueva partida". El jugador elige su nombre y cuántos bots rivales quiere.

**Elementos:**
- Título "Nueva partida"
- Campo de texto: nombre del jugador (placeholder "Jugador", máx 20 chars)
- Selector de cantidad de bots (1–4), con botones − y +
- Color del jugador: selector de color (se asocia al jugador en el tablero)
- Botones: **Comenzar** y **Volver**

**Fondo:** verde mesa. Panel centrado, ancho ~420px.

---

### 3. Pantalla principal del juego

Es la pantalla más compleja. Layout vertical dividido en tres zonas:

```
┌──────────────────────────────────────┐
│  ZONA RIVALES (fila superior)        │
├──────────────────────────────────────┤
│  ZONA CENTRAL — escaleras + mazo     │
├──────────────────────────────────────┤
│  ZONA HUMANO (fila inferior)         │
├──────────────────────────────────────┤
│  HUD (barra de acciones)             │
└──────────────────────────────────────┘
```

#### Zona rivales

**Con 1 rival (más común):** ocupa toda la fila. Muestra la vista completa del rival:
- Nombre (en su color identificatorio)
- Pozo: carta tapa visible con borde ámbar
- Tablero personal: columnas de cartas apiladas en abanico (todas visibles, solo la tapa interactuable)
- Mano: N cartas boca abajo (el rival no muestra sus cartas)

**Con 2–4 rivales:** cada rival ocupa una porción igual de la fila. Se muestra una vista compacta por rival:
- Barra de color vertical + nombre
- Carta tapa del pozo
- Conteo de cartas en mano ("Mano: 5")
- Tops del tablero (iconos pequeños de las cartas superiores de cada columna)
- Al hacer hover/click se abre un overlay con el tablero completo del rival

#### Zona central

- Fila de **escaleras**: cada escalera es un rectángulo que muestra la carta superior y el palo. Se resaltan en verde las escaleras donde se puede jugar la carta seleccionada.
- Botón **"+"** al final de la fila para iniciar una nueva escalera (solo válido si se tiene un As)
- Mazo central: carta boca abajo con el conteo de cartas restantes

#### Zona humano

- Nombre del jugador
- **Pozo**: carta tapa con borde ámbar destacado (zona de victoria)
- **Tablero personal**: columnas apiladas en abanico, igual que los rivales
- **Mano**: fila de cartas boca arriba, interactuables

#### HUD (barra inferior)

- Estado actual ("Tu turno", "Elige una escalera", "El bot está pensando...")
- Botón **Terminar turno** (se activa el flujo de bajar carta al tablero)
- Botón **Pausa** (≡ o ⏸)
- Log de la última acción jugada

#### Interacción en el juego

1. Click en carta (mano / pozo / tablero) → se marca con borde dorado
2. Click en escalera → se juega la carta
3. "Terminar turno" → click en carta de mano → click en columna del tablero personal
4. También se puede arrastrar cartas a escaleras o al tablero (drag & drop)

---

### 4. Menú de pausa (overlay)

Se abre con Escape o el botón de pausa. Overlay semitransparente sobre el juego.

**Elementos:**
- Fondo semitransparente oscuro
- Panel centrado con: título "Pausa", botones **Continuar**, **Reiniciar partida**, **Configuración**, **Menú principal**

---

### 5. Pantalla de fin de partida (overlay)

Aparece cuando alguien vacía su pozo.

**Elementos:**
- Fondo semitransparente oscuro
- Resultado grande: "¡Ganaste!" (dorado) o "¡Perdiste!" (rojo)
- Nombre del ganador
- Estadísticas: turnos jugados, cartas jugadas
- Botones: **Jugar de nuevo** y **Menú principal**

---

### 6. Pantalla de configuración

Ajustes del juego.

**Elementos:**
- Tamaño de fuente (slider 11–20)
- Velocidad de animaciones (slider 0.5–2.0)
- Tema de cartas (dropdown, solo "Clásico" por ahora)
- Audio: música y efectos (sliders deshabilitados, "Próximamente")
- Botones: **Guardar** y **Volver**

**Fondo:** verde mesa. Panel centrado, ancho ~480px.

---

### 7. Pantalla de estadísticas

Lista de todos los jugadores que han jugado en el dispositivo.

**Elementos por jugador (tarjeta):**
- Nombre (negrita)
- "12 partidas · 75% victorias"
- Victorias (verde), Derrotas (rojo), Mejor partida en turnos (dorado)

Las tarjetas se ordenan por victorias. Si no hay datos: "Aún no hay partidas registradas."

---

## Componentes clave

### Carta (`CardView`)

- Rectángulo con bordes redondeados (~180×260px en vista normal)
- Fondo crema `#F8F4E3`
- Valor y palo en texto: "A♠", "7♥", "Q♦"
- Corazones/diamantes en rojo, piques/tréboles en negro/oscuro
- **Borde dorado** cuando está seleccionada
- **Borde ámbar** cuando es la carta del pozo
- **Borde del color del jugador** cuando es su turno activo
- Variante boca abajo: fondo azul marino `#1A3A5C` con patrón simple

### Escalera (`LadderView`)

- Rectángulo más angosto (muestra solo la carta tapa)
- En estado vacío: muestra "AS" como indicador de que se puede iniciar
- Resaltado verde cuando puede recibir la carta seleccionada

### Área de jugador (`PlayerAreaView`)

- Cada zona (pozo, tablero, mano) tiene un encabezado de sección
- Las columnas del tablero se muestran como apilamientos con offset vertical (abanico)

---

## Plataforma y responsividad

- **Target primario:** Web (HTML5), con mobile como siguiente paso
- Layout basado en contenedores flexibles, no posiciones absolutas
- Resolución base: 1280×720 (landscape)
- Touch targets mínimos: 44px de alto en botones
- Sin assets externos: todo el arte es generado proceduralmente (colores sólidos, texto)
