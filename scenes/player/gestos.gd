class_name Gestos
extends Node
## Gestos del jugador (componente). Solo el dueño los controla:
## - Rueda: mantener Q, mover el mouse hacia un gesto y soltar Q.
## - Señalar: mantener clic derecho; el brazo apunta a donde mira la cámara.
## Los gestos se replican por RPC; el señalar, por el MultiplayerSynchronizer
## del jugador (apuntando / punto_apuntado). AnimadorGestos los dibuja en todos.

enum Gesto { SI, NO, ALTO, VEN, PULGAR_ARRIBA }

## En el orden de la rueda, empezando arriba y en sentido horario.
const NOMBRES := {
	Gesto.SI: "Sí",
	Gesto.NO: "No",
	Gesto.ALTO: "Alto",
	Gesto.VEN: "Ven",
	Gesto.PULGAR_ARRIBA: "Pulgar arriba",
}
## Hasta dónde llega el rayo de señalar. Si no choca con nada, apunta a esa distancia.
const ALCANCE_SENALAR := 30.0

signal gesto_hecho(gesto: Gesto)

## Replicados.
var apuntando := false
var punto_apuntado := Vector3.ZERO

@export var camara: Camera3D
@export var rueda: RuedaGestos

var _direccion_rueda := Vector2.ZERO


func _ready() -> void:
	var es_mio := is_multiplayer_authority()
	set_process(es_mio)
	set_process_unhandled_input(es_mio)
	rueda.opciones = PackedStringArray(NOMBRES.values())


func _unhandled_input(event: InputEvent) -> void:
	if Entrada.es_mouse_de_toque(event):
		return
	if not Entrada.jugando():
		_cerrar_rueda(false)
		apuntando = false
		return
	if event.is_action_pressed("gestos") and not apuntando:
		_abrir_rueda()
	elif event.is_action_released("gestos"):
		_cerrar_rueda(true)
	elif rueda.abierta and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		# Con la rueda abierta, el mouse (o el dedo que sostiene "Gestos") elige
		# gesto en vez de mover la cámara.
		_direccion_rueda = (_direccion_rueda + event.relative).limit_length(RuedaGestos.RADIO)
		rueda.seleccion = rueda.indice_para(_direccion_rueda)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("senalar") and not rueda.abierta:
		apuntando = true
		punto_apuntado = _calcular_punto_apuntado()
	elif event.is_action_released("senalar"):
		apuntando = false


func _process(_delta: float) -> void:
	if apuntando:
		punto_apuntado = _calcular_punto_apuntado()


func _abrir_rueda() -> void:
	_direccion_rueda = Vector2.ZERO
	rueda.seleccion = -1
	rueda.abierta = true


func _cerrar_rueda(ejecutar: bool) -> void:
	if not rueda.abierta:
		return
	rueda.abierta = false
	if ejecutar and rueda.seleccion != -1:
		var gesto: Gesto = NOMBRES.keys()[rueda.seleccion]
		_hacer_gesto.rpc(gesto)
		rueda.avisar(NOMBRES[gesto])


func _calcular_punto_apuntado() -> Vector3:
	var origen := camara.global_position
	var destino := origen - camara.global_basis.z * ALCANCE_SENALAR
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = [(owner as CollisionObject3D).get_rid()]
	var choque := camara.get_world_3d().direct_space_state.intersect_ray(consulta)
	return choque.position if choque else destino


@rpc("authority", "call_local", "reliable")
func _hacer_gesto(gesto: Gesto) -> void:
	gesto_hecho.emit(gesto)
