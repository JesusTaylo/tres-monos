# Tres Monos (título provisional)

Juego cooperativo multijugador de comedia ("friendslop") en primera persona para 3+ jugadores.
Inspirado en los tres monos sabios: uno no ve, uno no oye, uno no habla. Deben resolver puzzles
físicos comunicándose a través de una cadena rota de información. El caos de la comunicación ES el juego.

## Roles

| Rol | Ve | Oye | Habla | Qué hace |
|---|---|---|---|---|
| **Mudo** | Todo, incluido el objetivo | No | No | Único que entiende la situación. Se comunica con gestos. |
| **Sordo** | El entorno y a los jugadores, pero NO el objetivo | No | Sí | Interpreta los gestos del Mudo y los traduce en voz. |
| **Ciego** | Pantalla negra + siluetas vagas cuando hay ruido | Sí | Sí | El que actúa en el mundo, guiado por la voz del Sordo. |

Cadena de información: **Mudo → (gestos) → Sordo → (voz) → Ciego → (acciones)**

- Los roles rotan al terminar cada ronda.
- Tono: comedia. Fallar debe dar risa, no frustración (física torpe, ragdoll, sonidos ridículos).
- Con más de 3 jugadores (futuro): varias cadenas, o varios Ciegos siguiendo al mismo Sordo.

## Tecnología

- **Motor:** Godot 4 (versión estable más reciente), **GDScript**.
- **Renderer:** `Compatibility` o `Mobile`. El desarrollador trabaja en una laptop con gráfica
  integrada: mantener el rendimiento ligero (low-poly, pocas luces dinámicas, sin efectos pesados).
- **Red:** API de multijugador de alto nivel de Godot (`ENetMultiplayerPeer`,
  `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs). Modelo host-cliente: el host es autoridad
  sobre el estado del puzzle y la asignación de roles.
- **Voz (Hito 2):** chat de proximidad con `AudioEffectCapture` + `AudioStreamPlayer3D` por jugador.
  Evaluar plugin de VOIP con compresión, o GodotSteam si se publica en Steam.

## Cómo implementar la percepción de cada rol

Usar **capas de render** (`VisualInstance3D.layers` + `Camera3D.cull_mask`), no trucos de UI:

- Capa 1: mundo general.
- Capa 2: objetos de **objetivo** (lo que importa en el puzzle).
- Capa 3: jugadores.
- Capa 4: **siluetas** para el Ciego.

Cámaras por rol:
- **Mudo:** capas 1, 2, 3.
- **Sordo:** capas 1 y 3. Los objetivos no se renderizan para él. Opcional: niebla ligera.
- **Ciego:** solo capa 4 sobre fondo negro. Cada evento de ruido (pasos, golpes, objetos cayendo,
  voz) genera siluetas temporales de lo cercano a la fuente, que se desvanecen en ~1–2 s.
  Implementar como sistema `NoiseEvent` (posición, radio, intensidad) emitido por la red.

Audio por rol:
- **Mudo y Sordo:** no reciben audio de voz de nadie.
- **Mudo:** micrófono desactivado.
- Pendiente de decidir: si Mudo/Sordo oyen efectos de sonido del juego o silencio total.

## Gestos del Mudo

Es el sistema más importante del juego: debe ser expresivo pero ambiguo.

- Rueda de gestos (tecla mantenida + mouse): señalar, sí (asentir), no (negar), alto, ven, más,
  menos, pulgar arriba, contar con los dedos (1–5).
- Señalar con dirección real: raycast desde la cámara, el brazo apunta ahí. Se replica por red.
- Poder levantar y agitar objetos.
- Animaciones replicadas por RPC; todos los jugadores ven los gestos.

Implementado (Hito 1): rueda con **Q** mantenida → Sí, No, Alto, Ven, Pulgar arriba. **Señalar va
aparte, con clic derecho mantenido**, para apuntar en vivo. Faltan: más, menos, contar con los dedos
(agregar una entrada en `Gestos.NOMBRES` + su animación en `AnimadorGestos`; la rueda se adapta sola).

## Estructura del proyecto

```
/assets         modelos, texturas, sonidos que agrega el desarrollador (no renombrar sin avisar)
/scenes
  /main         menú, lobby
  /player       jugador, cámaras por rol, gestos
  /levels       cuartos de puzzles
  /ui
/scripts
  /net          conexión, lobby, asignación y rotación de roles
  /roles        lógica de percepción por rol
  /puzzles      lógica de cada puzzle
  /systems      NoiseEvent, interacción, física de objetos
```

## Convenciones

- Código y comentarios en español; nombres de archivos y nodos en `snake_case`.
- Un script por responsabilidad; evitar scripts gigantes.
- Todo estado de juego relevante lo decide el host y se sincroniza.
- Usar placeholders (cubos, cápsulas, `CSGBox3D`) hasta que existan assets reales.
- Probar multijugador lanzando varias instancias desde el editor
  (Depurar → Personalizar instancias de ejecución, 3 instancias).
- Antes de cerrar una tarea, verificar que el proyecto abra y corra sin errores.
- Los scripts ligados a una sola escena viven junto a ella (`scenes/.../x.gd`); `/scripts` es para
  lógica reutilizable o de sistemas.
- Si se agrega o renombra un `class_name` con el editor abierto, recargar el proyecto
  (Proyecto → Recargar proyecto actual): el editor puede regenerar la caché de clases con datos viejos.

## Arquitectura (estado actual)

**Autoloads**

| Nombre | Archivo | Responsabilidad |
|---|---|---|
| `Red` | `scripts/net/red.gd` | ENet host/cliente, saludo de autenticación, señales de conexión |
| `Lobby` | `scripts/net/lobby.gd` | Jugadores, roles, rotación y cambios de escena (menú ↔ lobby ↔ nivel) |
| `Ruido` | `scripts/systems/ruido.gd` | Emite `NoiseEvent` y los entrega solo al Ciego |
| `VentanasDebug` | `scripts/systems/ventanas_debug.gd` | En debug, acomoda las ventanas de cada instancia en 2×2 |

**Autoridad y red**
- El **host** decide: quién entra, roles, física de objetos (`ObjetoFisico`), puzzles y rondas.
- **Cada jugador es autoridad de su propio personaje** (movimiento en el cliente, replicado con
  `MultiplayerSynchronizer`). Si el host necesita moverlo, se lo pide por RPC
  (`Jugador.empujar`, `Jugador.teletransportar`) y lo aplica el dueño.
- Entrada: se usa la autenticación de `SceneMultiplayer`. El host acepta o rechaza con motivo
  ("La partida está llena", "La partida ya empezó") antes de que el peer cuente como conectado.
- Al entrar a un nivel, el host espera a que todos lo carguen (`Lobby.todos_cargaron`) antes de crear
  jugadores y de activar la replicación de los objetos (sus sincronizadores empiezan ocultos).
- Al salir de un nivel hay una salida ordenada con pausas: dejar de sincronizar → borrar jugadores →
  cambiar de escena. Así ningún peer recibe paquetes de nodos ya borrados.
- Si alguien se desconecta a mitad de partida, todos vuelven al lobby y se borran los roles.

**Interfaz de un puzzle** (para `control_rondas.gd`): señal `resuelto` (emitida en el host) y método
`reiniciar()`. Cada nivel tiene un nodo `control_rondas`, uno `siluetas` y un `spawner_jugadores`.

**Controles**: WASD caminar · Espacio saltar · E / clic agarrar, soltar y presionar · Q (mantener)
rueda de gestos · clic derecho (mantener) señalar · Esc liberar el mouse.

## Decisiones tomadas

- **Todos los roles pueden hacer gestos**, no solo el Mudo: el Mudo tampoco oye, así que el Sordo
  necesita contestarle con gestos. Restringirlo es una condición en `gestos.gd`.
- **Señalar va con clic derecho**, fuera de la rueda, para apuntar en vivo.
- **Solo las pulsaciones del Ciego cuentan** en el puzzle de botones; si no, el Mudo lo resolvería solo.
- **Fallar el puzzle lanza al Ciego hacia atrás** (comedia) y reinicia el progreso.
- El **Sordo ve con niebla ligera**. El **Ciego ve negro**; las siluetas usan un shader que ilumina lo
  cercano a cada ruido (hasta 16 ruidos a la vez) y se desvanece en 1.6 s. El objetivo nunca tiene silueta.
- Los `NoiseEvent` se envían **solo al Ciego**, por RPC no confiable.
- Las **rondas no terminan**: se rota (Mudo → Sordo → Ciego → Mudo) y se reinicia el cuarto
  indefinidamente. En 3 rondas cada uno jugó los 3 roles.
- Mientras no haya audio, el Sordo y el Ciego tienen que hablar por fuera (Discord o en persona).

## Hito 1 — Rebanada jugable (sin voz) ✅ completo

Objetivo: probar con amigos si da risa.

1. ✅ Proyecto Godot base con la estructura de carpetas y renderer ligero (`gl_compatibility`).
2. ✅ Menú simple: Hospedar / Unirse (IP) en red local (puerto 7777).
3. ✅ Lobby que espera 3 jugadores y asigna roles aleatorios (muestra la IP del host).
4. ✅ Controlador de jugador en primera persona (caminar, mirar, saltar, agarrar/soltar objetos) sincronizado.
5. ✅ Sistema de capas y cámaras por rol (Mudo / Sordo / Ciego).
6. ✅ Sistema `NoiseEvent` + siluetas del Ciego (pasos, aterrizajes, golpes de objetos, botones).
7. ✅ Rueda de gestos del Mudo (5 gestos + señalar).
8. ✅ Puzzle de 3 botones en orden: `scenes/levels/cuarto_botones.tscn` (nivel de la partida).
   `cuarto_pruebas.tscn` queda como sala de pruebas.
9. ✅ Fin de ronda → rotación de roles → reinicio del puzzle, jugadores y objetos.
10. ✅ Indicador de rol en pantalla ("Eres el CIEGO" + pista corta).

Pendiente o para observar al probar con amigos:
- Ajustes de sensación: sensibilidad y velocidad (`jugador.gd`), brillo de siluetas
  (`silueta.gdshader`), alcance de pasos (`pasos.gd`), empujón al fallar (`puzzle_botones.gd`).
- Si dos jugadores quedan exactamente encimados, sus cápsulas se empujan hacia arriba sin fin.
  No debería pasar en juego normal; si pasa, separarlos un poco al detectarlo.
- No hay efectos de sonido todavía.

## Hito 2 — Voz por proximidad

1. Captura de micrófono y transmisión por red.
2. Reproducción posicional con `AudioStreamPlayer3D` en cada jugador.
3. Reglas por rol (Mudo sin micro, Mudo y Sordo sin recibir voz).
4. La voz genera `NoiseEvent` para el Ciego.

## Ideas de puzzles (backlog)

- Armar un mueble con piezas que solo el Mudo distingue.
- Cortar el cable correcto de una bomba.
- Cocinar una receta (el Ciego echa ingredientes).
- Cruzar un piso con baldosas que se caen.
- Darle de comer a un animal que puede atacar.
- Cargar entre todos un objeto frágil por un pasillo.
