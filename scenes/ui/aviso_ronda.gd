class_name AvisoRonda
extends Control
## Aviso grande en pantalla (inicio y fin de ronda). Se muestra un rato
## y se desvanece solo.

const DURACION_DESVANECIDO := 0.4

var _tween: Tween

@onready var _titulo: Label = %titulo
@onready var _subtitulo: Label = %subtitulo


func _ready() -> void:
	hide()


func mostrar(titulo: String, subtitulo: String, duracion: float) -> void:
	_titulo.text = titulo
	_subtitulo.text = subtitulo
	_subtitulo.visible = not subtitulo.is_empty()
	modulate.a = 1.0
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(maxf(duracion - DURACION_DESVANECIDO, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, DURACION_DESVANECIDO)
	_tween.tween_callback(hide)
