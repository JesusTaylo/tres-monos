class_name SpawnerJugadores
extends MultiplayerSpawner
## Crea un jugador por peer cuando todos terminaron de cargar el nivel.
## Esperar evita que el host replique jugadores a quien aún no tiene la escena.

const ESCENA_JUGADOR := preload("res://scenes/player/jugador.tscn")

## Marker3D hijos: uno por jugador, en orden de llegada al lobby.
@export var puntos_aparicion: Node3D

var _creados := false


func _ready() -> void:
	spawn_function = _crear_jugador
	if multiplayer.is_server():
		Lobby.todos_cargaron.connect(_crear_jugadores)
	# Diferido: si es el último en cargar, los jugadores se crean ya,
	# y no se pueden agregar nodos mientras la escena aún se está armando.
	Lobby.avisar_nivel_cargado.call_deferred()


func _crear_jugadores() -> void:
	if _creados:
		return
	_creados = true
	for id in Lobby.jugadores:
		var punto := punto_de(id)
		spawn({"id": id, "posicion": punto.global_position, "giro": punto.global_rotation.y})


## Punto de aparición de un jugador según su orden de llegada al lobby.
func punto_de(id: int) -> Node3D:
	var puntos := puntos_aparicion.get_children()
	var indice := maxi(Lobby.jugadores.find(id), 0)
	return puntos[indice % puntos.size()]


## Corre en todos los peers (host y clientes) para cada jugador replicado.
func _crear_jugador(datos: Dictionary) -> Node:
	var jugador := ESCENA_JUGADOR.instantiate()
	jugador.name = str(datos.id)
	jugador.position = datos.posicion
	jugador.rotation.y = datos.giro
	jugador.set_multiplayer_authority(datos.id)
	return jugador
