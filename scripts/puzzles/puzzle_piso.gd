extends Node3D
## Puzzle del piso traicionero: una cuadrícula de baldosas que hay que cruzar.
## Solo un camino es seguro (cambia en cada ronda) y solo el Mudo lo ve
## (placas en la capa OBJETIVO); para el Sordo todas las baldosas son iguales.
## Las falsas se caen al pisarlas: el que cae da vueltas (ragdoll) y vuelve al
## inicio. El piso solo aguanta al Ciego: bajo los demás se cae cualquier baldosa.
## Se resuelve cuando el Ciego llega al otro lado.
##
## Las baldosas se crean por código, iguales en todos los peers (no se replican).
## El host vigila dónde está cada jugador, decide qué cae y se lo avisa a todos.
## La fila 0 está junto al inicio (+Z) y la última junto a la meta (-Z).

## Solo se emite en el host.
signal resuelto

const COLUMNAS := 6
const FILAS := 8
const LADO := 1.3
const SEPARACION := 0.08
const GROSOR := 0.3
## Pasos laterales máximos del camino en cada fila.
const DESVIO_MAXIMO := 2
const ROL_QUE_CRUZA := Roles.Rol.CIEGO
## Altura (relativa al piso) bajo la cual alguien "se cayó".
const ALTURA_CAIDA := -1.2
## Lo que dura la caída antes de volver al inicio.
const ESPERA_REAPARICION := 1.3
## Tras volver, no se lo vigila un rato (su posición nueva tarda en llegar).
const GRACIA_REAPARICION := 1.0
const ESPERA_REPONER := 3.0
const DURACION_CAIDA := 1.2
const RADIO_RUIDO_BALDOSA := 4.0
const RADIO_RUIDO_CAIDA := 5.0

@export var spawner: SpawnerJugadores
## Más allá de esta Z (local) se llegó a la meta.
@export var z_meta := -5.4

## Índices de las baldosas seguras.
var _seguras: Array[int] = []
var _caidas := {}
var _resuelto := false
var _baldosas: Array[StaticBody3D] = []
var _tweens := {}
## Host: id -> msec hasta el que no se vigila al jugador (está cayendo o recién volvió).
var _ignorados := {}


func _ready() -> void:
	_crear_baldosas()
	if not multiplayer.is_server():
		return
	if Lobby.en_partida:
		Lobby.todos_cargaron.connect(reiniciar)
	else:
		reiniciar.call_deferred()


func esta_resuelto() -> bool:
	return _resuelto


func indice(fila: int, columna: int) -> int:
	return fila * COLUMNAS + columna


## Centro local de una baldosa (la parte de arriba queda en y = 0).
func centro_de(i: int) -> Vector3:
	var fila := floori(float(i) / COLUMNAS)
	var columna := i % COLUMNAS
	return Vector3((columna - (COLUMNAS - 1) / 2.0) * LADO, -GROSOR / 2.0,
		((FILAS - 1) / 2.0 - fila) * LADO)


## Solo host: camino nuevo al azar y todas las baldosas en su lugar.
func reiniciar() -> void:
	_seguras.clear()
	var columna := randi() % COLUMNAS
	for fila in FILAS:
		_seguras.append(indice(fila, columna))
		if fila == FILAS - 1:
			break
		# Antes de avanzar a la fila siguiente, el camino puede moverse de costado.
		var desvio := randi_range(-DESVIO_MAXIMO, DESVIO_MAXIMO)
		for paso in absi(desvio):
			var nueva := columna + signi(desvio)
			if nueva < 0 or nueva >= COLUMNAS:
				break
			columna = nueva
			_seguras.append(indice(fila, columna))
	_resuelto = false
	_ignorados.clear()
	_recibir_estado.rpc(_seguras, _resuelto)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or _seguras.is_empty():
		return
	var ahora := Time.get_ticks_msec()
	for jugador: Jugador in get_tree().get_nodes_in_group("jugadores"):
		var id := str(jugador.name).to_int()
		if _ignorados.get(id, 0) > ahora:
			continue
		var local := to_local(jugador.global_position)
		if local.y < ALTURA_CAIDA:
			_al_caer(jugador, id)
			continue
		var puede_cruzar := not Lobby.roles_asignados() or Lobby.rol_de(id) == ROL_QUE_CRUZA
		if puede_cruzar and not _resuelto and local.z < z_meta and local.y > -0.3:
			_resuelto = true
			_recibir_estado.rpc(_seguras, _resuelto)
			resuelto.emit()
			continue
		var i := _baldosa_bajo(local)
		# Parado encima (no saltando por arriba ni ya cayendo).
		if i != -1 and not _caidas.has(i) and local.y > -0.25 and local.y < 0.3 \
				and (not puede_cruzar or not i in _seguras):
			_tirar_baldosa(i)


## Índice de la baldosa bajo una posición local, o -1 si no hay.
func _baldosa_bajo(local: Vector3) -> int:
	var columna := floori(local.x / LADO + COLUMNAS / 2.0)
	var fila := floori((FILAS / 2.0) - local.z / LADO)
	if columna < 0 or columna >= COLUMNAS or fila < 0 or fila >= FILAS:
		return -1
	return indice(fila, columna)


func _tirar_baldosa(i: int) -> void:
	_caidas[i] = true
	_caer_baldosa.rpc(i)
	var posicion := to_global(centro_de(i))
	Ruido.emitir(posicion, RADIO_RUIDO_BALDOSA, 0.9)
	get_tree().create_timer(ESPERA_REPONER).timeout.connect(_reponer.bind(i))


func _reponer(i: int) -> void:
	if not is_inside_tree() or not _caidas.has(i):
		return
	_caidas.erase(i)
	_reponer_baldosa.rpc(i)


func _al_caer(jugador: Jugador, id: int) -> void:
	_ignorados[id] = Time.get_ticks_msec() + int((ESPERA_REAPARICION + GRACIA_REAPARICION) * 1000)
	jugador.get_node("ragdoll").caer.rpc()
	Ruido.emitir(jugador.global_position + Vector3.UP * 2.0, RADIO_RUIDO_CAIDA, 1.0)
	_sonar.rpc("silbido_caida", jugador.global_position)
	get_tree().create_timer(ESPERA_REAPARICION).timeout.connect(_reaparecer.bind(id))


func _reaparecer(id: int) -> void:
	if not is_inside_tree():
		return
	var jugador := Jugador.buscar(get_tree(), id)
	var punto := spawner.punto_de(id)
	if jugador == null or punto == null:
		return
	jugador.teletransportar.rpc_id(id, punto.global_position, punto.global_rotation.y)
	jugador.get_node("ragdoll").levantarse.rpc()


func _crear_baldosas() -> void:
	var malla := BoxMesh.new()
	malla.size = Vector3(LADO - SEPARACION, GROSOR, LADO - SEPARACION)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.6, 0.58)
	var forma := BoxShape3D.new()
	forma.size = malla.size
	# Placa que marca el camino seguro: solo la ve el Mudo.
	var malla_marca := PlaneMesh.new()
	malla_marca.size = Vector2(LADO - SEPARACION, LADO - SEPARACION) * 0.8
	var material_marca := StandardMaterial3D.new()
	material_marca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_marca.albedo_color = Color(0.2, 1, 0.35)
	for i in FILAS * COLUMNAS:
		var baldosa := StaticBody3D.new()
		baldosa.name = "baldosa_%d" % i
		baldosa.position = centro_de(i)
		var colision := CollisionShape3D.new()
		colision.name = "colision"
		colision.shape = forma
		baldosa.add_child(colision)
		var vista := MeshInstance3D.new()
		vista.mesh = malla
		vista.material_override = material
		baldosa.add_child(vista)
		var marca := MeshInstance3D.new()
		marca.name = "marca"
		marca.mesh = malla_marca
		marca.material_override = material_marca
		marca.layers = Capas.OBJETIVO
		marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marca.position.y = GROSOR / 2.0 + 0.01
		marca.visible = false
		baldosa.add_child(marca)
		add_child(baldosa)
		_baldosas.append(baldosa)


func _poner_baldosa_en_su_lugar(i: int) -> void:
	if _tweens.has(i):
		_tweens[i].kill()
		_tweens.erase(i)
	var baldosa := _baldosas[i]
	baldosa.position = centro_de(i)
	baldosa.rotation = Vector3.ZERO
	baldosa.get_node("colision").set_deferred("disabled", false)


@rpc("authority", "call_local", "reliable")
func _recibir_estado(seguras: Array, resuelto_: bool) -> void:
	_seguras.assign(seguras)
	_resuelto = resuelto_
	_caidas.clear()
	for i in _baldosas.size():
		_poner_baldosa_en_su_lugar(i)
		_baldosas[i].get_node("marca").visible = i in _seguras


@rpc("authority", "call_local", "reliable")
func _caer_baldosa(i: int) -> void:
	var baldosa := _baldosas[i]
	_caidas[i] = true
	baldosa.get_node("colision").set_deferred("disabled", true)
	Sonidos.reproducir(self, "crujido", baldosa.global_position)
	var tween := create_tween().set_parallel()
	tween.tween_property(baldosa, "position:y", centro_de(i).y - 8.0, DURACION_CAIDA) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(baldosa, "rotation", Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)),
		DURACION_CAIDA)
	_tweens[i] = tween


@rpc("authority", "call_local", "reliable")
func _reponer_baldosa(i: int) -> void:
	_caidas.erase(i)
	_poner_baldosa_en_su_lugar(i)


@rpc("authority", "call_local", "reliable")
func _sonar(nombre: String, posicion: Vector3) -> void:
	Sonidos.reproducir(self, nombre, posicion)
