class_name PanelOpciones
extends VBoxContainer
## Panel de opciones de audio (se usa en el menú principal y en el de pausa).
## Mientras está visible enciende el micrófono para mostrar el medidor de nivel.

const MODOS := {
	Microfono.Modo.PULSAR: "Pulsar para hablar (V)",
	Microfono.Modo.ABIERTO: "Micrófono abierto",
}

@onready var _microfono: OptionButton = %microfono
@onready var _entrada: HSlider = %volumen_entrada
@onready var _medidor: ProgressBar = %medidor
@onready var _aviso_micro: Label = %aviso_micro
@onready var _salida: HSlider = %volumen_salida
@onready var _modo: OptionButton = %modo
@onready var _voz_prueba: CheckBox = %voz_prueba


func _ready() -> void:
	for modo in MODOS:
		_modo.add_item(MODOS[modo], modo)
	_voz_prueba.visible = OS.is_debug_build()
	if Entrada.es_tactil():
		# Más alto para el dedo; y en el teléfono no hay tecla V.
		for control: Control in [_microfono, _entrada, _salida, _modo]:
			control.custom_minimum_size.y = 40.0
		_modo.set_item_text(_modo.get_item_index(Microfono.Modo.PULSAR),
			"Pulsar para hablar (botón Hablar)")
	_microfono.item_selected.connect(func(i: int) -> void:
		Opciones.poner(&"dispositivo_entrada", _microfono.get_item_text(i)))
	_entrada.value_changed.connect(func(v: float) -> void: Opciones.poner(&"volumen_entrada", v))
	_salida.value_changed.connect(func(v: float) -> void: Opciones.poner(&"volumen_salida", v))
	_modo.item_selected.connect(func(i: int) -> void:
		Opciones.poner(&"modo_microfono", _modo.get_item_id(i)))
	_voz_prueba.toggled.connect(func(activa: bool) -> void: Microfono.voz_prueba = activa)
	visibility_changed.connect(_al_cambiar_visibilidad)
	_al_cambiar_visibilidad()


func _al_cambiar_visibilidad() -> void:
	if is_visible_in_tree():
		_refrescar()
		Microfono.pedir(&"opciones")
	else:
		Microfono.soltar(&"opciones")


func _exit_tree() -> void:
	Microfono.soltar(&"opciones")


## Carga los valores actuales en los controles sin disparar cambios.
func _refrescar() -> void:
	_microfono.clear()
	for nombre in Microfono.dispositivos():
		_microfono.add_item(nombre)
		if nombre == Opciones.dispositivo_entrada:
			_microfono.select(_microfono.item_count - 1)
	_entrada.set_value_no_signal(Opciones.volumen_entrada)
	_salida.set_value_no_signal(Opciones.volumen_salida)
	_modo.select(_modo.get_item_index(Opciones.modo_microfono))
	_voz_prueba.set_pressed_no_signal(Microfono.voz_prueba)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_medidor.value = Microfono.nivel
	var sin_codec := not Microfono.disponible()
	var fallo := Microfono.error_dispositivo() != OK and not Microfono.voz_prueba
	_aviso_micro.visible = sin_codec or fallo
	if sin_codec:
		_aviso_micro.text = "Voz no disponible (falta la extensión TwoVoIP)"
	elif Microfono.error_dispositivo() == ERR_UNAUTHORIZED:
		_aviso_micro.text = "Falta el permiso del micrófono: dáselo al juego en los ajustes del teléfono"
	elif fallo:
		_aviso_micro.text = "No se pudo abrir el micrófono"
