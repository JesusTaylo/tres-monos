extends Node
## Interacción con E / clic (componente del jugador): agarrar y soltar
## objetos físicos y presionar botones. El jugador solo pide; el host decide
## (ver ObjetoFisico y Boton).

@export var rayo: RayCast3D


func _ready() -> void:
	set_process_unhandled_input(is_multiplayer_authority())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("agarrar") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sostenido := ObjetoFisico.sostenido_por_jugador(get_tree(), multiplayer.get_unique_id())
	if sostenido:
		sostenido.pedir_soltar.rpc_id(1)
		return
	var objetivo := rayo.get_collider()
	if objetivo is ObjetoFisico:
		objetivo.pedir_agarrar.rpc_id(1)
	elif objetivo is Boton:
		objetivo.pedir_presionar.rpc_id(1)
