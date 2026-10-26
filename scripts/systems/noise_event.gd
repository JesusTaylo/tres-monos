class_name NoiseEvent
extends RefCounted
## Un ruido en el mundo: pasos, golpes, objetos cayendo, voz...
## Lo emite el sistema Ruido y el Ciego lo convierte en siluetas.

var posicion: Vector3
## Hasta dónde se "ve" el ruido, en metros.
var radio: float
## 0..1: qué tan brillantes son las siluetas.
var intensidad: float


func _init(p_posicion: Vector3, p_radio: float, p_intensidad: float) -> void:
	posicion = p_posicion
	radio = p_radio
	intensidad = clampf(p_intensidad, 0.0, 1.0)
