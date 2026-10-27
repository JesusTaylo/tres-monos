extends Control
## Controles táctiles (teléfono). Solo aparecen en modo táctil (ver Entrada).
## - Joystick a la izquierda: caminar (mueve las mismas acciones que WASD).
## - Arrastrar el dedo en la derecha: mirar.
## - Botones a la derecha: cada uno manda la misma acción que su tecla en PC,
##   así que el resto del juego no sabe si se juega con teclado o con el dedo.
## Los botones son TouchScreenButton porque soportan varios dedos a la vez
## (caminar y saltar al mismo tiempo); los botones de la interfaz no.

const RADIO_JOYSTICK := 90.0
const ZONA_MUERTA := 0.15
## Fracción izquierda de la pantalla donde un toque agarra el joystick.
const ZONA_JOYSTICK := 0.4
## [texto, acción, posición desde la esquina inferior derecha, radio].
const BOTONES := [
	["Saltar", "saltar", Vector2(-105, -105), 68.0],
	["Agarrar", "agarrar", Vector2(-245, -80), 56.0],
	["Gestos", "gestos", Vector2(-95, -265), 56.0],
	["Señalar", "senalar", Vector2(-230, -215), 50.0],
	["Hablar", "hablar", Vector2(-375, -75), 50.0],
]
const COLOR_BOTON := Color(1, 1, 1, 0.22)
const COLOR_BOTON_APRETADO := Color(1, 0.85, 0.35, 0.5)

@export var jugador: Jugador

var _dedo_joystick := -1
var _centro_joystick := Vector2.ZERO
var _vector := Vector2.ZERO
var _dedo_mirar := -1
## acción -> TouchScreenButton
var _botones := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if not Entrada.es_tactil():
		hide()
		set_process(false)
		set_process_input(false)
		return
	for datos in BOTONES:
		_crear_boton(datos[0], datos[1], datos[3])
	_crear_boton("Menú", "liberar_mouse", 34.0)
	resized.connect(_acomodar)
	Lobby.estado_cambiado.connect(_actualizar_hablar)
	Opciones.cambiadas.connect(_actualizar_hablar)
	_acomodar()
	_actualizar_hablar()


func _process(_delta: float) -> void:
	# Con el menú de pausa abierto los controles desaparecen (y sueltan todo).
	var mostrar := not Entrada.menu_abierto
	if mostrar != visible:
		visible = mostrar
		if not mostrar:
			_soltar_joystick()
			_dedo_mirar = -1
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _toca_un_boton(event.position):
				return
			if event.position.x < size.x * ZONA_JOYSTICK and _dedo_joystick == -1:
				_dedo_joystick = event.index
				_centro_joystick = event.position
				_vector = Vector2.ZERO
			elif event.position.x >= size.x * ZONA_JOYSTICK and _dedo_mirar == -1:
				_dedo_mirar = event.index
		elif event.index == _dedo_joystick:
			_soltar_joystick()
		elif event.index == _dedo_mirar:
			_dedo_mirar = -1
	elif event is InputEventScreenDrag:
		if event.index == _dedo_joystick:
			_vector = ((event.position - _centro_joystick) / RADIO_JOYSTICK).limit_length(1.0)
			_aplicar_movimiento()
		elif event.index == _dedo_mirar and Entrada.jugando():
			jugador.mirar(event.relative * Jugador.SENSIBILIDAD_TACTIL)


func _draw() -> void:
	# Joystick: base y perilla. Sin dedo, se dibuja tenue en su lugar de reposo.
	var activo := _dedo_joystick != -1
	var centro := _centro_joystick if activo else _reposo_joystick()
	draw_circle(centro, RADIO_JOYSTICK, Color(1, 1, 1, 0.12 if activo else 0.07))
	draw_arc(centro, RADIO_JOYSTICK, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)
	draw_circle(centro + _vector * RADIO_JOYSTICK, RADIO_JOYSTICK * 0.42, Color(1, 1, 1, 0.35))


func _reposo_joystick() -> Vector2:
	return Vector2(RADIO_JOYSTICK + 60.0, size.y - RADIO_JOYSTICK - 50.0)


func _soltar_joystick() -> void:
	_dedo_joystick = -1
	_vector = Vector2.ZERO
	_aplicar_movimiento()


## Traduce el joystick a las mismas acciones que WASD, con su intensidad.
func _aplicar_movimiento() -> void:
	var v := _vector if _vector.length() > ZONA_MUERTA else Vector2.ZERO
	_poner_eje("mover_izquierda", "mover_derecha", v.x)
	_poner_eje("mover_adelante", "mover_atras", v.y)


func _poner_eje(negativa: String, positiva: String, valor: float) -> void:
	if valor > 0.0:
		Input.action_release(negativa)
		Input.action_press(positiva, valor)
	elif valor < 0.0:
		Input.action_release(positiva)
		Input.action_press(negativa, -valor)
	else:
		Input.action_release(negativa)
		Input.action_release(positiva)


func _toca_un_boton(posicion: Vector2) -> bool:
	for boton: TouchScreenButton in _botones.values():
		if not boton.visible:
			continue
		var radio: float = boton.get_meta("radio")
		if posicion.distance_to(boton.position + Vector2(radio, radio)) <= radio:
			return true
	return false


func _crear_boton(texto: String, accion: String, radio: float) -> void:
	var boton := TouchScreenButton.new()
	boton.action = accion
	boton.texture_normal = _textura_circulo(COLOR_BOTON)
	boton.texture_pressed = _textura_circulo(COLOR_BOTON_APRETADO)
	var forma := CircleShape2D.new()
	forma.radius = 64.0
	boton.shape = forma
	boton.shape_centered = true
	# La textura mide 128 px: se escala al diámetro del botón.
	boton.scale = Vector2.ONE * (radio * 2.0 / 128.0)
	boton.set_meta("radio", radio)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.size = Vector2(128, 128)
	etiqueta.add_theme_font_size_override("font_size", int(17.0 * 128.0 / (radio * 2.0)))
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", int(5.0 * 128.0 / (radio * 2.0)))
	boton.add_child(etiqueta)
	add_child(boton)
	_botones[accion] = boton


## Ubica los botones respecto a la esquina inferior derecha (y "Menú" arriba a la derecha).
func _acomodar() -> void:
	for datos in BOTONES:
		var radio: float = datos[3]
		_botones[datos[1]].position = size + datos[2] - Vector2(radio, radio)
	var menu: TouchScreenButton = _botones["liberar_mouse"]
	var radio_menu: float = menu.get_meta("radio")
	menu.position = Vector2(size.x - radio_menu * 2.0 - 16.0, 12.0)


## "Hablar" solo hace falta si tu rol habla y estás en modo "pulsar para hablar".
func _actualizar_hablar() -> void:
	var boton: TouchScreenButton = _botones["hablar"]
	boton.visible = Lobby.mi_rol() != Roles.Rol.MUDO \
		and Opciones.modo_microfono == Microfono.Modo.PULSAR


static func _textura_circulo(color: Color) -> Texture2D:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.88, 0.95, 1.0])
	degradado.colors = PackedColorArray([color, color, Color(color, minf(color.a * 2.0, 1.0)),
		Color(color, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 128
	textura.height = 128
	return textura
