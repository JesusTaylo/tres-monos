extends Node
## Control de rondas (un nodo por nivel). Lo maneja el host:
## cuando el puzzle se resuelve, celebra, rota los roles, devuelve a todos
## a su punto de inicio, reacomoda los objetos y reinicia el puzzle.
## El puzzle solo necesita la señal `resuelto` y el método `reiniciar()`.

const PAUSA_CELEBRACION := 3.0
const DURACION_ANUNCIO := 4.5

@export var puzzle: Node
@export var spawner: SpawnerJugadores
@export var aviso: AvisoRonda

## Solo la lleva el host; los clientes la reciben en el anuncio.
var _ronda := 1


func _ready() -> void:
	if not multiplayer.is_server():
		return
	puzzle.resuelto.connect(_al_resolver)
	if Lobby.en_partida:
		Lobby.todos_cargaron.connect(_anunciar_ronda_actual)


func _al_resolver() -> void:
	_celebrar.rpc()
	# Tween del nodo: si el nivel se cierra antes (alguien se fue), se cancela solo.
	var tween := create_tween()
	tween.tween_interval(PAUSA_CELEBRACION)
	tween.tween_callback(_empezar_nueva_ronda)


func _empezar_nueva_ronda() -> void:
	_ronda += 1
	Lobby.rotar_roles()
	_reiniciar_mundo()
	puzzle.reiniciar()
	_anunciar_ronda_actual()


func _reiniciar_mundo() -> void:
	for objeto: ObjetoFisico in get_tree().get_nodes_in_group("objetos_fisicos"):
		objeto.reiniciar()
	for id in Lobby.jugadores:
		var jugador := Jugador.buscar(get_tree(), id)
		var punto := spawner.punto_de(id)
		if jugador and punto:
			jugador.teletransportar.rpc_id(id, punto.global_position, punto.global_rotation.y)


func _anunciar_ronda_actual() -> void:
	# Va después del estado del Lobby por el mismo canal confiable,
	# así que al llegar cada uno ya tiene su rol nuevo.
	_anunciar_ronda.rpc(_ronda)


@rpc("authority", "call_local", "reliable")
func _celebrar() -> void:
	aviso.mostrar("¡Lo lograron!", "Siguiente ronda: cambian los roles...", PAUSA_CELEBRACION)


@rpc("authority", "call_local", "reliable")
func _anunciar_ronda(ronda: int) -> void:
	var rol := Lobby.mi_rol()
	if rol == -1:
		aviso.mostrar("Ronda %d" % ronda, "", DURACION_ANUNCIO)
		return
	var frase := "Eres el %s" if ronda == 1 else "Ahora eres el %s"
	aviso.mostrar("Ronda %d" % ronda, "%s\n%s" % [frase % Roles.nombre(rol), Roles.descripcion(rol)],
		DURACION_ANUNCIO)
