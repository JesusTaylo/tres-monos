extends Node
## Interacción con E / clic (componente del jugador): agarrar y soltar
## objetos físicos, presionar botones y tomar o soltar la perilla de la caja
## fuerte. El jugador solo pide; el host decide (ver ObjetoFisico, Boton y Perilla).

@export var rayo: RayCast3D


func _ready() -> void:
	set_process_unhandled_input(is_multiplayer_authority())


func _unhandled_input(event: InputEvent) -> void:
	# En el teléfono, el botón "Agarrar" manda la acción; los toques sueltos no cuentan.
	if Entrada.es_mouse_de_toque(event) or not event.is_action_pressed("agarrar") \
			or not Entrada.jugando():
		return
	var mi_id := multiplayer.get_unique_id()
	var sostenido := ObjetoFisico.sostenido_por_jugador(get_tree(), mi_id)
	if sostenido:
		sostenido.pedir_soltar.rpc_id(1)
		return
	var perilla := Perilla.tomada_por_jugador(get_tree(), mi_id)
	if perilla:
		perilla.pedir_soltar.rpc_id(1)
		return
	var objetivo := rayo.get_collider()
	if objetivo is ObjetoFisico:
		objetivo.pedir_agarrar.rpc_id(1)
	elif objetivo is Boton:
		objetivo.pedir_presionar.rpc_id(1)
	elif objetivo is Perilla:
		objetivo.pedir_tomar.rpc_id(1)
