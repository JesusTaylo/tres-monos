extends Node3D
## Puzzle de los botones: el Ciego debe presionar los botones correctos en
## el orden correcto. Solo el Mudo ve cuáles son (números en la capa OBJETIVO).
## El host elige la secuencia, valida cada pulsación y envía el estado a todos.
## Los botones son los hijos Boton de este nodo.

## Solo se emite en el host.
signal resuelto

const LARGO_SECUENCIA := 3
const ROL_QUE_PRESIONA := Roles.Rol.CIEGO
const DURACION_ERROR := 0.7
## Empujón al que se equivoca: hacia atrás (alejándose de la pared) y arriba.
const EMPUJON_ATRAS := 7.0
const EMPUJON_ARRIBA := 4.5
const RADIO_RUIDO_PULSACION := 3.0
const RADIO_RUIDO_ERROR := 6.0

var _botones: Array[Boton] = []
var _secuencia: Array[int] = []
var _progreso := 0
var _resuelto := false
var _mostrando_error := false


func _ready() -> void:
	for hijo in get_children():
		if hijo is Boton:
			hijo.indice = _botones.size()
			_botones.append(hijo)
	if not multiplayer.is_server():
		return
	for boton in _botones:
		boton.presionado.connect(_al_presionar)
	if Lobby.en_partida:
		# Se espera a que todos tengan el nivel para mandarles el estado.
		Lobby.todos_cargaron.connect(reiniciar)
	else:
		# Nivel abierto suelto para probar.
		reiniciar.call_deferred()


func esta_resuelto() -> bool:
	return _resuelto


## Solo host: nueva secuencia al azar y progreso a cero.
func reiniciar() -> void:
	var indices := range(_botones.size())
	indices.shuffle()
	_secuencia.assign(indices.slice(0, LARGO_SECUENCIA))
	_progreso = 0
	_resuelto = false
	_enviar_estado()


func _al_presionar(indice: int, id_jugador: int) -> void:
	if _resuelto or _mostrando_error:
		return
	if Lobby.roles_asignados() and Lobby.rol_de(id_jugador) != ROL_QUE_PRESIONA:
		return
	var boton := _botones[indice]
	_animar_pulsacion.rpc(indice)
	if indice == _secuencia[_progreso]:
		_progreso += 1
		Ruido.emitir(boton.global_position, RADIO_RUIDO_PULSACION, 0.8)
		if _progreso == LARGO_SECUENCIA:
			_resuelto = true
			resuelto.emit()
	elif indice in _secuencia.slice(0, _progreso):
		# Volver a presionar uno ya correcto no castiga.
		Ruido.emitir(boton.global_position, RADIO_RUIDO_PULSACION, 0.8)
		return
	else:
		_progreso = 0
		Ruido.emitir(boton.global_position, RADIO_RUIDO_ERROR, 1.0)
		_empujar(id_jugador)
		_mostrar_error.rpc()
	_enviar_estado()


func _empujar(id_jugador: int) -> void:
	var jugador := Jugador.buscar(get_tree(), id_jugador)
	if jugador == null:
		return
	# Este nodo mira hacia afuera de la pared por su +Z.
	var atras := global_basis.z.normalized()
	jugador.empujar.rpc_id(id_jugador, atras * EMPUJON_ATRAS + Vector3.UP * EMPUJON_ARRIBA)


func _enviar_estado() -> void:
	_recibir_estado.rpc(_secuencia, _progreso, _resuelto)


func _actualizar_botones() -> void:
	for boton in _botones:
		var posicion := _secuencia.find(boton.indice)
		boton.mostrar_numero(posicion + 1)
		if _mostrando_error:
			continue
		var correcto := _resuelto or (posicion != -1 and posicion < _progreso)
		boton.poner_estado(Boton.Estado.CORRECTO if correcto else Boton.Estado.APAGADO)


@rpc("authority", "call_local", "reliable")
func _recibir_estado(secuencia: Array, progreso: int, resuelto_: bool) -> void:
	_secuencia.assign(secuencia)
	_progreso = progreso
	_resuelto = resuelto_
	_actualizar_botones()


@rpc("authority", "call_local", "reliable")
func _animar_pulsacion(indice: int) -> void:
	_botones[indice].animar_pulsacion()


@rpc("authority", "call_local", "reliable")
func _mostrar_error() -> void:
	_mostrando_error = true
	for boton in _botones:
		boton.poner_estado(Boton.Estado.ERROR)
	var tween := create_tween()
	tween.tween_interval(DURACION_ERROR)
	tween.tween_callback(_terminar_error)


func _terminar_error() -> void:
	_mostrando_error = false
	_actualizar_botones()
