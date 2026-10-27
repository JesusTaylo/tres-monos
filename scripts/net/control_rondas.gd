extends Node
## Control de rondas (un nodo por nivel). Lo maneja el host: cuando el puzzle
## se resuelve, celebra y le pide al Lobby pasar a la siguiente prueba (que
## rota los roles y cambia de escena con la salida ordenada).
## Si el nivel se abrió suelto para probar (sin partida), reinicia el mismo cuarto.
## El puzzle solo necesita la señal `resuelto` y el método `reiniciar()`.

const PAUSA_CELEBRACION := 3.0
const DURACION_ANUNCIO := 4.5

@export var puzzle: Node
@export var spawner: SpawnerJugadores
@export var aviso: AvisoRonda


func _ready() -> void:
	if not multiplayer.is_server():
		return
	puzzle.resuelto.connect(_al_resolver)
	if Lobby.en_partida:
		Lobby.todos_cargaron.connect(_anunciar_prueba_actual)


func _al_resolver() -> void:
	_celebrar.rpc(Lobby.prueba_actual if Lobby.en_partida else -1)
	# Tween del nodo: si el nivel se cierra antes (alguien se fue), se cancela solo.
	var tween := create_tween()
	tween.tween_interval(PAUSA_CELEBRACION)
	tween.tween_callback(_siguiente)


func _siguiente() -> void:
	if Lobby.en_partida:
		Lobby.avanzar_prueba()
		return
	# Nivel suelto: se vuelve a jugar el mismo cuarto.
	_reiniciar_mundo()
	puzzle.reiniciar()


func _reiniciar_mundo() -> void:
	for objeto: ObjetoFisico in get_tree().get_nodes_in_group("objetos_fisicos"):
		objeto.reiniciar()
	for id in Lobby.jugadores:
		var jugador := Jugador.buscar(get_tree(), id)
		var punto := spawner.punto_de(id)
		if jugador and punto:
			jugador.teletransportar.rpc_id(id, punto.global_position, punto.global_rotation.y)


func _anunciar_prueba_actual() -> void:
	# Va después del estado del Lobby por el mismo canal confiable,
	# así que al llegar cada uno ya tiene su rol nuevo.
	_anunciar_prueba.rpc(Lobby.prueba_actual)


## `prueba` = -1 si el nivel está suelto.
@rpc("authority", "call_local", "reliable")
func _celebrar(prueba: int) -> void:
	var subtitulo := "Otra vez..."
	if prueba != -1 and prueba >= Lobby.PRUEBAS.size() - 1:
		subtitulo = "¡Era la última prueba!"
	elif prueba != -1:
		subtitulo = "Siguiente: %s · cambian los roles..." % Lobby.nombre_prueba(prueba + 1)
	aviso.mostrar("¡Prueba superada!", subtitulo, PAUSA_CELEBRACION)


@rpc("authority", "call_local", "reliable")
func _anunciar_prueba(prueba: int) -> void:
	var titulo := "Prueba %d: %s" % [prueba + 1, Lobby.nombre_prueba(prueba)]
	var rol := Lobby.mi_rol()
	if rol == -1:
		aviso.mostrar(titulo, "", DURACION_ANUNCIO)
		return
	# La primera prueba de la partida (aunque se haya empezado en otra con debug).
	var frase := "Eres el %s" if Lobby.tiempos.is_empty() else "Ahora eres el %s"
	aviso.mostrar(titulo, "%s\n%s" % [frase % Roles.nombre(rol), Roles.descripcion(rol)],
		DURACION_ANUNCIO)
