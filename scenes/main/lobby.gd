extends Control
## Pantalla del lobby: muestra jugadores, roles y deja al host repartirlos.
## Solo es interfaz; el estado y los cambios de escena viven en el autoload Lobby.

@onready var _etiqueta_ip: Label = %etiqueta_ip
@onready var _etiqueta_estado: Label = %etiqueta_estado
@onready var _lista_jugadores: VBoxContainer = %lista_jugadores
@onready var _panel_mi_rol: VBoxContainer = %panel_mi_rol
@onready var _etiqueta_mi_rol: Label = %etiqueta_mi_rol
@onready var _etiqueta_descripcion: Label = %etiqueta_descripcion
@onready var _boton_asignar: Button = %boton_asignar
@onready var _boton_empezar: Button = %boton_empezar
@onready var _selector_prueba: OptionButton = %selector_prueba
@onready var _boton_salir: Button = %boton_salir


func _ready() -> void:
	_boton_asignar.pressed.connect(Lobby.asignar_roles)
	_boton_empezar.pressed.connect(func() -> void: Lobby.empezar_partida(_selector_prueba.selected))
	_boton_salir.pressed.connect(Red.desconectar)
	Lobby.estado_cambiado.connect(_actualizar)

	if multiplayer.is_server():
		var ips := Red.ips_locales()
		_etiqueta_ip.text = "Tu IP: %s" % (", ".join(ips) if not ips.is_empty() else "127.0.0.1")
	_etiqueta_ip.visible = multiplayer.is_server()
	_boton_asignar.visible = multiplayer.is_server()
	_boton_empezar.visible = multiplayer.is_server()
	# Debug: saltar directo a cualquier prueba sin jugar las anteriores.
	for i in Lobby.PRUEBAS.size():
		_selector_prueba.add_item("Empezar en: %d. %s" % [i + 1, Lobby.nombre_prueba(i)])
	_selector_prueba.selected = 0
	_selector_prueba.visible = multiplayer.is_server() and OS.is_debug_build()
	_actualizar()


func _actualizar() -> void:
	_actualizar_lista()
	_actualizar_estado()
	_actualizar_mi_rol()


func _actualizar_lista() -> void:
	for hijo in _lista_jugadores.get_children():
		hijo.queue_free()
	var mi_id := multiplayer.get_unique_id()
	for id in Lobby.jugadores:
		var texto := "Jugador %d" % Lobby.numero_de(id)
		if id == 1:
			texto += " (host)"
		if id == mi_id:
			texto += " (tú)"
		if Lobby.roles_asignados():
			texto += " — %s" % Roles.nombre(Lobby.rol_de(id))
		var etiqueta := Label.new()
		etiqueta.text = texto
		_lista_jugadores.add_child(etiqueta)


func _actualizar_estado() -> void:
	var cantidad := Lobby.jugadores.size()
	if Lobby.roles_asignados():
		_etiqueta_estado.text = "¡Roles asignados!" if multiplayer.is_server() \
			else "¡Roles asignados! Esperando a que el host empiece..."
	elif not Lobby.esta_lleno():
		_etiqueta_estado.text = "Esperando jugadores (%d/%d)" % [cantidad, Red.MAX_JUGADORES]
	elif multiplayer.is_server():
		_etiqueta_estado.text = "¡Listos! Asigna los roles."
	else:
		_etiqueta_estado.text = "Esperando a que el host asigne los roles..."
	_boton_asignar.disabled = not Lobby.esta_lleno() or Lobby.roles_asignados()
	_boton_empezar.disabled = not Lobby.roles_asignados()


func _actualizar_mi_rol() -> void:
	var rol := Lobby.mi_rol()
	_panel_mi_rol.visible = rol != -1
	if rol != -1:
		_etiqueta_mi_rol.text = "Eres el %s" % Roles.nombre(rol)
		_etiqueta_descripcion.text = Roles.descripcion(rol)
