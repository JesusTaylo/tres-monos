class_name Boton
extends StaticBody3D
## Botón de pared. Un jugador pide presionarlo (E) y el host, si está cerca,
## avisa al puzzle con la señal presionado. El puzzle decide si cuenta y
## llama a los métodos visuales en todos los peers.

## Solo se emite en el host.
signal presionado(indice: int, id_jugador: int)

enum Estado { APAGADO, CORRECTO, ERROR }

const COLORES := {
	Estado.APAGADO: Color(0.55, 0.55, 0.55),
	Estado.CORRECTO: Color(0.2, 0.85, 0.3),
	Estado.ERROR: Color(0.95, 0.15, 0.1),
}
const DISTANCIA_MAXIMA := 3.5
## Cuánto se hunde el pulsador al presionarlo.
const HUNDIMIENTO := 0.05

## Lo asigna el puzzle según el orden de los hijos.
var indice := 0

var _material := StandardMaterial3D.new()

@onready var _pulsador: MeshInstance3D = $pulsador
@onready var _numero: Label3D = $numero
@onready var _posicion_pulsador := _pulsador.position


func _ready() -> void:
	_pulsador.material_override = _material
	poner_estado(Estado.APAGADO)
	mostrar_numero(0)


func poner_estado(estado: Estado) -> void:
	_material.albedo_color = COLORES[estado]
	# Encendido = brilla un poco.
	_material.emission_enabled = estado != Estado.APAGADO
	_material.emission = COLORES[estado] * 0.6


## 0 = sin número. El número solo lo ve el Mudo (capa OBJETIVO).
func mostrar_numero(numero: int) -> void:
	_numero.visible = numero > 0
	_numero.text = str(numero) if numero > 0 else ""


func animar_pulsacion() -> void:
	var tween := create_tween()
	var hundido := _posicion_pulsador - Vector3(0, 0, HUNDIMIENTO)
	tween.tween_property(_pulsador, "position", hundido, 0.06)
	tween.tween_property(_pulsador, "position", _posicion_pulsador, 0.15)


@rpc("any_peer", "call_local", "reliable")
func pedir_presionar() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var jugador := Jugador.buscar(get_tree(), id)
	if jugador and jugador.global_position.distance_to(global_position) <= DISTANCIA_MAXIMA:
		presionado.emit(indice, id)
