extends Node3D
## Puzzle del plátano: en la mesa hay varias frutas y solo un plátano es el
## bueno. Solo el Mudo lo ve marcado (contorno en la capa OBJETIVO); para el
## Sordo y el Ciego todos los plátanos son iguales. El Ciego tiene que llevarlo
## a la ranura de la pared. Si mete otro, explota en confeti y vuelve a la mesa.
## El host elige el plátano bueno, revisa lo que entra a la ranura y avisa a todos.

## Solo se emite en el host.
signal resuelto

const ROL_QUE_ENTREGA := Roles.Rol.CIEGO
const RADIO_RUIDO_ERROR := 7.0
const RADIO_RUIDO_EXITO := 5.0
const RADIO_RUIDO_RECHAZO := 3.0

## Contenedor de las frutas (ObjetoFisico). Los del grupo "platanos" pueden ser el bueno.
@export var frutas: Node3D
## Area3D frente a la ranura: lo que entra se revisa.
@export var ranura: Area3D

## Nombre del nodo del plátano bueno (igual en todos los peers).
var _correcto := ""
var _resuelto := false


func _ready() -> void:
	if not multiplayer.is_server():
		return
	ranura.body_entered.connect(_al_entrar_a_la_ranura)
	if Lobby.en_partida:
		Lobby.todos_cargaron.connect(reiniciar)
	else:
		reiniciar.call_deferred()


func esta_resuelto() -> bool:
	return _resuelto


## Solo host: otro plátano bueno al azar y todas las frutas de vuelta.
func reiniciar() -> void:
	var platanos := frutas.get_children().filter(
		func(fruta: Node) -> bool: return fruta.is_in_group("platanos"))
	_correcto = platanos.pick_random().name
	_resuelto = false
	_enviar_estado()


func _al_entrar_a_la_ranura(cuerpo: Node3D) -> void:
	if _resuelto or not cuerpo is ObjetoFisico or cuerpo.get_parent() != frutas:
		return
	var fruta := cuerpo as ObjetoFisico
	var posicion := ranura.global_position
	# Solo cuenta si la mete el Ciego; si no, la ranura la escupe a la mesa sin más.
	if Lobby.roles_asignados() and Lobby.rol_de(fruta.sostenido_por) != ROL_QUE_ENTREGA:
		Ruido.emitir(posicion, RADIO_RUIDO_RECHAZO, 0.5)
		_sonar.rpc("tic", posicion)
		fruta.reiniciar.call_deferred()
		return
	if fruta.name == _correcto:
		_resuelto = true
		Ruido.emitir(posicion, RADIO_RUIDO_EXITO, 1.0)
		_sonar.rpc("exito", posicion)
		_enviar_estado()
		resuelto.emit()
		return
	# Equivocado: confeti, sonido ridículo y de vuelta a la mesa.
	Ruido.emitir(posicion, RADIO_RUIDO_ERROR, 1.0)
	_explotar.rpc(posicion)
	# Diferido: no se mueve un cuerpo dentro de su propia señal de física.
	fruta.reiniciar.call_deferred()


func _enviar_estado() -> void:
	_recibir_estado.rpc(_correcto, _resuelto)


@rpc("authority", "call_local", "reliable")
func _recibir_estado(correcto: String, resuelto_: bool) -> void:
	_correcto = correcto
	_resuelto = resuelto_
	for fruta in frutas.get_children():
		var marca := fruta.get_node_or_null("marca") as Node3D
		if marca:
			marca.visible = fruta.name == _correcto
		# El plátano bueno "se lo come" la ranura al entregarlo.
		fruta.visible = not (_resuelto and fruta.name == _correcto)


@rpc("authority", "call_local", "reliable")
func _explotar(posicion: Vector3) -> void:
	Confeti.explotar(self, posicion)
	Sonidos.reproducir(self, "pedorreta", posicion)


@rpc("authority", "call_local", "reliable")
func _sonar(nombre: String, posicion: Vector3) -> void:
	Sonidos.reproducir(self, nombre, posicion)
