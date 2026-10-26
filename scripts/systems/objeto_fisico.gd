class_name ObjetoFisico
extends RigidBody3D
## Objeto que se puede agarrar. El host simula su física y es el único que
## decide quién lo sostiene; en los clientes queda congelado y solo muestra
## la posición replicada por su MultiplayerSynchronizer.
## Al chocar fuerte hace ruido (NoiseEvent); lo detecta el host.

## Qué tan fuerte persigue el objeto al punto de agarre. Bajo = más torpe.
const FUERZA_SEGUIMIENTO := 10.0
## Distancia máxima desde el punto de agarre para poder tomarlo.
const DISTANCIA_AGARRE := 3.0
## Si se traba y queda más lejos que esto, se suelta solo.
const DISTANCIA_MAXIMA := 3.5
## Rango de velocidad de choque que se convierte en ruido de 0 a 1.
const VELOCIDAD_GOLPE_MIN := 1.5
const VELOCIDAD_GOLPE_MAX := 7.0
## Para que un objeto rebotando no dispare un ruido por frame.
const ESPERA_ENTRE_GOLPES := 0.2

## Peer id de quien lo sostiene, 0 si nadie. Replicado a todos.
var sostenido_por := 0:
	set = _cambiar_sostenido_por

## La velocidad antes del paso de física: al chocar, la actual ya cambió.
var _velocidad_previa := Vector3.ZERO
var _ultimo_golpe := -INF
## Host: dónde empezó, para reacomodarlo entre rondas.
var _transformacion_inicial: Transform3D


## Devuelve el objeto que sostiene un jugador, o null.
static func sostenido_por_jugador(arbol: SceneTree, id: int) -> ObjetoFisico:
	for objeto in arbol.get_nodes_in_group("objetos_fisicos"):
		if objeto.sostenido_por == id:
			return objeto
	return null


func _ready() -> void:
	add_to_group("objetos_fisicos")
	_transformacion_inicial = global_transform
	if multiplayer.is_server():
		# No se replica hasta que todos cargaron el nivel (lo reactiva el Lobby).
		$sincronizador.public_visibility = false
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_al_chocar)
	else:
		freeze = true


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	if sostenido_por != 0:
		_seguir_a_quien_sostiene()
	_velocidad_previa = linear_velocity


func _seguir_a_quien_sostiene() -> void:
	var jugador := Jugador.buscar(get_tree(), sostenido_por)
	if jugador == null:
		sostenido_por = 0
		return
	var diferencia := jugador.punto_agarre.global_position - global_position
	if diferencia.length() > DISTANCIA_MAXIMA:
		sostenido_por = 0
		return
	linear_velocity = diferencia * FUERZA_SEGUIMIENTO
	angular_velocity = angular_velocity.lerp(Vector3.ZERO, 0.2)


func _al_chocar(_cuerpo: Node) -> void:
	var velocidad := _velocidad_previa.length()
	var ahora := Time.get_ticks_msec() / 1000.0
	if velocidad < VELOCIDAD_GOLPE_MIN or ahora - _ultimo_golpe < ESPERA_ENTRE_GOLPES:
		return
	_ultimo_golpe = ahora
	var intensidad := clampf(inverse_lerp(VELOCIDAD_GOLPE_MIN, VELOCIDAD_GOLPE_MAX, velocidad), 0.2, 1.0)
	Ruido.emitir(global_position, 2.0 + 4.0 * intensidad, intensidad)


@rpc("any_peer", "call_local", "reliable")
func pedir_agarrar() -> void:
	if not multiplayer.is_server() or sostenido_por != 0:
		return
	var id := multiplayer.get_remote_sender_id()
	var jugador := Jugador.buscar(get_tree(), id)
	if jugador == null or sostenido_por_jugador(get_tree(), id) != null:
		return
	if jugador.punto_agarre.global_position.distance_to(global_position) > DISTANCIA_AGARRE:
		return
	sostenido_por = id


@rpc("any_peer", "call_local", "reliable")
func pedir_soltar() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == sostenido_por:
		sostenido_por = 0


## Solo host: lo suelta y lo devuelve a su lugar inicial.
func reiniciar() -> void:
	sostenido_por = 0
	global_transform = _transformacion_inicial
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_velocidad_previa = Vector3.ZERO


## Mientras se sostiene, no choca con quien lo sostiene (si no, lo empujaría).
## Corre en todos los peers porque sostenido_por se replica.
func _cambiar_sostenido_por(nuevo: int) -> void:
	if nuevo == sostenido_por:
		return
	if is_inside_tree():
		var anterior := Jugador.buscar(get_tree(), sostenido_por)
		if anterior:
			remove_collision_exception_with(anterior)
		var actual := Jugador.buscar(get_tree(), nuevo)
		if actual:
			add_collision_exception_with(actual)
	sostenido_por = nuevo
