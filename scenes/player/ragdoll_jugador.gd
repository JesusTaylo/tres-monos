extends Node
## Ragdoll simple (componente del jugador): al caer, el cuerpo da vueltas como
## muñeco de trapo y la cámara del dueño se ladea. No es física de verdad: es
## una animación barata que se ve en todos los peers. La piden el host
## (caer / levantarse) y corre en todos; el movimiento lo sigue haciendo el dueño.

const DURACION := 1.2
## Vueltas que da el cuerpo mientras cae.
const VUELTAS := 1.6
## Ladeo máximo de la cámara del dueño (radianes).
const LADEO_CAMARA := 0.9
## El cuerpo gira alrededor de su centro, no de los pies.
const CENTRO := Vector3(0, 0.9, 0)

@export var modelo: Node3D
@export var camara: Camera3D

var _tween: Tween
var _eje := Vector3.RIGHT


@rpc("any_peer", "call_local", "reliable")
func caer() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	# Eje al azar, pero más de frente que de costado: así se ve que "cae de cabeza".
	_eje = Vector3(randf_range(0.6, 1.0), randf_range(-0.3, 0.3), randf_range(-0.6, 0.6)).normalized()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_girar_cuerpo, 0.0, TAU * VUELTAS, DURACION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_multiplayer_authority():
		_tween.tween_property(camara, "rotation:z", LADEO_CAMARA * signf(randf() - 0.5), DURACION * 0.5)


@rpc("any_peer", "call_local", "reliable")
func levantarse() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	if _tween:
		_tween.kill()
	_girar_cuerpo(0.0)
	camara.rotation.z = 0.0


func _girar_cuerpo(angulo: float) -> void:
	var giro := Basis(_eje, angulo)
	modelo.transform = Transform3D(giro, CENTRO - giro * CENTRO)
