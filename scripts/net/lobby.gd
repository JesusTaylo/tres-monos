extends Node
## Lobby (autoload "Lobby"): jugadores, roles y flujo de la partida.
## El host es la autoridad: decide quién entra, los roles y los cambios de
## escena, y los envía a todos. Los clientes solo reciben el estado por RPC.

signal estado_cambiado
## Host: todos los jugadores terminaron de cargar el nivel.
signal todos_cargaron

const ESCENA_MENU := "res://scenes/main/menu_principal.tscn"
const ESCENA_LOBBY := "res://scenes/main/lobby.tscn"
const ESCENA_FINAL := "res://scenes/main/pruebas_completadas.tscn"
## Las pruebas de la partida, en orden. Al superar una se pasa a la siguiente.
const PRUEBAS := [
	{"nombre": "Los botones", "escena": "res://scenes/levels/cuarto_botones.tscn"},
	{"nombre": "Entrega de plátano", "escena": "res://scenes/levels/cuarto_platano.tscn"},
	{"nombre": "Piso traicionero", "escena": "res://scenes/levels/cuarto_piso.tscn"},
	{"nombre": "La caja fuerte", "escena": "res://scenes/levels/cuarto_caja_fuerte.tscn"},
]
## Pausa al salir de un nivel para que terminen de llegar los últimos paquetes
## de sincronización antes de borrar la escena.
const PAUSA_SALIDA := 0.3

## Ids de los jugadores en orden de llegada (el host, id 1, siempre primero).
var jugadores: Array[int] = []
## id -> Roles.Rol. Vacío mientras no se hayan asignado.
var roles: Dictionary = {}
var en_partida := false
## Índice en PRUEBAS de la prueba que se está jugando.
var prueba_actual := 0
## Segundos que tardaron en cada prueba superada (para la pantalla final).
var tiempos: Array[float] = []
## Host: peers aceptados en el saludo que aún no terminan de conectarse.
## Cuentan como lugar ocupado para no aceptar a dos por el mismo hueco.
var _reservas: Array[int] = []
## Host: jugadores que ya cargaron el nivel.
var _cargados: Array[int] = []
## Host: cuándo empezó la prueba actual (ms), para medir cuánto tardaron.
var _inicio_prueba := 0
## Host: hay una salida de nivel en curso; evita empezar otra encima.
var _saliendo := false


func _ready() -> void:
	Red.validar_entrada = _validar_entrada
	Red.servidor_creado.connect(_al_crear_servidor)
	Red.jugador_conectado.connect(_al_conectarse_jugador)
	Red.jugador_desconectado.connect(_al_desconectarse_jugador)
	Red.saludo_fallido.connect(_reservas.erase)
	Red.desconectado.connect(_reiniciar)


func esta_lleno() -> bool:
	return jugadores.size() >= Red.MAX_JUGADORES


func roles_asignados() -> bool:
	return not roles.is_empty()


## Número visible del jugador (1, 2, 3...) según su orden de llegada.
func numero_de(id: int) -> int:
	return jugadores.find(id) + 1


## Devuelve el Roles.Rol del jugador, o -1 si aún no tiene.
func rol_de(id: int) -> int:
	return roles.get(id, -1)


func mi_rol() -> int:
	return rol_de(multiplayer.get_unique_id())


## Solo host: reparte los roles al azar cuando el lobby está lleno.
func asignar_roles() -> void:
	if not multiplayer.is_server() or not esta_lleno() or en_partida:
		return
	var disponibles := Roles.TODOS.duplicate()
	disponibles.shuffle()
	roles.clear()
	for i in jugadores.size():
		roles[jugadores[i]] = disponibles[i]
	_enviar_estado()


## Solo host: cada jugador pasa al siguiente rol (Mudo → Sordo → Ciego → Mudo).
## Así, en 3 rondas todos juegan los 3 roles.
func rotar_roles() -> void:
	if not multiplayer.is_server() or not roles_asignados():
		return
	for id in roles:
		roles[id] = (roles[id] + 1) % Roles.TODOS.size()
	_enviar_estado()


## Solo host: lleva a todos a la primera prueba. `prueba` permite empezar en
## otra (el selector de debug del lobby, para no repetir las anteriores).
func empezar_partida(prueba: int = 0) -> void:
	if not multiplayer.is_server() or not roles_asignados() or en_partida:
		return
	en_partida = true
	prueba_actual = clampi(prueba, 0, PRUEBAS.size() - 1)
	tiempos.clear()
	_cargar_nivel(PRUEBAS[prueba_actual].escena)


func nombre_prueba(indice: int) -> String:
	return PRUEBAS[indice].nombre if indice >= 0 and indice < PRUEBAS.size() else "?"


func es_ultima_prueba() -> bool:
	return prueba_actual >= PRUEBAS.size() - 1


## Solo host: la prueba actual se superó. Sale del nivel en orden, rota los
## roles y lleva a todos a la siguiente prueba (o a la pantalla final).
func avanzar_prueba() -> void:
	if not multiplayer.is_server() or not en_partida or _saliendo:
		return
	tiempos.append((Time.get_ticks_msec() - _inicio_prueba) / 1000.0)
	await _salida_ordenada()
	# Alguien se fue durante la salida: ya se está volviendo al lobby.
	if not en_partida:
		return
	# Se rota sin jugadores en escena, así nadie ve cambiar su vista a medio salir.
	rotar_roles()
	if es_ultima_prueba():
		_cargar_nivel(ESCENA_FINAL)
	else:
		prueba_actual += 1
		_cargar_nivel(PRUEBAS[prueba_actual].escena)


## Solo host: desde la pantalla final, todos vuelven al lobby con sus roles.
func terminar_partida() -> void:
	if not multiplayer.is_server() or not en_partida:
		return
	en_partida = false
	_enviar_estado()
	for id in jugadores:
		_cargar_escena.rpc_id(id, ESCENA_LOBBY)


## Cada peer lo llama cuando su nivel está listo para recibir jugadores.
func avisar_nivel_cargado() -> void:
	_nivel_cargado.rpc_id(1)


func todos_cargaron_nivel() -> bool:
	return en_partida and _cargados.size() == jugadores.size()


## Host: se llama durante el saludo de cada peer nuevo.
func _validar_entrada(id: int) -> String:
	if en_partida:
		return "La partida ya empezó"
	if jugadores.size() + _reservas.size() >= Red.MAX_JUGADORES:
		return "La partida está llena"
	_reservas.append(id)
	return ""


func _al_crear_servidor() -> void:
	jugadores.assign([multiplayer.get_unique_id()])
	roles.clear()
	en_partida = false
	_reservas.clear()
	estado_cambiado.emit()


func _al_conectarse_jugador(id: int) -> void:
	if not multiplayer.is_server():
		return
	_reservas.erase(id)
	jugadores.append(id)
	_enviar_estado()


func _al_desconectarse_jugador(id: int) -> void:
	if not multiplayer.is_server() or not id in jugadores:
		return
	jugadores.erase(id)
	# Sin los 3 jugadores no se puede jugar: se vuelve a esperar.
	roles.clear()
	if en_partida:
		en_partida = false
		_volver_al_lobby()
	_enviar_estado()


func _volver_al_lobby() -> void:
	await _salida_ordenada()
	for id in jugadores:
		_cargar_escena.rpc_id(id, ESCENA_LOBBY)


## Host: salida ordenada del nivel, para que ningún peer reciba paquetes de
## nodos que ya borró. Cada paso espera a que lleguen los paquetes del anterior:
## 1) todos dejan de sincronizar, 2) se borran los jugadores (el borrado se
## replica mientras todos siguen en el nivel). Después, quien llama cambia la escena.
func _salida_ordenada() -> void:
	_saliendo = true
	for id in jugadores:
		_detener_replicacion.rpc_id(id)
	await get_tree().create_timer(PAUSA_SALIDA).timeout
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		jugador.queue_free()
	await get_tree().create_timer(PAUSA_SALIDA).timeout
	_saliendo = false


## Host: manda a todos a una escena de la partida (un nivel o la pantalla final).
func _cargar_nivel(ruta: String) -> void:
	_cargados.clear()
	_enviar_estado()
	for id in jugadores:
		_cargar_escena.rpc_id(id, ruta)


func _reiniciar() -> void:
	jugadores.clear()
	roles.clear()
	en_partida = false
	prueba_actual = 0
	tiempos.clear()
	_reservas.clear()
	_cargados.clear()
	_saliendo = false
	estado_cambiado.emit()
	var escena := get_tree().current_scene
	if escena and escena.scene_file_path != ESCENA_MENU:
		get_tree().change_scene_to_file(ESCENA_MENU)


## Solo se envía a los jugadores ya conectados.
func _enviar_estado() -> void:
	for id in jugadores:
		_recibir_estado.rpc_id(id, jugadores.duplicate(), roles.duplicate(), en_partida,
			prueba_actual, tiempos.duplicate())


## Todos los MultiplayerSynchronizer de la escena actual.
func _sincronizadores() -> Array[Node]:
	var escena := get_tree().current_scene
	if escena == null:
		return []
	return escena.find_children("*", "MultiplayerSynchronizer", true, false)


@rpc("authority", "call_local", "reliable")
func _recibir_estado(nuevos_jugadores: Array, nuevos_roles: Dictionary, nuevo_en_partida: bool,
		nueva_prueba: int, nuevos_tiempos: Array) -> void:
	jugadores.assign(nuevos_jugadores)
	roles = nuevos_roles
	en_partida = nuevo_en_partida
	prueba_actual = nueva_prueba
	tiempos.assign(nuevos_tiempos)
	estado_cambiado.emit()


@rpc("authority", "call_local", "reliable")
func _cargar_escena(ruta: String) -> void:
	get_tree().change_scene_to_file(ruta)


@rpc("authority", "call_local", "reliable")
func _detener_replicacion() -> void:
	for sincronizador: MultiplayerSynchronizer in _sincronizadores():
		if sincronizador.is_multiplayer_authority():
			sincronizador.public_visibility = false


@rpc("any_peer", "call_local", "reliable")
func _nivel_cargado() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id in jugadores and not id in _cargados:
		_cargados.append(id)
	if todos_cargaron_nivel():
		_inicio_prueba = Time.get_ticks_msec()
		# Los objetos del nivel empiezan ocultos (public_visibility = false)
		# para no mandar datos a quien aún no tenía la escena.
		for sincronizador: MultiplayerSynchronizer in _sincronizadores():
			if sincronizador.is_multiplayer_authority():
				sincronizador.public_visibility = true
		todos_cargaron.emit()
