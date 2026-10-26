class_name RuedaGestos
extends Control
## Rueda de gestos: solo dibuja. Gestos le pasa la dirección acumulada
## del mouse y le pregunta qué opción quedó elegida.

const RADIO := 150.0
## Dentro de este radio no se elige nada (soltar ahí cancela).
const RADIO_MUERTO := 35.0
const DURACION_AVISO := 1.2

const COLOR_FONDO := Color(0, 0, 0, 0.45)
const COLOR_SECTOR := Color(1, 1, 1, 0.08)
const COLOR_ELEGIDO := Color(1, 0.8, 0.3, 0.55)

var opciones := PackedStringArray()
## El nodo siempre está visible (para el aviso); esto controla si se dibuja la rueda.
var abierta := false:
	set(valor):
		abierta = valor
		queue_redraw()
var seleccion := -1:
	set(valor):
		seleccion = valor
		queue_redraw()

var _tween_aviso: Tween

@onready var _aviso: Label = $aviso


## Opción según la dirección (en píxeles desde el centro); -1 si está en el centro.
## La opción 0 está arriba y siguen en sentido horario.
func indice_para(direccion: Vector2) -> int:
	if direccion.length() < RADIO_MUERTO or opciones.is_empty():
		return -1
	var sector := TAU / opciones.size()
	var angulo := fposmod(direccion.angle() + PI / 2 + sector / 2, TAU)
	return int(angulo / sector) % opciones.size()


## Muestra brevemente el gesto hecho (el propio modelo no se ve en primera persona).
func avisar(texto: String) -> void:
	_aviso.text = "→ %s" % texto
	_aviso.modulate.a = 1.0
	_aviso.show()
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(DURACION_AVISO * 0.6)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, DURACION_AVISO * 0.4)
	_tween_aviso.tween_callback(_aviso.hide)


func _draw() -> void:
	if not abierta:
		return
	var centro := size / 2
	var fuente := get_theme_default_font()
	var tamano_fuente := get_theme_default_font_size()
	var sector := TAU / maxi(opciones.size(), 1)
	draw_circle(centro, RADIO, COLOR_FONDO)
	for i in opciones.size():
		var medio := -PI / 2 + i * sector
		var puntos := PackedVector2Array([centro + Vector2.from_angle(medio) * RADIO_MUERTO])
		for paso in 9:
			var angulo := medio - sector / 2 + sector * paso / 8.0
			puntos.append(centro + Vector2.from_angle(angulo) * (RADIO - 4))
		draw_colored_polygon(puntos, COLOR_ELEGIDO if i == seleccion else COLOR_SECTOR)
		var posicion := centro + Vector2.from_angle(medio) * RADIO * 0.62
		var ancho := fuente.get_string_size(opciones[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente).x
		draw_string(fuente, posicion + Vector2(-ancho / 2, tamano_fuente / 3.0), opciones[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente)
