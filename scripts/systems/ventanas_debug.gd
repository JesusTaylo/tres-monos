extends Node
## Autoload "VentanasDebug". Solo en builds de debug: acomoda la ventana de
## cada instancia en una cuadrícula de 2x2 para que no se encimen al probar
## con varias instancias desde el editor.
##
## Cada instancia "aparta" un puerto local: la primera toma PUERTO_BASE,
## la segunda el siguiente, etc. Así sabe qué número de instancia es
## sin tener que configurar argumentos en el editor.

const PUERTO_BASE := 7790
const COLUMNAS := 2
const FILAS := 2

## Se mantiene abierto mientras viva la instancia para conservar su número.
var _reserva := TCPServer.new()


func _ready() -> void:
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	# Si el editor incrusta el juego en su pestaña, no se mueve la ventana.
	if OS.has_feature("embedded_in_editor"):
		return
	var indice := _reservar_indice()
	if indice == -1:
		return
	get_window().title += " — instancia %d" % (indice + 1)
	# Se espera un frame para que la ventana ya tenga sus bordes reales.
	_acomodar.call_deferred(indice)


func _reservar_indice() -> int:
	for i in COLUMNAS * FILAS:
		if _reserva.listen(PUERTO_BASE + i, "127.0.0.1") == OK:
			return i
	return -1


func _acomodar(indice: int) -> void:
	var ventana := get_window()
	var area := DisplayServer.screen_get_usable_rect(ventana.current_screen)
	# Tamaño de bordes + barra de título, para que la ventana completa quepa en su celda.
	var bordes := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var borde_lateral := bordes.x / 2.0
	var celda := Vector2(area.size) / Vector2(COLUMNAS, FILAS)
	var columna := indice % COLUMNAS
	var fila := int(float(indice) / COLUMNAS)

	ventana.size = Vector2i(celda) - bordes
	# position es la del área de contenido, sin bordes.
	ventana.position = area.position + Vector2i(
		celda.x * columna + borde_lateral,
		celda.y * fila + bordes.y - borde_lateral)
