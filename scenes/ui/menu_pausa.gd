class_name MenuPausa
extends Control
## Menú de pausa (Esc en partida): libera el mouse y muestra las opciones.
## NO pausa la partida: los demás siguen jugando.

signal cerrado

@onready var _continuar: Button = %continuar
@onready var _salir: Button = %salir


func _ready() -> void:
	hide()
	_continuar.pressed.connect(cerrar)
	_salir.pressed.connect(Red.desconectar)


func abrir() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continuar.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cerrado.emit()


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()
