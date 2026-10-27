extends Control
## Menú principal: Hospedar / Unirse por IP en red local.
## Solo maneja la interfaz; la conexión la hace el autoload Red.
## Pasa al lobby cuando el host lo acepta en el saludo.

const IP_POR_DEFECTO := "127.0.0.1"

@onready var _boton_hospedar: Button = %boton_hospedar
@onready var _campo_ip: LineEdit = %campo_ip
@onready var _boton_unirse: Button = %boton_unirse
@onready var _boton_cancelar: Button = %boton_cancelar
@onready var _capa_opciones: Control = %capa_opciones
@onready var _etiqueta_estado: Label = %etiqueta_estado


func _ready() -> void:
	_boton_hospedar.pressed.connect(_al_presionar_hospedar)
	_boton_unirse.pressed.connect(_al_presionar_unirse)
	_campo_ip.text_submitted.connect(func(_texto: String) -> void: _al_presionar_unirse())
	_boton_cancelar.pressed.connect(_al_presionar_cancelar)
	%boton_opciones.pressed.connect(_capa_opciones.show)
	%boton_volver.pressed.connect(_capa_opciones.hide)

	Red.conexion_exitosa.connect(_ir_al_lobby)
	Red.desconectado.connect(_al_desconectarse)

	_campo_ip.placeholder_text = IP_POR_DEFECTO
	# Si venimos de una desconexión, se muestra el motivo.
	_al_desconectarse()


func _al_presionar_hospedar() -> void:
	var error := Red.hospedar()
	if error != OK:
		_mostrar_menu("No se pudo hospedar (¿puerto %d ocupado?)" % Red.PUERTO_POR_DEFECTO)
		return
	_ir_al_lobby()


func _al_presionar_unirse() -> void:
	var ip := _campo_ip.text.strip_edges()
	if ip.is_empty():
		ip = IP_POR_DEFECTO
	if not ip.is_valid_ip_address():
		_mostrar_menu("IP inválida: %s" % ip)
		return
	var error := Red.unirse(ip)
	if error != OK:
		_mostrar_menu("No se pudo crear la conexión")
		return
	_mostrar_conectando("Conectando a %s..." % ip)


func _al_presionar_cancelar() -> void:
	Red.desconectar()


## Muestra el motivo una sola vez (rechazo, fallo, host caído...).
func _al_desconectarse() -> void:
	_mostrar_menu(Red.motivo_desconexion)
	Red.motivo_desconexion = ""


func _ir_al_lobby() -> void:
	get_tree().change_scene_to_file(Lobby.ESCENA_LOBBY)


## Estado inicial: se puede hospedar o unirse.
func _mostrar_menu(mensaje: String) -> void:
	_boton_hospedar.disabled = false
	_boton_unirse.disabled = false
	_campo_ip.editable = true
	_boton_cancelar.visible = false
	_etiqueta_estado.text = mensaje


## Intentando conectar: solo se puede cancelar.
func _mostrar_conectando(mensaje: String) -> void:
	_boton_hospedar.disabled = true
	_boton_unirse.disabled = true
	_campo_ip.editable = false
	_boton_cancelar.visible = true
	_etiqueta_estado.text = mensaje
