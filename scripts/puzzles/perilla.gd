class_name Perilla
extends StaticBody3D
## Perilla de la caja fuerte. El Ciego la toma (E / "Agarrar"), y mientras la
## sostiene las teclas de caminar izquierda/derecha (A/D o el joystick en el
## teléfono) la giran un paso por vez; E de nuevo la suelta. Mientras la
## sostiene no camina (Jugador.inmovil).
## El host decide quién la sostiene y avisa al puzzle de cada giro con la señal
## girada; el puzzle decide el número y llama a mostrar_valor en todos los peers.

## Solo se emite en el host. `direccion` es -1 (izquierda) o 1 (derecha).
signal girada(direccion: int, id_jugador: int)

const ROL_QUE_GIRA := Roles.Rol.CIEGO
## Valores posibles: 0..CANTIDAD_VALORES-1.
const CANTIDAD_VALORES := 21
const DISTANCIA_MAXIMA := 3.0
## Al mantener la tecla: espera antes de repetir y pausa entre pasos.
const ESPERA_REPETIR := 0.35
const PAUSA_REPETIR := 0.13
## Qué tanto hay que inclinar el joystick para que cuente.
const UMBRAL := 0.5
const TEXTO_PISTA := "A / D: girar la perilla  ·  E: soltarla"
const TEXTO_PISTA_TACTIL := "Joystick a los lados: girar la perilla  ·  Agarrar: soltarla"

## Peer id de quien la sostiene, 0 si nadie. Lo envía el host.
var tomada_por := 0
## Pista en pantalla para quien la sostiene (opcional).
@export var pista: Label

## Dueño local: dirección que se está manteniendo y cuándo toca el próximo paso.
var _direccion_mantenida := 0
var _proximo_paso := 0.0

@onready var _pomo: Node3D = $pomo
@onready var _numero: Label3D = $numero


## Devuelve la perilla que sostiene un jugador, o null.
static func tomada_por_jugador(arbol: SceneTree, id: int) -> Perilla:
	for perilla in arbol.get_nodes_in_group("perillas"):
		if perilla.tomada_por == id:
			return perilla
	return null


func _ready() -> void:
	add_to_group("perillas")
	if pista:
		pista.text = TEXTO_PISTA_TACTIL if Entrada.es_tactil() else TEXTO_PISTA
		pista.hide()
	mostrar_valor(0)


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		_vigilar_distancia()
	if tomada_por == 0 or tomada_por != multiplayer.get_unique_id():
		return
	var eje := Input.get_axis("mover_izquierda", "mover_derecha") if Entrada.jugando() else 0.0
	var direccion := 0 if absf(eje) < UMBRAL else int(signf(eje))
	var ahora := Time.get_ticks_msec() / 1000.0
	if direccion == 0:
		_direccion_mantenida = 0
	elif direccion != _direccion_mantenida:
		_direccion_mantenida = direccion
		_proximo_paso = ahora + ESPERA_REPETIR
		pedir_girar.rpc_id(1, direccion)
	elif ahora >= _proximo_paso:
		_proximo_paso = ahora + PAUSA_REPETIR
		pedir_girar.rpc_id(1, direccion)


## El número y la marca del pomo solo los ve el Mudo (capa OBJETIVO). El pomo
## gira para todos, pero sin la marca es un cilindro liso: no se sabe dónde quedó.
func mostrar_valor(valor: int) -> void:
	_numero.text = str(valor)
	_pomo.rotation.z = -TAU * valor / CANTIDAD_VALORES


## Host: si quien la sostiene se aleja o se fue, se suelta sola.
func _vigilar_distancia() -> void:
	if tomada_por == 0:
		return
	var jugador := Jugador.buscar(get_tree(), tomada_por)
	if jugador == null or jugador.global_position.distance_to(global_position) > DISTANCIA_MAXIMA:
		_poner_tomada_por.rpc(0)


@rpc("any_peer", "call_local", "reliable")
func pedir_tomar() -> void:
	if not multiplayer.is_server() or tomada_por != 0:
		return
	var id := multiplayer.get_remote_sender_id()
	if Lobby.roles_asignados() and Lobby.rol_de(id) != ROL_QUE_GIRA:
		return
	var jugador := Jugador.buscar(get_tree(), id)
	if jugador and jugador.global_position.distance_to(global_position) <= DISTANCIA_MAXIMA:
		_poner_tomada_por.rpc(id)


@rpc("any_peer", "call_local", "reliable")
func pedir_soltar() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == tomada_por:
		_poner_tomada_por.rpc(0)


@rpc("any_peer", "call_local", "reliable")
func pedir_girar(direccion: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == tomada_por:
		girada.emit(clampi(direccion, -1, 1), tomada_por)


## Solo host: la suelta (p. ej. al abrir la caja o al reiniciar).
func soltar() -> void:
	if tomada_por != 0:
		_poner_tomada_por.rpc(0)


@rpc("authority", "call_local", "reliable")
func _poner_tomada_por(id: int) -> void:
	var mi_id := multiplayer.get_unique_id()
	var antes := tomada_por
	tomada_por = id
	_direccion_mantenida = 0
	# Mientras la sostiene, las teclas de caminar giran en vez de mover.
	for cambio in [antes, id]:
		if cambio == mi_id:
			var yo := Jugador.buscar(get_tree(), mi_id)
			if yo:
				yo.inmovil = id == mi_id
	if pista:
		pista.visible = id == mi_id and id != 0
