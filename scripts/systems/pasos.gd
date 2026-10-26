extends Node
## Ruido de pasos y aterrizajes (componente del jugador).
## Solo corre en el jugador propio: cada uno emite sus pasos.

const DISTANCIA_PASO := 1.4
const RADIO_PASO := 3.5
const INTENSIDAD_PASO := 0.6
## Velocidad de caída mínima para que aterrizar suene.
const VELOCIDAD_ATERRIZAJE := 3.0
const RADIO_ATERRIZAJE := 5.0

@export var cuerpo: CharacterBody3D

var _recorrido := 0.0
var _estaba_en_suelo := true
## La de antes de move_and_slide, que la deja en 0 al tocar el suelo.
var _velocidad_y_previa := 0.0


func _ready() -> void:
	set_physics_process(is_multiplayer_authority())


## Corre después del _physics_process del jugador (los hijos van después del padre).
func _physics_process(delta: float) -> void:
	var en_suelo := cuerpo.is_on_floor()
	if en_suelo and not _estaba_en_suelo and -_velocidad_y_previa > VELOCIDAD_ATERRIZAJE:
		Ruido.emitir(cuerpo.global_position, RADIO_ATERRIZAJE, 1.0)
		_recorrido = 0.0
	elif en_suelo:
		_recorrido += Vector2(cuerpo.velocity.x, cuerpo.velocity.z).length() * delta
		if _recorrido >= DISTANCIA_PASO:
			_recorrido = 0.0
			Ruido.emitir(cuerpo.global_position, RADIO_PASO, INTENSIDAD_PASO)
	_estaba_en_suelo = en_suelo
	_velocidad_y_previa = cuerpo.velocity.y
