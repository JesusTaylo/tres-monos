# Monkey See, Monkey Don't

(Antes «Tres Monos»; la carpeta del proyecto y el repositorio `tres-monos` conservan el nombre viejo.)

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
- **Plataformas:** Windows (x86_64) y **Android** (arm64, horizontal). Mismo proyecto y misma red:
  PC y teléfonos pueden jugar juntos en la misma red local.
- **Renderer:** `Compatibility` o `Mobile`. El desarrollador trabaja en una laptop con gráfica
  integrada: mantener el rendimiento ligero (low-poly, pocas luces dinámicas, sin efectos pesados).
- **Red:** API de multijugador de alto nivel de Godot (`ENetMultiplayerPeer`,
  `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs). Modelo host-cliente: el host es autoridad
  sobre el estado del puzzle y la asignación de roles.
- **Voz (Hito 2):** chat de proximidad con **TwoVoIP** (Opus + RNNoise, GDExtension en
  `addons/twovoip/`) + `AudioStreamPlayer3D` por jugador. Captura con `AudioServer.get_input_frames`
  (nativo de 4.7). **Fijado en v6.5**: la v6.6 cierra el editor de 4.7 al abrir el proyecto
  (issue #107 de TwoVoIP). Ver `addons/twovoip/VERSION.md` antes de actualizar.

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
- Efectos de sonido: **solo los oye el Ciego** (igual que la voz). La regla vive en
  `Sonidos.puede_oir()`; cambiarla ahí si se decide que Mudo/Sordo también los oigan.

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
  /main         menú, lobby, pantalla final
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
| `Lobby` | `scripts/net/lobby.gd` | Jugadores, roles, rotación, progresión de pruebas y cambios de escena (menú ↔ lobby ↔ pruebas ↔ pantalla final) |
| `Ruido` | `scripts/systems/ruido.gd` | Emite `NoiseEvent` y los entrega solo al Ciego |
| `Microfono` | `scripts/voz/microfono.gd` | Lee el micrófono (o la voz de prueba), decide si se habla, entrega paquetes Opus |
| `Opciones` | `scripts/systems/opciones.gd` | Opciones de audio; aplica y guarda en `user://opciones.cfg` |
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
- Al salir de un nivel hay una salida ordenada con pausas (`Lobby._salida_ordenada`): dejar de
  sincronizar → borrar jugadores → cambiar de escena. Así ningún peer recibe paquetes de nodos ya
  borrados. Se usa al pasar de prueba, al ir a la pantalla final y al volver al lobby.
- Si alguien se desconecta a mitad de partida, todos vuelven al lobby y se borran los roles.
- **Por internet**: no hay servidor propio. El host corre un túnel UDP (playit.gg) hacia su puerto
  7777 y pasa la dirección; "Unirse" acepta `ip`, `nombre` o `nombre:puerto` (`Red.separar_direccion`).
  Los nombres se resuelven sin congelar (`Red.resolver`; uno inexistente tarda ~11 s en fallar).

**Interfaz de un puzzle** (para `control_rondas.gd`): señal `resuelto` (emitida en el host) y método
`reiniciar()`. Cada nivel tiene un nodo `control_rondas`, uno `siluetas` y un `spawner_jugadores`.

**Progresión de pruebas**: `Lobby.PRUEBAS` es la lista ordenada (nombre + escena):
1 Botones → 2 Plátano → 3 Piso → 4 Caja fuerte. Al resolverse un puzzle, `control_rondas` celebra 3 s
y llama a `Lobby.avanzar_prueba()`: salida ordenada → rotar roles (sin jugadores en escena) → cargar
la siguiente prueba, o `scenes/main/pruebas_completadas.tscn` después de la última. Esa pantalla
muestra lo que tardaron en cada prueba (`Lobby.tiempos`) y a los 12 s (o con el botón del host)
`Lobby.terminar_partida()` devuelve a todos al lobby con los roles ya rotados. Si un nivel se abre
suelto (F6, sin partida), al resolverse se reinicia el mismo cuarto. **Debug**: en el lobby el host ve
un selector "Empezar en: …" para saltar directo a cualquier prueba (solo en builds de debug).
Para agregar una prueba: escena en `scenes/levels/` con los tres nodos de arriba y una entrada en
`Lobby.PRUEBAS`.

**Pruebas 2–4** (lógica en `scripts/puzzles/`; todo lo decide el host y lo manda por RPC):
- `puzzle_platano.gd` (`cuarto_platano.tscn`): 5 plátanos + limón + pepino (`ObjetoFisico`). El
  bueno se elige al azar y tiene un contorno verde en la capa OBJETIVO (nodo `marca`). La ranura es un
  `Area3D`: solo cuenta si la fruta la sostiene el Ciego al entrar; la equivocada hace confeti
  (`Confeti`) + pedorreta y vuelve a la mesa; si la mete otro rol, vuelve a la mesa sin más.
- `puzzle_piso.gd` (`cuarto_piso.tscn`): 6×8 baldosas creadas por código (iguales en todos los peers,
  no se replican). Camino seguro al azar (avanza fila a fila con desvíos laterales), marcado con placas
  en la capa OBJETIVO. El host vigila la posición de cada jugador: baldosa falsa pisada → cae (RPC) y
  vuelve a los 3 s. **El piso solo aguanta al Ciego**: bajo los demás se cae cualquier baldosa (si no,
  el Mudo cruzaría mostrando el camino). Quien cae da vueltas (`scenes/player/ragdoll_jugador.gd`,
  animación barata, no física) y el host lo devuelve al inicio con `Jugador.teletransportar`.
- `puzzle_caja_fuerte.gd` + `perilla.gd` (`cuarto_caja_fuerte.tscn`): combinación de 3 números 0–20
  (cada uno a 3+ pasos del anterior). El Ciego toma la perilla (E / "Agarrar") y la gira con A/D o el
  joystick (`Jugador.inmovil` lo deja quieto mientras tanto); E otra vez la suelta. El número y la
  marca del pomo están en la capa OBJETIVO, la combinación en una nota OBJETIVO sobre la caja. Hace
  "clic" (+ `NoiseEvent`) cuando la perilla **se queda 0.6 s** en el número que toca (`ESPERA_CLIC`;
  así no se resuelve girando sin parar). Pasarse no reinicia nada.

**Efectos de sonido**: `scripts/systems/sonidos.gd` (`Sonidos`, estático) los sintetiza al vuelo
(clic, tic, crujido, pedorreta, silbido de caída, éxito) porque aún no hay assets de audio; bus
"Efectos". Quien produce el sonido lo manda por RPC a todos y cada peer decide si lo oye.
`scripts/systems/confeti.gd`: `CPUParticles3D` de un disparo (ojo: con `one_shot` hay que llamar
`restart()` después de agregarlo al árbol, si no no arranca).

**Voz**: `scripts/voz/codec_voz.gd` es el **único** archivo que conoce TwoVoIP (crea sus clases con
`ClassDB.instantiate`, así el resto compila aunque falte la extensión). Para cambiar de códec,
reemplazar ese archivo con los mismos métodos. `scenes/player/voz_jugador.gd` envía y reproduce:
canal de red 2 (`unreliable_ordered`), colchón de ~60 ms, descarta si se atrasa más de 0.4 s.
El volumen con que habla cada uno (`nivel_voz`) se replica aparte para la boca, y la voz emite
`NoiseEvent` cada 0.3 s. Altavoz 3D: `unit_size` 3, `max_distance` 18 m, bus "Voz".

**Controles**: WASD caminar · Espacio saltar · E / clic agarrar, soltar y presionar · Q (mantener)
rueda de gestos · clic derecho (mantener) señalar · V (mantener) hablar · Esc menú de pausa
(opciones, libera el mouse; no pausa la partida). Con la perilla tomada: A/D (o joystick) girar.

**Entrada (PC y teléfono)**: `scripts/systems/entrada.gd` (`Entrada`, estático) decide si se juega con
mouse y teclado o táctil, y si se está "jugando" (fuera de menús). En táctil Godot convierte cada toque
en un clic de mouse falso: los controles de juego lo ignoran con `Entrada.es_mouse_de_toque()`.
`scenes/ui/controles_tactiles.gd` (en el HUD del jugador): joystick a la izquierda, arrastrar a la
derecha para mirar (`Jugador.mirar`), y `TouchScreenButton` (multitáctil) que mandan las **mismas
acciones** que las teclas (saltar, agarrar, gestos, senalar, hablar, liberar_mouse). Para probar el
modo táctil en PC: lanzar con `-- --tactil`.

**Probar la voz en una sola PC**: lanzar una instancia con `-- --voz-prueba` (Depurar → Personalizar
instancias de ejecución → argumentos) o marcar "Voz de prueba en bucle" en Opciones (solo debug).
Esa instancia habla sola con un "bla-bla" sintético. Con 3 instancias en la misma PC, todas leen el
mismo micrófono real: conviene usar la voz de prueba en una y "Pulsar para hablar" en las demás.

## Exportar

Presets en `export_presets.cfg` (sin contraseñas): "Windows Desktop" y "Android".
```
godot --headless --export-release "Windows Desktop" build/windows/MonkeySeeMonkeyDont.exe
godot --headless --export-release "Android" build/android/MonkeySeeMonkeyDont.apk
```
- Plantillas de exportación 4.7.2 instaladas solo para Windows y Android
  (`%APPDATA%\Godot\export_templates\4.7.2.stable\`).
- Android: Java 17 en `%LOCALAPPDATA%\Programs\Java\jdk-17…` y SDK en `%LOCALAPPDATA%\Android\Sdk`
  (platform-tools, build-tools 35.0.1, platforms android-35). Godot toma la ruta de Java de la
  configuración del editor (Exportar → Android → Java SDK Path), no de `JAVA_HOME`.
- **Llave de firma de Android: `%USERPROFILE%\.android-keystores\monkeysee.keystore`** (alias
  `monkeysee`; la contraseña está en `monkeysee-LEEME.txt` al lado). **Fuera del repo y no se pierde**:
  sin ella las actualizaciones no se instalan encima. Para exportar desde la terminal se pasa con
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` y
  `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Al publicar una versión nueva, subir `version/code`.
- `distribucion/LEEME.txt` va dentro del zip de Windows (y explica cómo instalar el APK).

## Decisiones tomadas

- **Todos los roles pueden hacer gestos**, no solo el Mudo: el Mudo tampoco oye, así que el Sordo
  necesita contestarle con gestos. Restringirlo es una condición en `gestos.gd`.
- **Señalar va con clic derecho**, fuera de la rueda, para apuntar en vivo.
- **Solo las acciones del Ciego cuentan** en todas las pruebas (pulsar botones, entregar la fruta,
  cruzar el piso, girar la perilla); si no, el Mudo las resolvería solo.
- **Fallar el puzzle lanza al Ciego hacia atrás** (comedia) y reinicia el progreso.
- El **Sordo ve con niebla ligera**. El **Ciego ve negro**; las siluetas usan un shader que ilumina lo
  cercano a cada ruido (hasta 16 ruidos a la vez) y se desvanece en 1.6 s. El objetivo nunca tiene silueta.
- Los `NoiseEvent` se envían **solo al Ciego**, por RPC no confiable.
- La partida es una **serie de 4 pruebas en orden**; entre prueba y prueba se rota
  (Mudo → Sordo → Ciego → Mudo). Al terminar la cuarta: pantalla "¡Pruebas completadas!" y al lobby.
- **La voz del Ciego no la oye nadie** en partidas de 3 (el Mudo y el Sordo no reciben voz); igual
  mueve su boca y genera siluetas para él mismo.
- **Android: solo arm64, horizontal y en pantalla completa**; controles = joystick + arrastrar para mirar.
  Los gestos en el teléfono: mantener "Gestos" y deslizar el mismo dedo hacia la opción.
- **Pulsar para hablar (V) es el modo por defecto**; el micrófono abierto usa un umbral de volumen
  más la probabilidad de voz de RNNoise, con 0.5 s de gracia para no cortar finales de palabra.

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
- Los efectos de sonido son sintéticos y provisorios (ver `Sonidos`).

## Hito 2 — Voz por proximidad ✅ completo (falta probarlo con amigos)

1. ✅ Captura de micrófono y transmisión por red (Opus ~14–20 kbps, solo hacia los Ciegos).
2. ✅ Reproducción posicional con `AudioStreamPlayer3D` en cada jugador.
3. ✅ Reglas por rol (Mudo sin micro, Mudo y Sordo sin recibir voz); se actualizan al rotar.
4. ✅ La voz genera `NoiseEvent` para el Ciego.
5. ✅ Boca que se abre según el volumen, visible para todos.
6. ✅ Opciones: micrófono, volumen de entrada (con medidor) y salida, modo abierto o pulsar (V).
   En el menú principal y en el menú de pausa (Esc).
7. ✅ Modo debug con voz de prueba en bucle.

Costo medido: ~2 % de un núcleo mientras el micrófono está encendido (RNNoise es lo más caro).
Solo están los binarios de Windows de TwoVoIP; para otras plataformas, copiarlos del zip de v6.5.

## Hito 3 — Pruebas 2–4 y progresión ✅ completo (falta probarlo con amigos)

1. ✅ Prueba 2, entrega de plátano (confeti y sonido ridículo al equivocarse).
2. ✅ Prueba 3, piso traicionero (baldosas que caen y vuelven, ragdoll simple, reaparición).
3. ✅ Prueba 4, caja fuerte (perilla con teclado y joystick, clic audible, la puerta se abre).
4. ✅ Progresión 1 → 4 con rotación de roles, pantalla final con tiempos y vuelta al lobby.
5. ✅ Selector de debug en el lobby para empezar en cualquier prueba.

Para observar al probar: si la perilla es cómoda en el teléfono (`Perilla.UMBRAL`, repetición), si
0.6 s de espera para el clic es mucho o poco, cuán largo es el camino del piso (`DESVIO_MAXIMO`) y si
hace falta que el piso también aguante al Sordo.

## Port a Android ✅ hecho (falta probarlo en teléfonos reales)

APK firmado de 33 MB con voz (TwoVoIP arm64) y permisos de internet y micrófono. Controles táctiles
probados en PC con toques simulados; nunca se corrió en un teléfono real todavía.

## Ideas de puzzles (backlog)

- Armar un mueble con piezas que solo el Mudo distingue.
- Cortar el cable correcto de una bomba.
- Cocinar una receta (el Ciego echa ingredientes).
- Darle de comer a un animal que puede atacar.
- Cargar entre todos un objeto frágil por un pasillo.
