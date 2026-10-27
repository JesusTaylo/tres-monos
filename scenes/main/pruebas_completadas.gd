extends Control
## Pantalla final: las cuatro pruebas superadas, con lo que tardaron en cada una.
## Al rato (o cuando el host aprieta el botón) todos vuelven al lobby.
## Los tiempos llegan en el estado del Lobby; el host decide cuándo se vuelve.

const ESPERA_VOLVER := 12.0

var _restante := ESPERA_VOLVER

@onready var _lista: Label = %lista_tiempos
@onready var _cuenta: Label = %cuenta
@onready var _boton_volver: Button = %boton_volver


func _ready() -> void:
	_boton_volver.visible = multiplayer.is_server()
	_boton_volver.pressed.connect(Lobby.terminar_partida)
	Lobby.estado_cambiado.connect(_actualizar_lista)
	_actualizar_lista()


func _process(delta: float) -> void:
	_restante = maxf(_restante - delta, 0.0)
	_cuenta.text = "Volviendo al lobby en %d..." % ceili(_restante)
	if _restante <= 0.0 and multiplayer.is_server():
		set_process(false)
		Lobby.terminar_partida()


func _actualizar_lista() -> void:
	# Si se empezó en otra prueba (debug), los tiempos son de las últimas jugadas.
	var primera := Lobby.PRUEBAS.size() - Lobby.tiempos.size()
	var lineas: PackedStringArray = []
	var total := 0.0
	for i in Lobby.tiempos.size():
		total += Lobby.tiempos[i]
		lineas.append("%d. %s — %s" % [primera + i + 1, Lobby.nombre_prueba(primera + i),
			_formato(Lobby.tiempos[i])])
	if not lineas.is_empty():
		lineas.append("")
		lineas.append("Total: %s" % _formato(total))
	_lista.text = "\n".join(lineas)


static func _formato(segundos: float) -> String:
	return "%d:%02d" % [floori(segundos / 60.0), int(segundos) % 60]
