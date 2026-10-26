class_name Jugador
extends CharacterBody3D
## Controlador en primera persona: caminar, mirar y saltar.
## Cada peer es autoridad de su propio jugador: lo mueve localmente y el
## MultiplayerSynchronizer replica posición, rotación y cabeza a los demás.

const VELOCIDAD := 5.0
const VELOCIDAD_SALTO := 4.5
const ACELERACION_SUELO := 12.0
const ACELERACION_AIRE := 3.0
const SENSIBILIDAD_MOUSE := 0.0025
## Límite para mirar arriba/abajo (~85°).
const LIMITE_CABEZA := 1.48

var _gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var cabeza: Node3D = $cabeza
@onready var punto_agarre: Marker3D = $cabeza/punto_agarre
@onready var _camara: Camera3D = $cabeza/camara
@onready var _rayo: RayCast3D = $cabeza/camara/rayo


## Busca el jugador de un peer en la escena actual.
static func buscar(arbol: SceneTree, id: int) -> Jugador:
	for jugador in arbol.get_nodes_in_group("jugadores"):
		if jugador.name == str(id):
			return jugador
	return null


func _ready() -> void:
	add_to_group("jugadores")
	_rayo.add_exception(self)
	var es_mio := is_multiplayer_authority()
	_camara.current = es_mio
	# Uno no se ve a sí mismo (la cámara está dentro de la cápsula).
	$modelo.visible = not es_mio
	$cabeza/cara.visible = not es_mio
	$hud.visible = es_mio
	set_physics_process(es_mio)
	set_process_unhandled_input(es_mio)
	if es_mio:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSIBILIDAD_MOUSE)
		cabeza.rotation.x = clampf(cabeza.rotation.x - event.relative.y * SENSIBILIDAD_MOUSE,
			-LIMITE_CABEZA, LIMITE_CABEZA)
	elif event.is_action_pressed("liberar_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Clic dentro de la ventana para volver a capturar el mouse.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


## Empujón cómico (p. ej. al equivocarse en un puzzle). Lo pide el host;
## lo aplica el dueño, que es quien mueve al jugador.
@rpc("any_peer", "call_local", "reliable")
func empujar(impulso: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	velocity += impulso


## Devuelve al jugador a un punto (p. ej. al empezar una ronda). Lo pide el host.
@rpc("any_peer", "call_local", "reliable")
func teletransportar(posicion: Vector3, giro: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	global_position = posicion
	rotation.y = giro
	cabeza.rotation.x = 0.0
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravedad * delta
	elif Input.is_action_just_pressed("saltar"):
		velocity.y = VELOCIDAD_SALTO

	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var direccion := transform.basis * Vector3(entrada.x, 0.0, entrada.y)
	var objetivo := direccion * VELOCIDAD
	var aceleracion := ACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
	velocity.x = move_toward(velocity.x, objetivo.x, aceleracion * VELOCIDAD * delta)
	velocity.z = move_toward(velocity.z, objetivo.z, aceleracion * VELOCIDAD * delta)
	move_and_slide()
