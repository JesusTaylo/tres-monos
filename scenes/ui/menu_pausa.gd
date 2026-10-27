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
	if Entrada.es_tactil():
		_continuar.text = "Continuar"


func abrir() -> void:
	show()
	Entrada.menu_abierto = true
	if not Entrada.es_tactil():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_continuar.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	hide()
	Entrada.menu_abierto = false
	if not Entrada.es_tactil():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cerrado.emit()


func _exit_tree() -> void:
	# Si se sale del nivel con el menú abierto, que no quede "en menú" para la próxima.
	if visible:
		Entrada.menu_abierto = false


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()
